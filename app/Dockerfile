# --- Builder stage: install build deps and Python packages ---
FROM python:3.11-alpine AS builder

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV VENV_PATH="/opt/venv"
ENV PATH="${VENV_PATH}/bin:${PATH}"

COPY requirements.txt /app/requirements.txt

# Install build deps, create virtualenv, and install packages into it
RUN python -m venv "${VENV_PATH}" \
	&& apk add --no-cache build-base \
	&& pip install --no-cache-dir --upgrade pip \
	&& pip install --no-cache-dir -r /app/requirements.txt \
	&& apk del build-base


# --- Final stage: runtime image ---
FROM python:3.11-alpine

LABEL org.opencontainers.image.source="https://example.com/aiClipx-trial"

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV VENV_PATH="/opt/venv"
ENV PATH="${VENV_PATH}/bin:${PATH}"

# Copy virtualenv from builder
COPY --from=builder ${VENV_PATH} ${VENV_PATH}

# Copy application files
COPY --chown=1000:1000 app.py /app/app.py
COPY --chown=1000:1000 requirements.txt /app/requirements.txt

# Create non-root user with fixed UID and set permissions
RUN adduser -D -u 1000 appuser \
	&& chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

# Simple healthcheck using Python stdlib (runs as container user)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
	CMD python -c "import sys,urllib.request as u; r=u.urlopen('http://127.0.0.1:8080/health/ready'); sys.exit(0 if r.getcode()==200 else 1)" || exit 1

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8080", "app:app"]
