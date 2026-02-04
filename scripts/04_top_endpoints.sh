#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
ENDPOINT="${1:-/}"          # dùng: ./p95_focus.sh /items  hoặc ./p95_focus.sh /
DURATION="${DURATION:-300}" # 5 phút
BURST_EVERY="${BURST_EVERY:-12}"   # mỗi ~N giây có 1 burst
BURST_MIN="${BURST_MIN:-30}"       # số request song song tối thiểu
BURST_MAX="${BURST_MAX:-80}"       # số request song song tối đa
SLEEP_MIN="${SLEEP_MIN:-0.05}"     # nền traffic
SLEEP_MAX="${SLEEP_MAX:-0.20}"

echo "Target endpoint: $ENDPOINT"
echo "BASE_URL=$BASE_URL, DURATION=${DURATION}s"
echo "Burst every ~${BURST_EVERY}s, parallel=${BURST_MIN}-${BURST_MAX}"

one_req() {
  local url="$BASE_URL$ENDPOINT"

  if [[ "$ENDPOINT" == "/items" ]]; then
    # /items: mix GET và POST để trông thật hơn
    if (( RANDOM % 100 < 80 )); then
      curl -s "$url" >/dev/null
    else
      curl -s -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"item-$RANDOM\"}" >/dev/null
    fi
  else
    # / : chỉ GET
    curl -s "$url" >/dev/null
  fi
}

start_ts=$(date +%s)
next_burst=$((start_ts + BURST_EVERY))

while true; do
  now=$(date +%s)
  elapsed=$((now - start_ts))
  if (( elapsed >= DURATION )); then
    break
  fi

  # Burst định kỳ để kéo p95 lên
  if (( now >= next_burst )); then
    burst=$((BURST_MIN + (RANDOM % (BURST_MAX - BURST_MIN + 1))))
    echo "Burst: $burst parallel hits to $ENDPOINT at +${elapsed}s"

    for _ in $(seq 1 "$burst"); do
      one_req &
    done
    wait

    next_burst=$((now + BURST_EVERY))
    sleep 0.5
    continue
  fi

  # Nền traffic
  one_req

  # sleep random (50–200ms)
  sleep_time=$(awk -v min="$SLEEP_MIN" -v max="$SLEEP_MAX" 'BEGIN{srand(); print min+rand()*(max-min)}')
  sleep "$sleep_time"
done

echo "Done."
