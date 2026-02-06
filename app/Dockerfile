# --- Builder: create venv and install deps ---
FROM python:3.11-alpine AS builder
WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VENV_PATH=/opt/venv \
    PATH=/opt/venv/bin:$PATH \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

ARG WHEEL_VERSION=0.46.2
ARG JARACO_CONTEXT_VERSION=6.1.0

COPY requirements.txt .

RUN apk add --no-cache build-base \
    && python -m venv "$VENV_PATH" \
    && pip install --upgrade pip \
    && printf "wheel==%s\njaraco.context==%s\n" "$WHEEL_VERSION" "$JARACO_CONTEXT_VERSION" > /tmp/constraints.txt \
    && pip install -r requirements.txt -c /tmp/constraints.txt \
    && pip check \
    && apk del build-base


# --- Runtime ---
FROM python:3.11-alpine
WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VENV_PATH=/opt/venv \
    PATH=/opt/venv/bin:$PATH \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

ARG WHEEL_VERSION=0.46.2
ARG JARACO_CONTEXT_VERSION=6.1.0

RUN adduser -D -u 1000 appuser

# Copy venv first
COPY --from=builder ${VENV_PATH} ${VENV_PATH}

# ---- HARD CLEAN: remove vulnerable stdlib bundles and old packages ----
RUN set -eux; \
  rm -rf /usr/lib/python3.11/ensurepip/_bundled/*; \
  python - <<'PY'
import shutil
import sys
from pathlib import Path

TARGET_PATTERNS = [
    "jaraco",
    "jaraco.context",
    "jaraco.context-5.3.0",
    "jaraco.context-5.3.0.dist-info",
    "wheel",
    "wheel-0.45.1",
    "wheel-0.45.1.dist-info",
    "setuptools-75.8.0",
    "setuptools-75.8.0.dist-info",
]

def purge(base: Path) -> None:
    if not base.exists():
        return
    for pattern in TARGET_PATTERNS:
        for path in base.glob(pattern):
            if path.is_dir():
                shutil.rmtree(path, ignore_errors=True)
            else:
                try:
                    path.unlink()
                except FileNotFoundError:
                    pass

for entry in sys.path:
    if entry and entry.endswith(("site-packages", "dist-packages")):
        purge(Path(entry))
PY

# Reinstall fixed versions into BOTH system python and venv
RUN set -eux; \
  python -m pip install --upgrade pip; \
  python -m pip install --upgrade --force-reinstall --no-deps \
    "wheel==${WHEEL_VERSION}" \
    "jaraco.context==${JARACO_CONTEXT_VERSION}"; \
  ${VENV_PATH}/bin/pip install --upgrade --force-reinstall --no-deps \
    "wheel==${WHEEL_VERSION}" \
    "jaraco.context==${JARACO_CONTEXT_VERSION}"; \
  python -m pip check; \
  ${VENV_PATH}/bin/pip check

COPY --chown=1000:1000 app.py /app/app.py
COPY --chown=1000:1000 requirements.txt /app/requirements.txt

USER appuser
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import sys,urllib.request as u; r=u.urlopen('http://127.0.0.1:8080/health/ready'); sys.exit(0 if r.getcode()==200 else 1)" || exit 1

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8080", "app:app"]
