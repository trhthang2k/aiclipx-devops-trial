# Round 2 — Evidence Package

## 1. Design Overview
- Goal: deliver a release-safe pipeline with unit tests, baseline security checks, and actionable alerting for key service signals.
- CI workflow `.github/workflows/ci.yml` runs on every PR and on `main`, covering lint, unit tests, Docker build, dependency audit, and secret scanning.
- Prometheus alert rules in `prometheus/rules/alerts.yml` watch 5xx error rate, p95 latency, internal exceptions, and traffic drops.

## 2. CI and Release Safety
| Step | Tooling | Purpose |
| --- | --- | --- |
| Lint & format check | ruff | Keep code quality consistent before builds. |
| Unit tests | pytest + Flask test client | Validate core endpoints and request validation. |
| Build image | docker build -t aiclipx-devops-trial:ci app | Ensure the Dockerfile builds before release. |
| Dependency scan | pip-audit | Detect Python packages with known CVEs. |
| Secret scan | gitleaks | Prevent accidental secret commits. |

### Release provenance guidance
- Tag application images with semantic versions (`vMAJOR.MINOR.PATCH`) and publish the matching SHA256 digest.
- Document release notes with CI results, alert evidence, and rollback instructions; include the image digest for verification.
- Promote images from the provisional `ci` tag to `staging`/`prod` only after the CI checklist and alert verification are complete.

## 3. Alert Rules and Runbook
| Alert | Threshold & window | Severity | Rationale | Runbook summary |
| --- | --- | --- | --- | --- |
| AppHigh5xxErrorRate | 5xx > 5% of total requests for 10 minutes | Critical | 5% 5xx breaches the trial SLO and signals a widespread regression | (1) Open "User 5xx Error Rate" panel; (2) inspect app JSON logs via docker compose logs app; (3) review recent deploys and rollback if required. |
| AppHighP95Latency | p95 > 0.5 s for 10 minutes | Warning | Five times the ~100 ms baseline, indicating contention or burst traffic | (1) Check "p95 Latency" panel; (2) review traffic and top endpoints; (3) inspect logs for slow operations and scale or throttle as needed. |
| AppHighExceptionRate | rate(app_errors_total[5m]) > 1 for 5 minutes | Warning | Sustained exception rate suggests instability or bad traffic | (1) View "Internal Exceptions" panel; (2) capture stack traces from logs; (3) block malicious payloads or rollback regression. |
| AppTrafficDrop | Total requests < 0.05 req/s for 15 minutes | Warning | Indicates the service is down or disconnected from users | (1) Confirm via "User Request Rate" panel; (2) check Prometheus target status; (3) run manual health probe; (4) restart container and investigate infrastructure. |

## 4. Reproduction Commands (clean clone)
```bash
git clone <repo-url>
cd aiclipx-devops-trial
python3 -m venv .venv && source .venv/bin/activate
pip install -r app/requirements.txt pytest ruff pip-audit
pytest
ruff check . && ruff format --check .
pip-audit
# Build image
cd app && docker build -t aiclipx-devops-trial:ci . && cd ..
# Start observability stack
cp .env.example .env && echo "GF_SECURITY_ADMIN_PASSWORD=changeme" >> .env
docker compose up -d --build
```

- Trigger 5xx alert: `TARGET_EPS=5 DURATION=120 ./scripts/05_exceptions_rate.sh`
- Trigger latency burst: `./scripts/03_latency_p95.sh`

## 5. Required Screenshots
Store images in `evidence/round2/screenshots/`:
- `ci-pass.png`: successful CI workflow run.
- `ci-fail.png`: failing run (lint/test/security) demonstrating guardrails.
- `alert-config.png`: alert configuration in Prometheus or Grafana.
- `alert-trigger.png`: alert firing screenshot (simulation allowed).

> Note: the repo only keeps placeholders; capture real screenshots after running the pipeline and alerts.

## 6. Top 5 Risks and Mitigations
1. **No outbound alert channel** — Add Alertmanager plus an on-call channel (email/chat) before production.
2. **Prometheus data not persisted** — Mount a persistent volume and set retention to preserve history across restarts.
3. **CI depends on public mirrors** — Configure a package cache or artifact mirror to avoid external outages.
4. **Secrets exposed in CI logs** — Mask environment variables and scope GitHub Actions secrets with least privilege.
5. **Limited test coverage** — Expand tests for error scenarios, metrics correctness, and contract validation.

