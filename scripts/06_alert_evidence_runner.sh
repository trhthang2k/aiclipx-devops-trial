#!/usr/bin/env bash
set -euo pipefail

# Purpose: drive synthetic traffic patterns that trigger the Prometheus alerts.
# Usage: ./scripts/06_alert_evidence_runner.sh [scenario]
# Scenarios: all (default), baseline, 5xx, latency, exceptions, drop

BASE_URL="${BASE_URL:-http://localhost:8080}"

# Default durations are short; override via environment variables if needed.
BASELINE_DURATION="${BASELINE_DURATION:-60}"
FIVEXX_DURATION="${FIVEXX_DURATION:-120}"
FIVEXX_ERROR_PCT="${FIVEXX_ERROR_PCT:-25}"
LATENCY_DURATION="${LATENCY_DURATION:-120}"
LATENCY_BURST_MIN="${LATENCY_BURST_MIN:-15}"
LATENCY_BURST_MAX="${LATENCY_BURST_MAX:-40}"
LATENCY_BURST_PROB="${LATENCY_BURST_PROB:-15}"
EXCEPTION_DURATION="${EXCEPTION_DURATION:-120}"
EXCEPTION_TARGET_EPS="${EXCEPTION_TARGET_EPS:-8}"
DROP_WINDOW="${DROP_WINDOW:-360}"

random_float() {
  python3 - "$1" "$2" <<'PY'
import random
import sys
print(random.uniform(float(sys.argv[1]), float(sys.argv[2])))
PY
}

random_int() {
  python3 - "$1" "$2" <<'PY'
import random
import sys
print(random.randint(int(sys.argv[1]), int(sys.argv[2])))
PY
}

run_baseline() {
  local end_ts=$(( $(date +%s) + BASELINE_DURATION ))
  echo "[baseline] Running for ${BASELINE_DURATION}s against ${BASE_URL}"
  while [ "$(date +%s)" -lt "$end_ts" ]; do
    local pick=$(( RANDOM % 100 ))
    if [ "$pick" -lt 60 ]; then
      curl -s "$BASE_URL/" >/dev/null
    elif [ "$pick" -lt 85 ]; then
      curl -s "$BASE_URL/items" >/dev/null
    else
      curl -s -X POST "$BASE_URL/items" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"item-$RANDOM\"}" >/dev/null
    fi
    sleep "$(random_float 0.05 0.3)"
  done
  echo "[baseline] Done"
}

run_5xx() {
  local end_ts=$(( $(date +%s) + FIVEXX_DURATION ))
  echo "[5xx] Running for ${FIVEXX_DURATION}s with ~${FIVEXX_ERROR_PCT}% forced errors"
  while [ "$(date +%s)" -lt "$end_ts" ]; do
    local pick=$(( RANDOM % 100 ))
    if [ "$pick" -lt "$FIVEXX_ERROR_PCT" ]; then
      curl -s -X POST "$BASE_URL/items" \
        -H "Content-Type: application/json" \
        -d '{"name":' >/dev/null
    else
      curl -s "$BASE_URL/" >/dev/null
    fi
    sleep "$(random_float 0.05 0.25)"
  done
  echo "[5xx] Done"
}

run_latency() {
  local end_ts=$(( $(date +%s) + LATENCY_DURATION ))
  echo "[latency] Running for ${LATENCY_DURATION}s with burst probability ${LATENCY_BURST_PROB}%"
  while [ "$(date +%s)" -lt "$end_ts" ]; do
    if [ $(( RANDOM % 100 )) -lt "$LATENCY_BURST_PROB" ]; then
      local burst=$(random_int "$LATENCY_BURST_MIN" "$LATENCY_BURST_MAX")
      echo "[latency] Burst of $burst parallel requests"
      for _ in $(seq 1 "$burst"); do
        curl -s "$BASE_URL/items" >/dev/null &
      done
      wait
      sleep 0.4
    else
      curl -s "$BASE_URL/items" >/dev/null
      sleep "$(random_float 0.05 0.2)"
    fi
  done
  echo "[latency] Done"
}

run_exceptions() {
  local end_ts=$(( $(date +%s) + EXCEPTION_DURATION ))
  local base_sleep
  base_sleep=$(python3 - "$EXCEPTION_TARGET_EPS" <<'PY'
import sys
rate = float(sys.argv[1])
if rate <= 0:
    rate = 1.0
print(1.0 / rate)
PY
)
  echo "[exceptions] Running for ${EXCEPTION_DURATION}s targeting ~${EXCEPTION_TARGET_EPS} eps"
  while [ "$(date +%s)" -lt "$end_ts" ]; do
    curl -s -X POST "$BASE_URL/items" \
      -H "Content-Type: application/json" \
      -d '{"name":' >/dev/null || true
    local jitter
    jitter=$(random_float 0.0 0.05)
    sleep "$(python3 - "$base_sleep" "$jitter" <<'PY'
import sys
print(float(sys.argv[1]) + float(sys.argv[2]))
PY
)"
  done
  echo "[exceptions] Done"
}

run_drop() {
  echo "[drop] Sleeping for ${DROP_WINDOW}s to simulate traffic loss"
  sleep "$DROP_WINDOW"
  echo "[drop] Done"
}

run_scenario() {
  case "$1" in
    baseline) run_baseline ;;
    5xx) run_5xx ;;
    latency) run_latency ;;
    exceptions) run_exceptions ;;
    drop) run_drop ;;
    all)
      run_baseline
      run_5xx
      run_latency
      run_exceptions
      run_drop
      ;;
    *)
      echo "Unknown scenario: $1" >&2
      echo "Use: all, baseline, 5xx, latency, exceptions, drop" >&2
      exit 1
      ;;
  esac
}

scenario="${1:-all}"
cat <<EOF
Alert evidence runner
Base URL: $BASE_URL
Scenario: $scenario
EOF

run_scenario "$scenario"

echo "All done. Capture Prometheus/Grafana evidence now."
