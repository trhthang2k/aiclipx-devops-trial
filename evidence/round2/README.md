# Round 2 – Evidence Package

This document explains how this repository satisfies the round‑2 assignment requirements and how to reproduce the evidence from a clean clone.

## 1. Mapping to the Assignment

- **A) CI / Release Safety**  → GitHub Actions workflow [.github/workflows/ci.yml](../../.github/workflows/ci.yml) and PR template [.github/pull_request_template.md](../../.github/pull_request_template.md).
- **B) Alerting (Prometheus)** → Alert rules in [prometheus/rules/alerts.yml](../../prometheus/rules/alerts.yml) and dashboard queries in [grafana/provisioning/dashboards/app_dashboard.json](../../grafana/provisioning/dashboards/app_dashboard.json).
- **C) Evidence Package** → This README, screenshots under [evidence/round2/screenshots](screenshots), and the traffic helper scripts under [scripts](../../scripts).

All examples are self‑contained and use only local Docker/Compose and mock values from `.env.example`.

## 1.1 Design decisions and trade‑offs

- **Single Python service with a minimal test suite** – focuses on core API behaviour (`/`, `/items`, basic validation) in [tests/test_app.py](../../tests/test_app.py) instead of full coverage, to keep the homework small while still showing how tests plug into CI.
- **Multi‑stage Dockerfile and non‑root user** – [app/Dockerfile](../../app/Dockerfile) installs dependencies in a builder stage and runs the app as an unprivileged `appuser` in a slim runtime image, prioritising reproducibility and container security over the absolute smallest possible image size.
- **Short alert `for` windows for demos** – Prometheus rules in [prometheus/rules/alerts.yml](../../prometheus/rules/alerts.yml) use `rate()` over several minutes but a short `for` (1–3 minutes) so alerts can FIRE quickly during interviews; annotations describe the longer SLO window you would use in production.
- **Security scans tuned for fast feedback** – CI runs `pip-audit` for Python deps and Trivy with `severity: CRITICAL` and `ignore-unfixed: true` to keep the pipeline fast and focused for this exercise; a real pipeline would likely include HIGH severity and additional policies.
- **Local‑only observability stack** – `docker-compose.yml` brings up Prometheus and Grafana with in‑container storage only, which is enough to demonstrate alerting and dashboards without committing to a particular long‑term storage solution.

## 2. CI & Release Safety (Part A)

### 2.1 Workflow overview

The GitHub Actions workflow [.github/workflows/ci.yml](../../.github/workflows/ci.yml) runs on:

- Every push to `main`.
- Every `pull_request` targeting the repository.

It uses Python 3.11 and a single job `build-test` with these steps:

| Order | Step | Tooling | Purpose |
| --- | --- | --- | --- |
| 1 | Checkout | `actions/checkout@v4` | Fetch the repository code for the job. |
| 2 | Set up Python | `actions/setup-python@v5` | Install the requested Python version for tests and tools. |
| 3 | Install dependencies | `pip` | Install `app/requirements.txt` plus `pytest`, `ruff`, and `pip-audit`. |
| 4 | Dependency vulnerability scan | `pip-audit` | Scan installed Python dependencies for known CVEs. |
| 5 | Lint & format check | `ruff check .` and `ruff format --check .` | Enforce style and formatting before build and release. Uses `set -o pipefail` and writes detailed logs to the GitHub step summary. |
| 6 | Unit tests | `pytest` running [tests/test_app.py](../../tests/test_app.py) | Exercise the Flask API (`/`, `/items`, validation) via Flask’s test client. Logs are also attached to the GitHub step summary. |
| 7 | Secret scanning (source) | `gitleaks/gitleaks-action@v2` | Detect hard‑coded secrets in the repository. |
| 8 | Build Docker image | `docker build` on [app](../../app) | Build the runtime image from [app/Dockerfile](../../app/Dockerfile), tagged as `aiclipx-devops-trial:${GITHUB_SHA}` and `aiclipx-devops-trial:latest`. |
| 9 | List Docker images | `docker images` | Help debug build/push issues by listing built images. |
| 10 | Image vulnerability scan | `aquasecurity/trivy-action` | Scan the built Docker image for OS and library vulnerabilities and secrets (CRITICAL severity, `ignore-unfixed: true`). Report is attached to the GitHub step summary. |

The job is configured to **fail fast**: any non‑zero exit code from lint, tests, security scans, or image build will fail the workflow and block the PR.

### 2.2 Branch / PR discipline

Pull requests use the template [.github/pull_request_template.md](../../.github/pull_request_template.md), which requires authors to:

- Summarise the change.
- Attach evidence links:
	- Link to the related CI run.
	- Proof of alert configuration (config file or UI screenshot).
	- Screenshot of an alert firing (simulation acceptable).
	- Command list to reproduce locally if build/test steps changed.
