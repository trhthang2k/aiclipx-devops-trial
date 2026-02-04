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

Add recording or alerting rules
- Create YAML files under `prometheus/rules/` (create the directory).
- Include them in `prometheus/prometheus.yml` with a `rule_files:` entry, e.g.: 

```yaml
rule_files:
  - 'rules/*.yml'
```

- After adding rules restart Prometheus container: `docker compose restart prometheus`.

Verification & troubleshooting
- Check scrape status: `http://localhost:9090/targets`.
- View metrics from app: `http://localhost:8080/metrics`.
- Prometheus logs: `docker compose logs prometheus`.
