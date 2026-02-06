## Prometheus — Config & quick notes

Purpose
- Collect metrics from the `app` service for local demos and dashboarding.

Quick start
- Start whole stack: `docker compose up --build`
- Prometheus UI: http://localhost:9090
- Verify targets: open `Status → Targets` and confirm `app:8080` is `UP`.

Config file
- Main config: `prometheus/prometheus.yml`
- Key settings in this repo:
  - `scrape_interval: 15s`
  - job `app` scrapes target `app:8080`
- Alert rules loaded from `prometheus/rules/alerts.yml`. Prometheus needs a restart to pick up rule changes.

Add recording or alerting rules
- Rules in this repo live under `prometheus/rules/`. Update or add `.yml` files there and they are auto-loaded via `rule_files: ['rules/*.yml']`.
- After editing rules restart Prometheus container: `docker compose restart prometheus`.

Verification & troubleshooting
- Check scrape status: `http://localhost:9090/targets`.
- View metrics from app: `http://localhost:8080/metrics`.
- Prometheus logs: `docker compose logs prometheus`.