- Provide a minimal reviewer checklist (CI green, alert rules updated/unchanged, evidence attached).

This keeps PRs lightweight but still enforces discipline and traceability.

### 2.3 Image provenance and versioning

The CI build step tags images with the immutable Git commit SHA and a `latest` tag. For a real release process, this repo recommends:

- Tagging release images with semantic versions (for example `aiclipx-devops-trial:v1.2.0`) **and** publishing the corresponding image digest (`@sha256:…`).
- Recording release notes (GitHub Releases or CHANGELOG) that include:
	- The image tag and digest.
	- A link to the successful CI run.
	- A short summary of alerts verified in the environment.
	- Rollback instructions and any migration notes.
- Promoting images from a temporary `ci` or `staging` tag to `prod` only after the CI workflow is green and the alerting checks below have been exercised.

## 3. Alerting (Part B)

Prometheus is configured via [prometheus/prometheus.yml](../../prometheus/prometheus.yml) to scrape the Flask app at `app:8080` and to load alert rules from [prometheus/rules/alerts.yml](../../prometheus/rules/alerts.yml).

The app exposes metrics using `prometheus_client` in [app/app.py](../../app/app.py):

- `app_requests_total{method,endpoint,http_status}` – request counter.
- `app_request_latency_seconds_bucket` (and `_sum`, `_count`) – latency histogram by endpoint.
- `app_errors_total` – counter of internal exceptions.

The alert rules are defined in a single rule group `app-observability` and are designed to be **actionable but not noisy**. All rules use `rate()` over multiple minutes and a `for` clause to avoid firing on brief spikes. For local demos the `for` windows are intentionally short; annotations describe longer SLO‑style expectations.

### 3.1 AppHigh5xxErrorRate – 5xx error rate elevated

- **Location**: [prometheus/rules/alerts.yml](../../prometheus/rules/alerts.yml)
- **Expr** (simplified):
	- 5xx error rate over 5 minutes: `sum(rate(app_requests_total{endpoint!~"/(metrics|health/.*)", http_status=~"5.."}[5m]))`.
	- Total request rate over 5 minutes: `sum(rate(app_requests_total{endpoint!~"/(metrics|health/.*)"}[5m]))`.
	- Condition: 5xx rate / total rate `> 0.05` (5%) **and** total rate `> 0.5` req/s.
	- `for: 1m` (shortened so it can FIRE quickly in local demos).
- **Severity**: `critical`.
- **Rationale**: sustained 5xx error rate above 5% indicates a serious regression while still protecting against noise at very low traffic.
- **Runbook (summary)**:
	1. Open Grafana (provisioned dashboard `App Overview`) and inspect the “User 5xx Error Rate” panel.
	2. Use `docker compose logs app` to inspect JSON logs and recent stack traces.
	3. Check recent deployments/merges and roll back to the last known good image if needed.

### 3.2 AppHighP95Latency – p95 latency elevated

- **Expr** (simplified):
	- Compute 95th percentile latency over 5 minutes for user endpoints:
		`histogram_quantile(0.95, sum by (le) (rate(app_request_latency_seconds_bucket{endpoint!~"/(metrics|health/.*)"}[5m]))) > 0.5`.
	- Require total request rate `> 0.5` req/s.
	- `for: 1m` (short for demo).
- **Severity**: `warning`.
- **Rationale**: p95 above 0.5 s (≈ 5× the typical ~100 ms baseline) across several minutes points to contention or a performance regression rather than a single slow request.
- **Runbook (summary)**:
	1. In Grafana, inspect the “p95 Latency” panel to locate when the spike started.
	2. Compare with “User Request Rate” and “Top Endpoints” to see whether specific endpoints or traffic bursts are responsible.
	3. Review application logs for slow operations (database calls, external APIs, queues) and scale out or disable the problematic path if required.

### 3.3 AppHighExceptionRate – internal exceptions elevated

- **Expr**: `rate(app_errors_total[2m]) > 1` with `for: 1m`.
- **Severity**: `warning`.
- **Rationale**: more than one internal exception per second over several minutes indicates instability or hostile traffic, while still ignoring small spikes.
- **Runbook (summary)**:
	1. Use the “Internal Exceptions Rate” panel in Grafana to confirm the timing and magnitude of the spike.
	2. Use `docker compose logs app` to capture stack traces and example payloads.
	3. If caused by malformed client traffic, add validation or rate‑limits; if caused by a code regression, roll back and open an incident ticket.

### 3.4 AppTrafficDrop – traffic drop to near‑zero (optional alert)

