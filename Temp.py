# ============================================================
# Dataset : Intel Image Classification (6 scene categories)
# Kaggle  : https://www.kaggle.com/datasets/puneet6060/intel-image-classification
# Add it  : Kaggle notebook → + Add Data → search "intel image classification" by puneet6060
# Folders : seg_train/seg_train   (14k images)
#           seg_test/seg_test      (3k images)
# ============================================================

import os, torch
from torch import nn, optim
from torchvision import datasets, transforms, models
from torch.utils.data import DataLoader, random_split
from sklearn.metrics import classification_report

# 1. CONFIG
device   = "cuda" if torch.cuda.is_available() else "cpu"
BASE     = "/kaggle/input/datasets/puneet6060/intel-image-classification"
TRAIN    = BASE + "/seg_train/seg_train"
TEST     = BASE + "/seg_test/seg_test"
IMG_SIZE = 224
MEAN, STD = [0.485, 0.456, 0.406], [0.229, 0.224, 0.225]

# 2. DATA
train_tfm = transforms.Compose([
    transforms.Resize((IMG_SIZE + 20, IMG_SIZE + 20)),
    transforms.RandomCrop(IMG_SIZE),
    transforms.RandomHorizontalFlip(),
    transforms.RandomVerticalFlip(),
    transforms.RandomRotation(20),
    transforms.ColorJitter(brightness=0.3, contrast=0.3),
    transforms.GaussianBlur(kernel_size=3),
    transforms.ToTensor(),
    transforms.Normalize(MEAN, STD),
    transforms.RandomErasing(p=0.2),
])
val_tfm = transforms.Compose([
    transforms.Resize((IMG_SIZE, IMG_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(MEAN, STD),
])

# Split seg_train → 80% train / 20% val
full_ds  = datasets.ImageFolder(TRAIN, transform=train_tfm)
n_train  = int(0.8 * len(full_ds))
train_ds, val_ds = random_split(full_ds, [n_train, len(full_ds) - n_train])
val_ds.dataset.transform = val_tfm                 # clean transform for val

test_ds  = datasets.ImageFolder(TEST, transform=val_tfm)

train_dl = DataLoader(train_ds, batch_size=32, shuffle=True)
val_dl   = DataLoader(val_ds,   batch_size=32)
test_dl  = DataLoader(test_ds,  batch_size=32)

print(f"Classes : {full_ds.classes}")
print(f"Train: {len(train_ds)} | Val: {len(val_ds)} | Test: {len(test_ds)}")

# 3. MODEL
model    = models.resnet18(weights="IMAGENET1K_V1")
for p in model.parameters(): p.requires_grad = False      # freeze backbone
model.fc = nn.Linear(model.fc.in_features, len(full_ds.classes))
model    = model.to(device)

# 4. TRAIN
opt     = optim.Adam(model.fc.parameters(), lr=1e-3)
loss_fn = nn.CrossEntropyLoss()

for epoch in range(10):
    model.train()
    for x, y in train_dl:
        x, y = x.to(device), y.to(device)
        loss = loss_fn(model(x), y)
        opt.zero_grad(); loss.backward(); opt.step()

    model.eval(); correct = 0
    with torch.no_grad():
        for x, y in val_dl:
            correct += (model(x.to(device)).argmax(1).cpu() == y).sum().item()
    print(f"Epoch {epoch+1:2d} | Val Acc: {correct/len(val_ds):.4f}")

# 5. EVALUATE on test set
model.eval()
y_true, y_pred = [], []
with torch.no_grad():
    for x, y in test_dl:
        y_pred += model(x.to(device)).argmax(1).cpu().tolist()
        y_true += y.tolist()

print(classification_report(y_true, y_pred, target_names=full_ds.classes))
