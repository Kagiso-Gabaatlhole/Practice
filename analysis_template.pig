-- ============================================================
-- PIG LATIN CHEAT-SHEET / TEMPLATE
-- Covers the patterns most likely to show up: load JSON, extract
-- time buckets, GROUP + aggregate, FILTER, JOIN across two topics,
-- ORDER + top-N, and STORE results.
-- Copy/paste the blocks you need and rename fields/paths.
-- Run inside the pig container:  pig -x local analysis_template.pig
-- (drop "-x local" to run against HDFS/MapReduce instead of local fs)
-- ============================================================

-- Register the JSON loader piggybank jar if it isn't already on the classpath
-- REGISTER '/opt/pig/lib/piggybank.jar';

-- ---------- 1. LOAD JSON DATA ----------
-- Field list must match your data's keys, in order.
sales = LOAD '/exam_data/sales/sales.json'
    USING JsonLoader('transaction_id:int, item:chararray, price:double, quantity:int, timestamp:chararray');

turnstiles = LOAD '/exam_data/turnstiles/turnstiles.json'
    USING JsonLoader('ticket_id:int, gate_id:int, person_id:int, action:chararray, timestamp:chararray');

-- ---------- 2. DERIVE / TRANSFORM FIELDS ----------
-- Common gotcha: timestamp format must EXACTLY match how you wrote it in Python.
-- Python: datetime.datetime.now() -> "2026-09-01 14:23:05.123456" (has microseconds!)
-- If your timestamp has microseconds, strip them first or the ToDate() call will fail:
--   e.g. SUBSTRING(timestamp, 0, 19) to cut off ".123456"

sales_enriched = FOREACH sales GENERATE
    transaction_id,
    item,
    price * quantity AS total_spend,
    GetHour(ToDate(SUBSTRING(timestamp, 0, 19), 'yyyy-MM-dd HH:mm:ss')) AS hour,
    timestamp;

-- ---------- 3. FILTER ----------
big_purchases = FILTER sales_enriched BY total_spend > 15.0;

-- ---------- 4. GROUP + AGGREGATE ----------
-- "Which item is most popular per hour?" style question
sales_by_hour_item = FOREACH (GROUP sales_enriched BY (hour, item))
    GENERATE
        FLATTEN(group) AS (hour, item),
        SUM(sales_enriched.total_spend) AS revenue,
        COUNT(sales_enriched) AS n_transactions;

-- ---------- 5. TOP-N PER GROUP (e.g. most popular item per hour) ----------
sales_by_hour_item_ordered = ORDER sales_by_hour_item BY hour, revenue DESC;

grouped_by_hour = GROUP sales_by_hour_item_ordered BY hour;
top_item_per_hour = FOREACH grouped_by_hour {
    ranked = ORDER sales_by_hour_item_ordered BY revenue DESC;
    top1   = LIMIT ranked 1;
    GENERATE FLATTEN(top1);
};

-- ---------- 6. GATE / ENTRY CONGESTION EXAMPLE ----------
entries = FILTER turnstiles BY action == 'entry';
entries_per_gate = FOREACH (GROUP entries BY gate_id)
    GENERATE group AS gate_id, COUNT(entries) AS n_entries;
entries_per_gate_sorted = ORDER entries_per_gate BY n_entries DESC;

-- ---------- 7. JOIN TWO DATASETS ----------
-- e.g. "do fans who enter earlier spend more?" -> join turnstiles with sales on person_id
-- (only meaningful if both datasets share a common key like person_id/fan_id)
joined = JOIN entries BY person_id, sales_enriched BY transaction_id;  -- swap for the real shared key
-- spend_vs_entry_time = FOREACH joined GENERATE entries::timestamp AS entry_time,
--     sales_enriched::total_spend AS spend;

-- ---------- 8. STORE RESULTS ----------
STORE sales_by_hour_item_ordered INTO '/exam_data/output/sales_by_hour_item' USING PigStorage(',');
STORE entries_per_gate_sorted INTO '/exam_data/output/entries_per_gate' USING PigStorage(',');
STORE top_item_per_hour INTO '/exam_data/output/top_item_per_hour' USING PigStorage(',');

-- ---------- 9. QUICK DEBUGGING (comment out before final submission) ----------
-- DUMP sales_enriched;
-- DESCRIBE sales_by_hour_item;
-- ILLUSTRATE sales_by_hour_item;
