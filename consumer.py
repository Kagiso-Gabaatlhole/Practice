"""
Reusable Kafka consumer template.

HOW TO ADAPT:
1. List the same topics you're producing to in TOPICS below.
2. Run in a SEPARATE terminal from producer.py:
       python consumer.py
   (make sure `pip install kafka-python` first)

This writes each event as a line of JSON into ./data/<topic>.json
so the files are ready to `hdfs dfs -put` straight into HDFS afterwards.
Run one instance per topic (open several terminals) to satisfy
"implement multiple consumers", or let one process fan out to files
for every topic as shown here.
"""

import json
import os
from kafka import KafkaConsumer

KAFKA_BOOTSTRAP_SERVERS = "localhost:29092"
TOPICS = ["turnstiles", "sales", "social_media", "sensors"]  # <-- match producer.py
OUTPUT_DIR = "./data"

os.makedirs(OUTPUT_DIR, exist_ok=True)

consumer = KafkaConsumer(
    *TOPICS,
    bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
    value_deserializer=lambda v: json.loads(v.decode("utf-8")),
    auto_offset_reset="earliest",
    group_id="exam-consumer-group",
)

print(f"[consumer] listening on topics: {TOPICS}")

# Keep one open file handle per topic; append newline-delimited JSON (NDJSON)
file_handles = {t: open(os.path.join(OUTPUT_DIR, f"{t}.json"), "a") for t in TOPICS}

try:
    for message in consumer:
        topic = message.topic
        record = message.value
        print(f"[consumer:{topic}] <- {record}")
        file_handles[topic].write(json.dumps(record) + "\n")
        file_handles[topic].flush()
except KeyboardInterrupt:
    print("\nStopping consumer...")
finally:
    for f in file_handles.values():
        f.close()
    consumer.close()
