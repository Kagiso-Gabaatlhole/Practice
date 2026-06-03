
# Question : Distributed Computing - Logistic Regression
# Optimization: Newton-Raphson across 5 nodes

library(parallel)

set.seed(42)

# 2.1 DATA GENERATION
n_total <- 200
n_nodes <- 5
n_per_node <- n_total / n_nodes  # 40 per node

# Generate full dataset
x <- rnorm(n_total, mean = 0, sd = 1)
prob <- 1 / (1 + exp(-(0.5 + x)))   # linear predictor: 0.5 + x
y <- rbinom(n_total, size = 1, prob = prob)

cat(sprintf("Total data points: %d\n", n_total))
cat(sprintf("Nodes: %d\n", n_nodes))
cat(sprintf("Data points per node: %d\n", n_per_node))
cat(sprintf("Overall proportion of y=1: %.4f\n\n", mean(y)))

# Distribute data across 5 nodes (5 separate datasets)
node_data <- lapply(1:n_nodes, function(i) {
  idx <- ((i - 1) * n_per_node + 1):(i * n_per_node)
  data.frame(x = x[idx], y = y[idx])
})

for (i in 1:n_nodes) {
  cat(sprintf("Node %d: %d observations, proportion y=1 = %.4f\n",
              i, nrow(node_data[[i]]), mean(node_data[[i]]$y)))
}

# ============================================================
# 2.4 OPTIMIZATION: Newton-Raphson
# ============================================================
# Logistic regression log-likelihood, gradient, and Hessian
# Model: logit(p) = beta0 + beta1 * x
# Parameters: theta = c(beta0, beta1)

# Sigmoid function
sigmoid <- function(z) 1 / (1 + exp(-z))

# Compute local gradient and Hessian for one node
local_grad_hessian <- function(data, theta) {
  X <- cbind(1, data$x)   # design matrix (n x 2)
  y <- data$y
  p <- sigmoid(X %*% theta)       # predicted probabilities
  
  residual <- y - p                # (n x 1)
  gradient <- t(X) %*% residual   # (2 x 1)
  
  W <- diag(as.vector(p * (1 - p)))   # weight matrix (n x n)
  hessian <- -t(X) %*% W %*% X        # (2 x 2)
  
  list(gradient = gradient, hessian = hessian)
}
# 2.2 PARAMETER UPDATES (Distributed Newton-Raphson)
# True parameters for comparison
true_beta0 <- 0.5
true_beta1 <- 1.0

# Initialise parameters
theta <- c(0, 0)   # beta0=0, beta1=0
max_iter <- 50
tol <- 1e-6

cat(sprintf("\nTrue parameters: beta0 = %.4f, beta1 = %.4f\n", true_beta0, true_beta1))
cat(sprintf("Initial parameters: beta0 = %.4f, beta1 = %.4f\n\n", theta[1], theta[2]))

# ---- Start timing ----
start_time <- proc.time()

iteration_log <- data.frame(
  Iteration  = integer(),
  beta0      = numeric(),
  beta1      = numeric(),
  diff_beta0 = numeric(),
  diff_beta1 = numeric(),
  norm_diff  = numeric()
)

for (iter in 1:max_iter) {
  
  # --- Aggregate gradient and Hessian across all nodes ---
  agg_gradient <- matrix(0, nrow = 2, ncol = 1)
  agg_hessian  <- matrix(0, nrow = 2, ncol = 2)
  
  for (node in 1:n_nodes) {
    gh <- local_grad_hessian(node_data[[node]], theta)
    agg_gradient <- agg_gradient + gh$gradient
    agg_hessian  <- agg_hessian  + gh$hessian
  }
  
  # Newton-Raphson update: theta_new = theta - H^{-1} * gradient
  # (gradient ascent on log-likelihood => subtract negative gradient)
  theta_new <- theta - solve(agg_hessian) %*% agg_gradient
  
  # 2.2: Compare estimated vs actual parameters
  diff_beta0 <- theta_new[1] - true_beta0
  diff_beta1 <- theta_new[2] - true_beta1
  norm_diff  <- sqrt(sum((theta_new - c(true_beta0, true_beta1))^2))
  
  iteration_log <- rbind(iteration_log, data.frame(
    Iteration  = iter,
    beta0      = round(theta_new[1], 6),
    beta1      = round(theta_new[2], 6),
    diff_beta0 = round(diff_beta0, 6),
    diff_beta1 = round(diff_beta1, 6),
    norm_diff  = round(norm_diff, 6)
  ))
  
  cat(sprintf(
    "Iter %2d | beta0 = %7.4f | beta1 = %7.4f | diff_beta0 = %8.5f | diff_beta1 = %8.5f | ||diff|| = %.6f\n",
    iter, theta_new[1], theta_new[2], diff_beta0, diff_beta1, norm_diff
  ))
  
  # Check convergence
  if (sqrt(sum((theta_new - theta)^2)) < tol) {
    cat(sprintf("\nConverged at iteration %d\n", iter))
    break
  }
  
  theta <- theta_new
}

# ---- End timing ----
end_time <- proc.time()
elapsed  <- (end_time - start_time)["elapsed"]

# FINAL RESULTS SUMMARY
cat("\n=== FINAL RESULTS ===\n")
cat(sprintf("Estimated beta0 : %.6f\n", theta_new[1]))
cat(sprintf("Estimated beta1 : %.6f\n", theta_new[2]))
cat(sprintf("True      beta0 : %.6f\n", true_beta0))
cat(sprintf("True      beta1 : %.6f\n", true_beta1))
cat(sprintf("Difference beta0: %.6f\n", theta_new[1] - true_beta0))
cat(sprintf("Difference beta1: %.6f\n", theta_new[2] - true_beta1))

# 2.3 RUN TIME
cat("\n=== 2.3 RUN TIME ===\n")
cat(sprintf("Total elapsed runtime: %.6f seconds\n", elapsed))
cat(sprintf("Iterations completed : %d\n", nrow(iteration_log)))
cat(sprintf("Average time/iter    : %.6f seconds\n", elapsed / nrow(iteration_log)))
# ITERATION LOG TABLE
# ========================================================
cat("\n=== ITERATION LOG (Parameter Comparison) ===\n")
print(iteration_log, row.names = FALSE)

# ============================================================
# VERIFICATION: Compare with R's built-in glm
# ============================================================
cat("\n=== VERIFICATION WITH glm() ===\n")
full_data <- data.frame(x = x, y = y)
glm_fit <- glm(y ~ x, data = full_data, family = binomial)
cat("glm() estimates:\n")
print(coef(glm_fit))
cat(sprintf("\nNewton-Raphson estimates: beta0 = %.6f, beta1 = %.6f\n",
            theta_new[1], theta_new[2]))
