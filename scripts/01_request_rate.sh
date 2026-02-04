#!/usr/bin/env bash

BASE_URL="http://localhost:8080"
DURATION=300   # 5 phút = 300s

start_ts=$(date +%s)

echo "Generating random user traffic for 5 minutes..."

while true; do
  now=$(date +%s)
  elapsed=$((now - start_ts))

  if [ "$elapsed" -ge "$DURATION" ]; then
    break
  fi

  # random number 1–100
  r=$((RANDOM % 100))

  if [ "$r" -lt 60 ]; then
    # 60% GET /
    curl -s "$BASE_URL/" > /dev/null

  elif [ "$r" -lt 85 ]; then
    # 25% GET /items
    curl -s "$BASE_URL/items" > /dev/null

  else
    # 15% POST /items
    curl -s -X POST "$BASE_URL/items" \
      -H "Content-Type: application/json" \
      -d "{\"name\": \"item-$RANDOM\"}" > /dev/null
  fi

  # sleep random 50–300ms (user think time)
  sleep_time=$(awk -v min=0.05 -v max=0.3 'BEGIN{srand(); print min+rand()*(max-min)}')
  sleep "$sleep_time"
done

echo "Done."
