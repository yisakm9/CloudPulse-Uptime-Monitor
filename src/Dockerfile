# ──────────────────────────────────────────────────────────────
# CloudPulse — Dockerfile (Multi-Stage Build)
# ──────────────────────────────────────────────────────────────
# Single image, two entrypoints:
#   Web:    uvicorn main:app --host 0.0.0.0 --port 8000
#   Worker: python worker.py
# ──────────────────────────────────────────────────────────────

# ─── Stage 1: Build dependencies ─────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ─── Stage 2: Production image ───────────────────────────────
FROM python:3.11-slim AS production

# Security: run as non-root user
RUN groupadd -r cloudpulse && useradd -r -g cloudpulse cloudpulse

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Set working directory
WORKDIR /app

# Copy application source code
COPY . .

# Set ownership to non-root user
RUN chown -R cloudpulse:cloudpulse /app

# Switch to non-root user
USER cloudpulse

# Expose port for web service
EXPOSE 8000

# Default command: run the web service
# Override via Cloud Run command for the worker
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
