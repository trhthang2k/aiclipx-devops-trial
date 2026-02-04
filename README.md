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

# aiClipx — Service & Monitoring (DevOps overview)

This repository contains a small containerized Flask service and a local monitoring stack (Prometheus + Grafana) intended for DevOps evaluation, demonstrations, and the AiClipX trial exercise.

The project is designed to be runnable locally with Docker Compose and to demonstrate basic CI/CD/observability practices:
- Container image built with a multi-stage `Dockerfile`.
- Structured JSON logging to stdout for container-native log collection.
- Prometheus metrics exposition and a provisioned Grafana dashboard.
- Health endpoints and a container `HEALTHCHECK` for release-safety basics.

Quick start (local)

1. Copy example env and set a secure Grafana password:

```bash
cp .env.example .env
# edit .env and set GF_SECURITY_ADMIN_PASSWORD to a secure value
```

2. Build and start the stack:

```bash
docker compose up --build
```

3. Useful UIs

- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (user `admin`, password from your `.env`)

Smoke checks

```bash
curl http://localhost:8080/
curl http://localhost:8080/items
curl -X POST -H "Content-Type: application/json" -d '{"name":"demo"}' http://localhost:8080/items
curl http://localhost:8080/metrics | head -n 40
```

Secure configuration & image pinning

- This repository uses an `.env` file (see `.env.example`) to avoid hard-coded credentials in `docker-compose.yml`.
- Available variables in `.env.example`:
  - `GF_SECURITY_ADMIN_PASSWORD` — Grafana admin password (change immediately).
  - `PROMETHEUS_IMAGE` — Prometheus image tag (defaults to a pinned version).
  - `GRAFANA_IMAGE` — Grafana image tag (defaults to a pinned version).
- Do **not** commit `.env` to source control. Prefer Docker secrets or a cloud secret manager for shared or production environments.
- You can override images at runtime:

```bash
PROMETHEUS_IMAGE=prom/prometheus:v2.49.0 GRAFANA_IMAGE=grafana/grafana:9.5.2 docker compose up --build
```

Service summary

- `app/` — Flask service source, `Dockerfile`, and `requirements.txt`.
- `docker-compose.yml` — local stack: `app`, `prometheus`, and `grafana`.
- `prometheus/prometheus.yml` — Prometheus scrape configuration.
- `grafana/provisioning/` — Grafana provisioning: datasource and dashboard JSON.
- `scripts/` — traffic generators used to create demo load and errors.
- `evidence/` — example screenshots / evidence files used for demonstration.

Health checks

- Liveness: `GET /health/live` — verifies the process is running.
- Readiness: `GET /health/ready` — indicates whether the app is ready to receive traffic. The runtime image also includes a `HEALTHCHECK` that calls `/health/ready`.

Logging

- Logs are emitted in JSON to stdout via `python-json-logger` (see `app/app.py`). This makes logs easy to collect with a shipper (Vector, Fluent Bit, Fluentd) or platform logging.
- Recommendation: add a log forwarder (Vector/Fluent Bit) to collect, parse, and index logs in a central system for any real deployment.

Monitoring explanation

- Stack: Prometheus (scrape & storage) + Grafana (visualisation).
- The app exposes Prometheus metrics at `/metrics` using the `prometheus_client` library.
- Key metrics:
  - `app_requests_total{method,endpoint,http_status}` — request counters
  - `app_request_latency_seconds_bucket/_count/_sum` — histogram buckets for latency
  - `app_errors_total` — internal exception counter
- Grafana is provisioned with a dashboard that uses `rate()` and `histogram_quantile()` queries to show request rate, p95 latency, error rate, and top endpoints.

Design decisions (short)

- Multi-stage Dockerfile to keep the runtime image minimal and reproducible.
- Run as a non-root user in the container for improved security.
- Expose Prometheus metrics for accurate, pull-based monitoring.
- Use JSON logs to stdout to follow container-native logging best practices.
- Provision Grafana dashboards to make the visualisation reproducible across restarts.

Identified risks & recommended improvements

These are actionable items to make the stack more production-ready:

- Secrets: switch from `.env` to Docker secrets or a secret manager (Vault, AWS Secrets Manager, Kubernetes Secrets) for sensitive values.
- Persistence: add a persistent volume for Prometheus (e.g. `./prometheus/data:/prometheus`) and set a retention policy to retain metrics across restarts.
- Alerting & recording rules: add `prometheus/rules.yml` to create recording rules for expensive queries (e.g., p95) and alert rules for high 5xx rate and instance down; add `alertmanager` in the Compose file for notifications.
- Resource constraints: declare CPU/memory limits in production orchestration to avoid noisy-neighbour issues.
- Metrics correctness: `app/app.py` currently increments request counters in handlers and again in the `after_request` hook; remove duplicate increments to avoid double-counting.
- Logging hygiene: avoid logging raw request bodies or sensitive fields; sanitize before logging.

Improvement roadmap (suggested next steps)

1. Add Prometheus persistence and retention settings in `docker-compose.yml`.
2. Add `prometheus/rules.yml` and an `alertmanager` service; define basic alerts and recording rules.
3. Convert sensitive config to Docker secrets and document deployment steps.
4. Add a lightweight log forwarder example (Vector/Fluent Bit) and example configuration.
5. Fix metrics double-counting in `app/app.py` and add unit tests for metrics correctness.

How to run the traffic generators

The `scripts/` folder contains utility scripts to generate traffic used for demos. Make them executable and run from the repo root:

```bash
chmod +x scripts/*.sh
./scripts/01_request_rate.sh
```

Contact / Notes

This repository is intended for local evaluation and demonstration. Do not use it unchanged in production — apply the recommended hardening steps above before deploying in a shared or production environment.
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
  └── evidence.pdf              # screen shot for evidence

Notes:
- Keep `app/` focused on the service implementation and metrics exposition.
- Keep monitoring config under `prometheus/` and `grafana/provisioning/` for easy local provisioning.
- Use `scripts/` to store small traffic generators and diagnostics that help reproduce demo scenarios.