- **Expr**: `sum(rate(app_requests_total{endpoint!~"/(metrics|health/.*)"}[2m])) < 0.05` with `for: 3m`.
- **Severity**: `warning`.
- **Rationale**: total user traffic below ~0.05 req/s (≈ 3 requests/minute) for multiple minutes suggests the service is down, unreachable, or disconnected from users.
- **Runbook (summary)**:
	1. Check the Grafana “User Request Rate” panel to confirm the drop.
	2. In Prometheus, open **Status → Targets** to confirm whether `app:8080` is still up.
	3. Run a manual health probe such as `curl http://localhost:8080/health/live` from the host or a container.
	4. If the app is down, restart the container and investigate system and application logs for the root cause.

## 4. Reproducing the Evidence (Part C)

### 4.1 From a clean clone

```bash
git clone <repo-url>
cd aiclipx-devops-trial

# (Optional but recommended) create and activate a virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install Python dependencies and dev tools
pip install -r app/requirements.txt pytest ruff pip-audit

# Run unit tests
pytest

# Lint and format check
ruff check .
ruff format --check .

# Dependency vulnerability scan
pip-audit

# Build the application Docker image
cd app
docker build -t aiclipx-devops-trial:ci .
cd ..

# Start the full observability stack (app + Prometheus + Grafana)
cp .env.example .env
echo "GF_SECURITY_ADMIN_PASSWORD=changeme" >> .env  # demo only; do not use in production
docker compose up -d --build
```

### 4.2 Triggering alerts with synthetic traffic

Traffic and error patterns are generated by [scripts/06_alert_evidence_runner.sh](../../scripts/06_alert_evidence_runner.sh):

- 5xx error rate: `./scripts/06_alert_evidence_runner.sh 5xx`
- High p95 latency (bursty slow path): `./scripts/06_alert_evidence_runner.sh latency`
- Internal exceptions: `./scripts/06_alert_evidence_runner.sh exceptions`
- Traffic drop to near‑zero: `./scripts/06_alert_evidence_runner.sh drop`

Each scenario drives HTTP requests against `http://localhost:8080` until the corresponding Prometheus alert transitions to `PENDING` and then `FIRING`.

## 5. Evidence Artifacts (Screenshots)

Screenshots for this round live in [evidence/round2/screenshots](screenshots) and correspond to the requirements as follows:

- `CI-success.png` – Successful GitHub Actions run of the `CI` workflow, showing lint, tests, security scans, and Docker image build all passing.
- `CI-failed.png` – Example CI run failing during the `Lint & format check` step because of a `ruff` error, demonstrating that the pipeline blocks merges on code‑quality issues.
- `alert-1.png` and `alert-2.png` – Prometheus “Alerts” UI listing the four rules (`AppHigh5xxErrorRate`, `AppHighP95Latency`, `AppHighExceptionRate`, `AppTrafficDrop`) loaded from `/etc/prometheus/rules/alerts.yml`.
- `alert-firing.png` and `alert-firing-1.png` – Prometheus UI showing alerts such as `AppHigh5xxErrorRate` and `AppHighExceptionRate` in `FIRING` state while traffic is generated by the scripts above.

These images provide visual proof that the CI pipeline, alert configuration, and alert firing behaviour match the design described here.

## 6. Top 5 Risks and Mitigations

1. **No outbound alert channel**  
	 - *Risk*: Alerts are visible only in the Prometheus UI; there is no Alertmanager or notification channel.  
	 - *Mitigation*: Add Alertmanager to `docker-compose.yml` and configure at least one notification route (email, Slack, or PagerDuty) before any real production deployment.

2. **Prometheus data is not persisted**  
	 - *Risk*: The current Compose stack does not mount a persistent volume for Prometheus; container restarts lose historical metrics.  
	 - *Mitigation*: Add a volume such as `./prometheus/data:/prometheus` and configure an explicit retention policy (for example `--storage.tsdb.retention.time=15d`).

3. **CI depends on public package and image registries**  
	 - *Risk*: Outages or rate limits on PyPI or Docker Hub could break CI.  
	 - *Mitigation*: Use a caching proxy or internal artifact registry for Python wheels and base images; pin image digests for reproducibility.

4. **Secrets could leak in CI logs**  
	 - *Risk*: Although `.env` is not committed and Gitleaks scans the repo, misconfigured secrets could still appear in logs.  
	 - *Mitigation*: Store secrets only in GitHub encrypted secrets, avoid echoing them, and configure GitHub Action masking for any sensitive patterns.

5. **Limited test coverage**  
	 - *Risk*: Current tests in [tests/test_app.py](../../tests/test_app.py) cover only basic happy‑path and validation for `/` and `/items`.  
	 - *Mitigation*: Extend tests to cover error conditions, metrics correctness (for example, verifying `app_requests_total` and `app_errors_total` increments), and contract tests for additional endpoints as the service grows.

This evidence package, together with the CI workflow, alert rules, and screenshots, demonstrates a minimal but realistic setup for safe releases and actionable monitoring in a small Flask service.

