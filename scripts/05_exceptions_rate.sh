#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
DURATION="${DURATION:-300}"     # 5 phút
TARGET_EPS="${TARGET_EPS:-5}"   # exceptions per second (ước lượng). tăng lên 20, 50 nếu muốn

# khoảng nghỉ giữa các lỗi (giây)
SLEEP=$(awk -v eps="$TARGET_EPS" 'BEGIN{ if(eps<=0) eps=1; print 1/eps }')

start_ts=$(date +%s)
echo "Generating internal exceptions for ${DURATION}s at ~${TARGET_EPS} exceptions/s..."
echo "BASE_URL=$BASE_URL, sleep=${SLEEP}s"

while true; do
  now=$(date +%s)
  elapsed=$((now - start_ts))
  if [ "$elapsed" -ge "$DURATION" ]; then
    break
  fi

  # Gửi JSON bị cắt cụt => parse fail => except => ERROR_COUNT.inc()
  curl -s -X POST "$BASE_URL/items" \
    -H "Content-Type: application/json" \
    -d '{"name":' >/dev/null || true

  # jitter nhẹ cho giống thật
  jitter=$(awk 'BEGIN{srand(); print (rand()*0.05)}')  # 0-50ms
  sleep_time=$(awk -v base="$SLEEP" -v j="$jitter" 'BEGIN{ print base + j }')
  sleep "$sleep_time"
done

echo "Done."
