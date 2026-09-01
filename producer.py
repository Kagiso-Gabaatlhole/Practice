"""
Reusable Kafka producer template.

HOW TO ADAPT THIS IN THE EXAM (fast):
1. Rename the EVENT_GENERATORS dict keys to your topics
   (e.g. "turnstiles", "concessions", "crowd_noise", "energy", "ads")
2. Rewrite each gen_XXX() function to return ONE dict matching your scenario's fields.
3. Run: python producer.py
   (make sure `pip install kafka-python` first)

This single script can run MULTIPLE "producers" at once (one per event type / topic)
using threads, which satisfies "implement multiple producers" requirements.
"""

import json
import random
import time
import threading
import datetime
from kafka import KafkaProducer

# ---- CONNECTION ---------------------------------------------------------
# Use "localhost:29092" if running this script on your HOST machine
# (matches the PLAINTEXT_HOST listener in docker-compose.yml)
KAFKA_BOOTSTRAP_SERVERS = "localhost:29092"

producer = KafkaProducer(
    bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
    value_serializer=lambda v: json.dumps(v).encode("utf-8"),
)


def now():
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


# ---- EVENT GENERATORS (EDIT THESE PER SCENARIO) --------------------------

def gen_turnstiles():
    """Example: fan/passenger entry & exit events."""
    return {
        "ticket_id": random.randint(1, 999999),
        "gate_id": random.choice([1, 2, 3, 4]),
        "person_id": random.randint(1000, 9999),
        "action": random.choice(["entry", "exit"]),
        "timestamp": now(),
    }


def gen_sales():
    """Example: concession / retail transaction events."""
    items = ["burger", "soda", "chips", "pizza", "coffee"]
    return {
        "transaction_id": random.randint(1, 999999),
        "item": random.choice(items),
        "price": round(random.uniform(2, 10), 2),
        "quantity": random.randint(1, 4),
        "timestamp": now(),
    }


def gen_social_media():
    """Example: social media reaction/comment events."""
    platforms = ["Twitter", "Instagram", "TikTok", "Facebook"]
    actions = ["post", "comment", "like", "share", "reaction"]
    return {
        "user_id": random.randint(1, 50000),
        "platform": random.choice(platforms),
        "action": random.choice(actions),
        "text": random.choice(
            ["Amazing performance!", "Loving this!", "Best moment ever", "😍😍😍", "Not feeling this one"]
        ),
        "timestamp": now(),
    }


def gen_sensor_reading():
    """Example: environmental / IoT sensor events (noise, energy, etc.)."""
    return {
        "sensor_id": random.randint(1, 20),
        "reading_type": random.choice(["noise_db", "energy_kwh", "temperature_c"]),
        "value": round(random.uniform(20, 120), 2),
        "timestamp": now(),
    }


# Map: Kafka topic name -> generator function
EVENT_GENERATORS = {
    "turnstiles": gen_turnstiles,
    "sales": gen_sales,
    "social_media": gen_social_media,
    "sensors": gen_sensor_reading,
}


# ---- PRODUCER WORKER (one thread per topic = "multiple producers") -------

def produce_loop(topic, generator_fn, interval_sec=1.0):
    print(f"[producer:{topic}] started, sending every {interval_sec}s")
    while True:
        event = generator_fn()
        producer.send(topic, value=event)
        print(f"[producer:{topic}] -> {event}")
        time.sleep(interval_sec)


if __name__ == "__main__":
    threads = []
    for topic, gen_fn in EVENT_GENERATORS.items():
        t = threading.Thread(target=produce_loop, args=(topic, gen_fn, 1.0), daemon=True)
        t.start()
        threads.append(t)

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nStopping producers...")
        producer.flush()
        producer.close()