## 2. Quy trình CI & Release safety
| Bước | Công cụ | Mục đích |
| --- | --- | --- |
| Lint & format check | `ruff` | Giữ chất lượng mã nguồn nhất quán trước khi build. |
| Unit tests | `pytest` + Flask test client | Đảm bảo các endpoint chính hoạt động và kiểm tra validation. |
| Build image | `docker build -t aiclipx-devops-trial:ci app` | Xác nhận Dockerfile hợp lệ trước khi phát hành. |
| Dependency scan | `pip-audit` | Phát hiện gói Python có CVE đã biết. |
| Secret scan | `gitleaks` | Ngăn nhầm commit bí mật vào repo. |

### Ghi chú về phát hành & provenance
- Gắn thẻ image theo semver (`vMAJOR.MINOR.PATCH`) và xuất bản digest SHA256 tương ứng.
- Tạo ghi chú phát hành kèm link digest, kết quả CI, bằng chứng alert, và hướng dẫn rollback.
- Chỉ promote image khỏi tag `ci` sang `staging/prod` sau khi checklist CI + alert verification hoàn tất.

## 3. Alert rules & runbook
| Alert | Ngưỡng & cửa sổ | Mức độ | Rationale | Runbook tóm tắt |
| --- | --- | --- | --- | --- |
| `AppHigh5xxErrorRate` | 5xx > 5% tổng request trong 10 phút | Critical | 5% 5xx cho thấy lỗi diện rộng vượt SLO thử nghiệm | (1) Mở panel "User 5xx Error Rate"; (2) đọc log JSON `docker compose logs app`; (3) kiểm tra thay đổi gần nhất / rollback. |
| `AppHighP95Latency` | p95 > 0.5s trong 10 phút | Warning | Cao gấp ~5 lần baseline 100ms, báo hiệu nghẽn | (1) Panel "p95 Latency"; (2) xem lưu lượng/top endpoints; (3) đọc log tìm tác nhân chậm, cân nhắc scale. |
| `AppHighExceptionRate` | `rate(app_errors_total[5m]) > 1` giữ 5 phút | Warning | Exception >1/s kéo dài gây nguy cơ thiếu ổn định | (1) Panel "Internal Exceptions"; (2) tra log lấy stacktrace; (3) cách ly payload xấu hoặc rollback. |
| `AppTrafficDrop` | Tổng request <0.05 req/s trong 15 phút | Warning | Lưu lượng gần như mất hẳn → app down hay routing lỗi | (1) Panel "User Request Rate"; (2) Prometheus Targets; (3) tự kiểm tra health check; (4) khởi động lại container nếu cần. |

## 4. Lệnh tái hiện (từ bản clone sạch)
```bash
git clone <repo-url>
cd aiclipx-devops-trial
python3 -m venv .venv && source .venv/bin/activate
pip install -r app/requirements.txt pytest ruff pip-audit
pytest
ruff check . && ruff format --check .
pip-audit
# Build image
cd app && docker build -t aiclipx-devops-trial:ci . && cd ..
# Khởi động stack quan sát
cp .env.example .env && echo "GF_SECURITY_ADMIN_PASSWORD=changeme" >> .env
docker compose up -d --build
```

- Tạo lỗi 5xx để thử alert: `TARGET_EPS=5 DURATION=120 ./scripts/05_exceptions_rate.sh`
- Tạo burst latency: `./scripts/03_latency_p95.sh`

## 5. Bằng chứng cần đính kèm
Đặt ảnh chụp trong `evidence/round2/screenshots/`:
- `ci-pass.png`: workflow CI thành công.
- `ci-fail.png`: ví dụ thất bại (lint/test/security) cho thấy guard hoạt động.
- `alert-config.png`: cấu hình alert trong Prometheus/Grafana.
- `alert-trigger.png`: ảnh chụp alert sau khi mô phỏng sự cố.

> **Lưu ý:** repo chỉ chứa placeholder, vui lòng thu thập ảnh thực tế sau khi chạy pipeline/alert và lưu đúng tên.

## 6. Top 5 rủi ro & giảm thiểu
1. **Thiếu cảnh báo triển khai thực** — Thiếu Alertmanager/email ⇒ đề xuất thêm Alertmanager + channel cảnh báo trước khi production.
2. **Không lưu dữ liệu Prometheus lâu dài** — Khởi động lại mất lịch sử ⇒ gắn volume persistent và đặt retention phù hợp.
3. **CI phụ thuộc internet công cộng** — Nếu kho package không sẵn ⇒ cấu hình cache nội bộ hoặc mirror artifactory.
4. **Secret leak qua log CI** — Cần mask biến môi trường và giới hạn quyền GitHub Action secrets.
5. **Thiếu kiểm thử sâu** — Mới chỉ test happy path ⇒ mở rộng test cho error handling, metrics correctness, contract test.
