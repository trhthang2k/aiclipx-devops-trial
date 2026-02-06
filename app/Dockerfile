# --- Builder stage: install build deps and Python packages ---
FROM python:3.11.14-slim AS builder

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY requirements.txt /app/requirements.txt

# Install build deps, upgrade pip, and install packages into /install
RUN apt-get update \
		&& apt-get upgrade -y --no-install-recommends \
		&& apt-get install -y --no-install-recommends build-essential gcc \
		&& pip install --no-cache-dir -U pip setuptools "wheel==0.46.2" "jaraco.context==6.1.0" \
		&& pip install --prefix=/install --no-cache-dir -r /app/requirements.txt \
		&& apt-get purge -y --auto-remove build-essential gcc \
		&& rm -rf /var/lib/apt/lists/*


# --- Final stage: runtime image ---
FROM python:3.11.14-slim

LABEL org.opencontainers.image.source="https://example.com/aiClipx-trial"

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application files
COPY --chown=1000:1000 app.py /app/app.py
COPY --chown=1000:1000 requirements.txt /app/requirements.txt

# Create non-root user with fixed UID and set permissions
RUN apt-get update \
		&& apt-get upgrade -y --no-install-recommends \
		&& rm -rf /var/lib/apt/lists/* \
		&& useradd -u 1000 --create-home appuser \
		&& chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

# Simple healthcheck using Python stdlib (runs as container user)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
	CMD python -c "import sys,urllib.request as u; r=u.urlopen('http://127.0.0.1:8080/health/ready'); sys.exit(0 if r.getcode()==200 else 1)" || exit 1

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8080", "app:app"]
