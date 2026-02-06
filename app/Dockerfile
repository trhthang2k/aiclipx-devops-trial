# --- Builder: build venv with pinned safe tooling + constraints ---
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


# --- Runtime: ensure BOTH system and venv are clean for Trivy ---
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

# Copy venv first (so we can fix venv packages deterministically)
COPY --from=builder ${VENV_PATH} ${VENV_PATH}

# 1) Fix SYSTEM python packages (Trivy scans these)
RUN python -m pip install --upgrade pip \
    && python -m pip install --upgrade --force-reinstall --no-deps \
         "wheel==${WHEEL_VERSION}" \
         "jaraco.context==${JARACO_CONTEXT_VERSION}" \
    && python -m pip check

# 2) Fix VENV packages too (Trivy can also detect these)
RUN ${VENV_PATH}/bin/pip install --upgrade --force-reinstall --no-deps \
         "wheel==${WHEEL_VERSION}" \
         "jaraco.context==${JARACO_CONTEXT_VERSION}" \
    && ${VENV_PATH}/bin/pip check

COPY --chown=1000:1000 app.py /app/app.py
COPY --chown=1000:1000 requirements.txt /app/requirements.txt

USER appuser
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import sys,urllib.request as u; r=u.urlopen('http://127.0.0.1:8080/health/ready'); sys.exit(0 if r.getcode()==200 else 1)"

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8080", "app:app"]
