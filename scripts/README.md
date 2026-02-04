## Traffic generator scripts

This folder contains small shell scripts that generate different types of traffic against the `app` service for demonstrations and evidence collection. Each script is standalone; run them from the repo root or this folder.

Scripts included

- `01_request_rate.sh`
	- Purpose: steady, randomized user traffic for ~5 minutes (default).
	- Defaults (in-script): `BASE_URL="http://localhost:8080"`, `DURATION=300` (seconds).
	- Behavior: ~60% `GET /`, ~25% `GET /items`, ~15% `POST /items` with 50–300ms random sleep between requests.
	- Run: `./scripts/01_request_rate.sh`

- `02_5xx_error_rate.sh`
	- Purpose: introduce a configurable percentage of requests that produce server-side 5xx errors.
	- Defaults (in-script): `BASE_URL="http://localhost:8080"`, `DURATION=300`, `ERROR_PCT=10` (percent).
	- Behavior: `ERROR_PCT` percent of requests send malformed JSON to `/items` to trigger exceptions; remaining requests are normal traffic.
	- Run (example): `ERROR_PCT=15 DURATION=120 ./scripts/02_5xx_error_rate.sh`

- `03_latency_p95.sh`
	- Purpose: create occasional high-concurrency bursts to increase p95 latency.
	- Defaults: `BASE_URL="http://localhost:8080"`, `DURATION=300`.
	- Behavior: most requests are single-shot; ~12% of the time the script launches a burst of 20–60 parallel requests.
	- Run: `./scripts/03_latency_p95.sh`

- `04_top_endpoints.sh`
	- Purpose: focus traffic on a specific endpoint and generate periodic bursts to exercise that endpoint.
	- Usage: `./scripts/04_top_endpoints.sh [ENDPOINT]` (default `ENDPOINT=/`).
	- Environment overrides: `BASE_URL`, `DURATION`, `BURST_EVERY`, `BURST_MIN`, `BURST_MAX`, `SLEEP_MIN`, `SLEEP_MAX`.
	- Example: `BASE_URL=http://localhost:8080 DURATION=180 ./scripts/04_top_endpoints.sh /items`

- `05_exceptions_rate.sh`
	- Purpose: generate a roughly constant rate of internal exceptions (used to exercise `app_errors_total`).
	- Defaults (in-script): `BASE_URL=http://localhost:8080`, `DURATION=300`, `TARGET_EPS=5` (target exceptions per second estimate).
	- Behavior: sends malformed JSON to `/items` repeatedly with jitter to approximate the requested exceptions/sec.
	- Run (example): `TARGET_EPS=10 DURATION=120 ./scripts/05_exceptions_rate.sh`

Usage notes

- Make scripts executable if needed: `chmod +x scripts/*.sh`.
- Most scripts accept environment variable overrides for `BASE_URL` and `DURATION`. If a script uses explicitly defined defaults, you can still override them by exporting a variable in the shell before running.

