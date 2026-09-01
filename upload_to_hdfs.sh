#!/bin/bash
# Run this from your HOST after producer.py + consumer.py have written files
# into ./data/*.json. It copies those files into the namenode container,
# then puts them into HDFS.
#
# Usage: ./upload_to_hdfs.sh
# Edit HDFS_BASE and the file list to match your scenario's topic names.

HDFS_BASE=/exam_data

for f in ./data/*.json; do
  topic=$(basename "$f" .json)

  # 1. copy file from host into the namenode container
  docker cp "$f" namenode:/tmp/"$topic".json

  # 2. make sure the HDFS directory exists, then put the file
  docker exec namenode hdfs dfs -mkdir -p "$HDFS_BASE/$topic"
  docker exec namenode hdfs dfs -put -f /tmp/"$topic".json "$HDFS_BASE/$topic/"

  echo "Uploaded $f -> hdfs://$HDFS_BASE/$topic/"
done

echo "Done. Verify with: docker exec namenode hdfs dfs -ls -R $HDFS_BASE"
