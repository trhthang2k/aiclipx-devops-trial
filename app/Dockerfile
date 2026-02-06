# --- Builder: install deps into an isolated venv (Wolfi base) ---
FROM cgr.dev/chainguard/python:3.11-dev AS builder

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VENV_PATH=/venv \
    PATH=/venv/bin:$PATH

COPY requirements.txt ./

RUN python -m venv "$VENV_PATH" \
    && "$VENV_PATH"/bin/pip install --upgrade pip \
    && "$VENV_PATH"/bin/pip install --no-cache-dir -r requirements.txt \
    && "$VENV_PATH"/bin/pip check

COPY app.py app.py

# --- Final: minimal non-root runtime with patched packages ---
FROM cgr.dev/chainguard/python:3.11

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VENV_PATH=/venv \
    PATH=/venv/bin:$PATH

COPY --from=builder /venv /venv
COPY --from=builder /app/app.py /app/app.py
COPY requirements.txt requirements.txt

# Chainguard images run as non-root by default; ensure app directory ownership
RUN chown -R nonroot:nonroot /app

USER nonroot
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import sys, urllib.request as u; r = u.urlopen('http://127.0.0.1:8080/health/ready'); sys.exit(0 if r.getcode() == 200 else 1)" || exit 1

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8080", "app:app"]
