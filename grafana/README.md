## Grafana — Provisioned dashboards (concise)

Purpose
- Provision Grafana with a Prometheus datasource and a prebuilt `App Overview` dashboard for local testing and demos.

Quick start
- Start stack: `docker compose up --build`
- Grafana UI: http://localhost:3000  (admin / admin)
- Verify: Configuration → Data sources shows Prometheus; Dashboards → Manage shows `App Overview`.

Provisioning files
- Datasource: [grafana/provisioning/datasources/datasource.yml](grafana/provisioning/datasources/datasource.yml)
- Dashboards provider: [grafana/provisioning/dashboards/dashboard.yml](grafana/provisioning/dashboards/dashboard.yml)
- Dashboard JSON: [grafana/provisioning/dashboards/app_dashboard.json](grafana/provisioning/dashboards/app_dashboard.json)

How to update a dashboard
1. Edit or replace the JSON in `grafana/provisioning/dashboards/`.
2. Restart Grafana container: `docker compose restart grafana`.

Key notes
- Grafana identifies dashboards by the `uid` field inside JSON (the sample dashboard uid is `app-overview`). Filenames do not need to match the uid.
- Ensure provisioning files are readable by the Grafana container and avoid duplicate `uid` values.

## Dashboard metrics — PromQL & meaning

Below are the dashboard panels, the exact PromQL used in the provisioned dashboard, and a short explanation. These queries read metrics exported by the app (listed after the panel descriptions).

- **User Request Rate (req/s)**
	- PromQL: `sum(rate(app_requests_total{endpoint!~"/(metrics|health/.*)"}[1m]))`
	- Meaning: total requests-per-second across user-facing endpoints. `rate(...[1m])` computes the per-second slope of the request counter over 1 minute; `sum()` aggregates across endpoints.
	- Source: `app_requests_total{method,endpoint,http_status}` (counter).

- **User 5xx Error Rate (%)**
	- PromQL: `100 * sum(rate(app_requests_total{endpoint!~"/(metrics|health/.*)", http_status=~"5.."}[5m])) / sum(rate(app_requests_total{endpoint!~"/(metrics|health/.*)"}[5m]))`
	- Meaning: percent of requests returning 5xx over 5 minutes. Numerator = 5xx request rate; denominator = total request rate; multiply by 100 for percent.
	- Source: `app_requests_total` with `http_status` label.

- **p95 Latency (s) — User Traffic**
	- PromQL: `histogram_quantile(0.95, sum by (le) (rate(app_request_latency_seconds_bucket{endpoint!~"/(metrics|health/.*)"}[5m])))`
	- Meaning: estimated 95th percentile response time across endpoints over 5 minutes. Steps: convert bucket counters to rates, aggregate buckets by `le`, then compute `histogram_quantile(0.95, ...)`.
	- Source: `app_request_latency_seconds_bucket{le,endpoint,...}` plus `_count`/_`sum` for other analysis.

- **Top Endpoints by Traffic (req/s) — Top 1**
	- PromQL: `topk(1, sum by (endpoint) (rate(app_requests_total{endpoint!~"/(metrics|health/.*)"}[1m])))`
	- Meaning: shows the single endpoint with the highest request rate (1-minute window).
	- Source: `app_requests_total` grouped by `endpoint`.

- **Internal Exceptions Rate (exceptions/s)**
	- PromQL: `rate(app_errors_total[5m])`
	- Meaning: per-second rate of internal exceptions observed by the app (5-minute window).
	- Source: `app_errors_total` (counter).

Notes / best practices
- Prefer `rate()` or `increase()` when using counters; avoid reading raw counter values directly.
- For histograms, aggregate buckets by `le` before calling `histogram_quantile()`.
- Heavy histogram + aggregation queries can be expensive; create Prometheus recording rules for `p95` and high-cardinality aggregates in production.

Metrics exported by the app
- `app_requests_total{method,endpoint,http_status}` — counter incremented per request.
- `app_request_latency_seconds_bucket{le,endpoint,...}` — histogram buckets for request latency; also expose `app_request_latency_seconds_count` and `app_request_latency_seconds_sum`.
- `app_errors_total` — counter of internal exceptions/errors.

Common labels available: `method`, `endpoint`, `http_status` — use these to filter or group queries.

