# NDEV842 Exam Cheat Sheet — Kafka → HDFS → Pig

## 0. Adapt the templates first (2 minutes)
- `producer.py`: rename topics/fields in `EVENT_GENERATORS` to match the given scenario.
- `consumer.py`: update `TOPICS` list to match.
- `analysis_template.pig`: update field lists in `LOAD ... USING JsonLoader(...)`.

## 1. Start the cluster
```bash
docker compose up -d
docker ps            # confirm zookeeper, kafka, namenode, datanode, pig are all Up
```
Give Kafka + namenode ~20–30s to finish initializing before producing.

## 2. Create topics (optional — auto-create is on, but explicit is safer)
```bash
docker exec -it kafka kafka-topics --create --topic turnstiles \
  --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1
# repeat per topic, or list existing ones:
docker exec -it kafka kafka-topics --list --bootstrap-server localhost:9092
```

## 3. Run producer + consumer side-by-side (two terminals)
```bash
pip install kafka-python
python producer.py     # terminal 1
python consumer.py     # terminal 2 — writes ./data/<topic>.json
```
Let it run a bit, then Ctrl+C both. You now have NDJSON files in `./data/`.

## 4. Upload to HDFS
```bash
chmod +x upload_to_hdfs.sh
./upload_to_hdfs.sh
docker exec namenode hdfs dfs -ls -R /exam_data
```
Or manually per file:
```bash
docker cp ./data/sales.json namenode:/tmp/sales.json
docker exec namenode hdfs dfs -mkdir -p /exam_data/sales
docker exec namenode hdfs dfs -put -f /tmp/sales.json /exam_data/sales/
```
HDFS web UI (if exposed): http://localhost:50070

## 5. Run Pig
```bash
docker cp analysis_template.pig pig:/data/analysis.pig
docker exec -it pig pig -x mapreduce /data/analysis.pig
# use "-x local" instead if you want to test against the local filesystem, not HDFS
```
Check results:
```bash
docker exec namenode hdfs dfs -cat /exam_data/output/sales_by_hour_item/part-*
```

## Common gotchas
- **Timestamp format mismatch** is the #1 Pig bug in the practice materials. Python's
  `datetime.datetime.now()` includes microseconds (`14:23:05.123456`), but
  `ToDate(ts, 'yyyy-MM-dd HH:mm:ss')` expects no microseconds. Either format with
  `strftime('%Y-%m-%d %H:%M:%S')` in Python (as the templates already do), or
  `SUBSTRING(timestamp, 0, 19)` in Pig before calling `ToDate`.
- **`localhost:29092` vs `kafka:9092`**: use `29092` from your host machine (producer/consumer
  scripts running outside Docker); use `9092` from inside another container on the same
  docker network.
- **Kafka not ready yet**: if the producer throws `NoBrokersAvailable`, wait a few seconds
  and retry — Kafka takes longer to boot than the script does.
- **Pig image**: there's no official bde2020 Pig image, so `pig.Dockerfile` builds Pig on top
  of `bde2020/hadoop-base`. If your course already gave you a working pig image name from a
  lab, just swap it back into `docker-compose.yml` (`image: <that-image>`) instead of `build:`.
- **JsonLoader needs one JSON object per line** (NDJSON) — the consumer template already
  writes files this way. A single JSON array `[{...},{...}]` will NOT load correctly.
- **Multiple producers/consumers requirement**: `producer.py` already runs one thread per
  topic (counts as multiple producers). For consumers, either run `consumer.py` once (it
  fans out to files per topic) or open a separate terminal per topic with a filtered
  `KafkaConsumer(["topic_name"], ...)` if the brief wants visibly separate consumer processes.

## Answering the "analysis questions" fast
Most scenarios ask things like:
- "Which X is busiest/most popular over time?" → GROUP BY (time_bucket, category), SUM/COUNT, ORDER DESC
- "Does A correlate with B?" → JOIN two datasets on a shared time window or id, eyeball trend, or bucket both by hour and compare
- "Who acts fastest/slowest?" → GROUP BY entity, aggregate a duration or count, ORDER
All covered by blocks 4–7 in `analysis_template.pig` — just relabel fields.
