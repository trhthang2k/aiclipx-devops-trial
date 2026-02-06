# --- Builder stage: create venv + install deps safely ---
FROM python:3.11-alpine AS builder

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VENV_PATH=/opt/venv \
    PATH=/opt/venv/bin:$PATH \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Security-fixed versions from Trivy output
ARG SETUPTOOLS_VERSION=78.1.1
ARG WHEEL_VERSION=0.46.2
ARG JARACO_CONTEXT_VERSION=6.1.0

COPY requirements.txt .

# Build deps only in builder
RUN apk add --no-cache build-base \
    && python -m venv "$VENV_PATH" \
    && pip install --upgrade \
         "pip" \
         "setuptools==${SETUPTOOLS_VERSION}" \
         "wheel==${WHEEL_VERSION}" \
    # Force safe versions even if transitive deps try to downgrade
    && printf "jaraco.context==%s\nsetuptools==%s\nwheel==%s\n" \
         "$JARACO_CONTEXT_VERSION" "$SETUPTOOLS_VERSION" "$WHEEL_VERSION" > /tmp/constraints.txt \
    && pip install -r requirements.txt -c /tmp/constraints.txt \
    && pip check \
    && apk del build-base


# --- Final stage: runtime image ---
FROM python:3.11-alpine

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VENV_PATH=/opt/venv \
    PATH=/opt/venv/bin:$PATH \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

ARG SETUPTOOLS_VERSION=78.1.1
ARG WHEEL_VERSION=0.46.2

# (Important) Trivy scans system python packages too -> upgrade to fixed versions
RUN python -m pip install --upgrade \
        "pip" \
        "setuptools==${SETUPTOOLS_VERSION}" \
        "wheel==${WHEEL_VERSION}" \
    && adduser -D -u 1000 appuser

# Copy virtualenv from builder
COPY --from=builder ${VENV_PATH} ${VENV_PATH}

# Copy app
COPY --chown=1000:1000 app.py /app/app.py
COPY --chown=1000:1000 requirements.txt /app/requirements.txt

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import sys,urllib.request as u; r=u.urlopen('http://127.0.0.1:8080/health/ready'); sys.exit(0 if r.getcode()==200 else 1)"

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8080", "app:app"]
