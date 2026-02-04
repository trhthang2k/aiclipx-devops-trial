#!/usr/bin/env bash

BASE_URL="http://localhost:8080"
DURATION=300          # 5 phút
ERROR_PCT=10          # % request sẽ cố tình tạo 5xx (chỉnh 5, 10, 20...)

start_ts=$(date +%s)

echo "Generating traffic with ~${ERROR_PCT}% 5xx for ${DURATION}s..."

while true; do
  now=$(date +%s)
  elapsed=$((now - start_ts))
  if [ "$elapsed" -ge "$DURATION" ]; then
    break
  fi

  r=$((RANDOM % 100))

  if [ "$r" -lt "$ERROR_PCT" ]; then
    # ---- Force 5xx: gửi JSON rác để server parse fail -> exception -> 500 ----
    curl -s -X POST "$BASE_URL/items" \
      -H "Content-Type: application/json" \
      -d '{"name":' >/dev/null

  else
    # ---- Normal user traffic (2xx) ----
    r2=$((RANDOM % 100))
    if [ "$r2" -lt 50 ]; then
      curl -s "$BASE_URL/" >/dev/null
    elif [ "$r2" -lt 85 ]; then
      curl -s "$BASE_URL/items" >/dev/null
    else
      curl -s -X POST "$BASE_URL/items" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"item-$RANDOM\"}" >/dev/null
    fi
  fi

  # sleep random 50–300ms
  sleep_time=$(awk -v min=0.05 -v max=0.3 'BEGIN{srand(); print min+rand()*(max-min)}')
  sleep "$sleep_time"
done

echo "Done."
