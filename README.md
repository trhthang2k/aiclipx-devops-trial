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
- Grafana: http://localhost:3000 (default user: `admin`, password: `admin`)

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
---

File list / quick references

- `app/` (service source)
- `docker-compose.yml`
- `prometheus/prometheus.yml`
- `grafana/provisioning/dashboards/app_dashboard.json`
- `scripts/generate_traffic_rich.sh`

End of overview.

