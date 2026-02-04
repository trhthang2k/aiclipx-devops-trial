#!/usr/bin/env bash

BASE_URL="http://localhost:8080"
DURATION=300  # 5 phút

start_ts=$(date +%s)
echo "Generating traffic to push p95 latency up for ${DURATION}s..."

# Hàm bắn 1 request random (đa phần là GET)
one_request() {
  r=$((RANDOM % 100))
  if [ "$r" -lt 55 ]; then
    curl -s "$BASE_URL/" >/dev/null
  elif [ "$r" -lt 90 ]; then
    curl -s "$BASE_URL/items" >/dev/null
  else
    curl -s -X POST "$BASE_URL/items" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"item-$RANDOM\"}" >/dev/null
  fi
}

while true; do
  now=$(date +%s)
  elapsed=$((now - start_ts))
  if [ "$elapsed" -ge "$DURATION" ]; then
    break
  fi

  # Mỗi ~10-20 giây tạo 1 burst cao điểm (20–60 requests song song)
  if [ $((RANDOM % 100)) -lt 12 ]; then
    burst=$((20 + (RANDOM % 41)))   # 20..60
    echo "Burst: ${burst} parallel requests"

    for _ in $(seq 1 "$burst"); do
      one_request &
    done
    wait

    # Nghỉ ngắn sau burst
    sleep 0.5
  else
    # Nền traffic bình thường (1 request/lần)
    one_request

    # sleep random 50–250ms
    sleep_time=$(awk -v min=0.05 -v max=0.25 'BEGIN{srand(); print min+rand()*(max-min)}')
    sleep "$sleep_time"
  fi
done

echo "Done."
