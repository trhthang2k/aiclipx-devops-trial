## aiClipx — Service & Monitoring (DevOps overview)

This repository provides a small containerized Flask service and a local monitoring stack (Prometheus + Grafana) intended for DevOps/observability evaluation and demonstrations.

Keep this root README as a short overview. See the detailed guides in the subfolders for runbooks and troubleshooting:

- [scripts/README.md](scripts/README.md)
- [grafana/README.md](grafana/README.md)
- [prometheus/README.md](prometheus/README.md)

What this repo contains
- `app/` — Flask service source, metrics, health checks, and `Dockerfile`.
- `docker-compose.yml` — brings up `app`, Prometheus and Grafana for local testing.
- `prometheus/` — scrape configuration used to collect app metrics.
- `grafana/provisioning/` — datasource and dashboard provisioning (includes a simple dashboard).
- `scripts/` — traffic generators and helper scripts to produce load and errors.

Quick start (local)

1. Build and start the full stack:

```bash
docker-compose up --build
```

2. Useful UIs

- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (default user: `admin`, password: `admin`) — This is the default Grafana account. On first login you will be prompted to change the password; change it immediately to secure your instance.

3. Smoke checks

```bash
curl http://localhost:8080/
curl http://localhost:8080/items
curl -X POST -H "Content-Type: application/json" -d '{"name":"demo"}' http://localhost:8080/items
curl http://localhost:8080/metrics | head -n 40
```

Important endpoints

- `GET /` — service info
- `GET /metrics` — Prometheus metrics (scraped every 15s by default)
- `GET /health/live` — liveness
- `GET /health/ready` — readiness

Monitoring notes

- Prometheus scrapes the app at `/metrics` (see `prometheus/prometheus.yml`).
- Key metrics exported by the app:
  - `app_requests_total{method,endpoint,http_status}` — request counters
  - `app_request_latency_seconds_bucket/_count/_sum` — latency histogram (for percentile calculations)
  - `app_errors_total` — internal error counter
- The provided Grafana dashboard visualises request rate, p95 latency and error rate using these metrics.

Monitoring explanation

- **Stack**: Prometheus (scrape & storage) + Grafana (visualisation). Prometheus scrapes the app's `/metrics` endpoint and stores time series; Grafana is provisioned with a Prometheus datasource and a prebuilt dashboard in `grafana/provisioning/dashboards/app_dashboard.json`.
- **Key queries**: the dashboard uses `rate()` on counters for request-rate panels, `histogram_quantile()` over aggregated histogram buckets for p95, and `rate(app_errors_total[5m])` for internal exceptions.
- **Why this design**: Prometheus is lightweight and well-aligned with pull-based metrics exposition from instrumented services. Grafana provides fast visual feedback and reproducible dashboards via provisioning.

Explanation of design decisions

- **Multi-stage Dockerfile** (`app/Dockerfile`): separate builder and runtime stages to keep the final image minimal and reproducible.
- **Non-root runtime user**: the final image runs as a non-root user (`appuser`) to follow container security best practices.
- **Expose Prometheus metrics**: instrumenting the app with Prometheus client libraries enables precise, aggregated observability (counters, histograms, error counters).
- **Structured JSON logs to stdout**: application logs are emitted in JSON to stdout so container orchestrators and log shippers can collect and index them without fragile file handling.
- **Provisioned Grafana**: dashboards and datasources are configured by files under `grafana/provisioning/` so the visualisation is reproducible across restarts.

Implemented logging strategy

- **What**: `app/app.py` configures structured JSON logs (via `python-json-logger`) that write to stdout.
- **Why**: container-native logging prefers stdout/stderr; JSON makes logs machine-parseable for later ingestion into ELK/Fluentd/Vector.
- **Limitations**: this repository does not include a log-forwarder; in production, add a shipper (Vector/Fluentd/Fluent Bit) or use platform logging.

Define health checks

- **Liveness**: `GET /health/live` — verifies process is running.
- **Readiness**: `GET /health/ready` — simple readiness flag (200 when ready, 503 when not). The container image includes a `HEALTHCHECK` (in `app/Dockerfile`) that queries `/health/ready` to indicate container health to orchestrators.

Identified risks and suggested improvements

- **Hard-coded credentials**: `GF_SECURITY_ADMIN_PASSWORD=admin` in `docker-compose.yml` is insecure. Suggest using an `.env` file or Docker secrets for passwords and sensitive config.
- **No persistent storage for Prometheus**: current compose does not persist Prometheus data — add a volume (e.g., `./prometheus/data:/prometheus`) and tune retention for longer-term analysis.
- **Image pinning**: `prom/prometheus:latest` and other `latest` tags should be pinned to specific versions to avoid unintended upgrades; update `docker-compose.yml` accordingly.
- **No alerting or recording rules**: provide Prometheus `rules.yml` with recording rules for expensive queries (p95) and alert rules (high 5xx rate, instance down) plus an `alertmanager` to manage notifications.
- **Metric double-counting**: `app/app.py` currently increments request counters in both handlers (via `record_request`) and in the `after_request` hook — this can double-count requests. Remove one of the mechanisms (prefer hooks) or guard `record_request()` in handlers.
- **No resource limits**: add container resource constraints in compose for more predictable behaviour on shared machines.
- **Logging sensitive data**: ensure payloads are sanitized before logging in production; avoid logging full request bodies.

Improvement suggestions (next steps)

- Add a small `prometheus/rules.yml` with recording rules for `p95` and alerts for `high_5xx` and `instance_down` and include `alertmanager` in `docker-compose.yml`.
- Add persistent volume for Prometheus and optionally Grafana (dashboards persistency if editing via UI).
- Replace hard-coded Grafana password with an `.env`-backed secret and pin image tags.
- Add a short example `vector`/`fluent-bit` config or instructions to ship logs from stdout to a log backend.
- Fix the request counter duplication in `app/app.py` so counters are only incremented once per request.

---

File list / quick references

- `app/` (service source)
- `docker-compose.yml`
- `prometheus/prometheus.yml`
- `grafana/provisioning/dashboards/app_dashboard.json`
- `scripts/generate_traffic_rich.sh`

**Repository Structure (suggested)**

Below is a concise, recommended view of the repository structure based on the current source files:

```
aiclipx-devops-trial/
├── README.md                     # High-level overview and runbook links
├── docker-compose.yml            # Compose to run app + Prometheus + Grafana
├── app/
│   ├── Dockerfile                # Build the service image
│   ├── app.py                    # Flask service (endpoints, metrics, health)
│   └── requirements.txt          # Python dependencies
├── prometheus/
│   ├── prometheus.yml            # Prometheus scrape configuration
│   └── README.md                 # Prometheus notes and usage
├── grafana/
│   ├── README.md                 # Grafana notes
│   └── provisioning/
│       ├── dashboards/
│       │   ├── app_dashboard.json
│       │   └── dashboard.yml
│       └── datasources/
│           └── datasource.yml
├── scripts/
│   ├── 01_request_rate.sh
│   ├── 02_5xx_error_rate.sh
│   ├── 03_latency_p95.sh
│   ├── 04_top_endpoints.sh
│   ├── 05_exceptions_rate.sh
│   └── README.md                 # How to run the traffic generators
└── evidence/
  └── evidence.pdf              # Optional demo artifacts

Notes:
- Keep `app/` focused on the service implementation and metrics exposition.
- Keep monitoring config under `prometheus/` and `grafana/provisioning/` for easy local provisioning.
- Use `scripts/` to store small traffic generators and diagnostics that help reproduce demo scenarios.


