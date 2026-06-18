# ─── Stage 1: dependency builder ────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# Build-time system deps (compiler + libpq headers for packages that need them)
RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc libpq-dev \
 && rm -rf /var/lib/apt/lists/*

# Copy only the requirements file first — changes here invalidate the pip layer
COPY requirements.txt .

# Create an isolated venv and install production dependencies into it
RUN python -m venv /opt/venv \
 && /opt/venv/bin/pip install --upgrade pip --no-cache-dir \
 && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# ─── Stage 2: runtime image ─────────────────────────────────────────────────
FROM python:3.11-slim AS runtime

# Runtime-only system libs (no compiler; libpq5 for psycopg, libjpeg/libpng for Pillow)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libpq5 \
      libjpeg62-turbo \
      libpng16-16 \
 && rm -rf /var/lib/apt/lists/*

# Pull the fully-populated venv from the builder stage
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Non-root user for runtime security
RUN groupadd --system appgroup \
 && useradd --system --gid appgroup --no-create-home --shell /sbin/nologin appuser

WORKDIR /app

# Copy application source (.dockerignore excludes test files, caches, secrets)
COPY . .

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8000

# Health check — uses stdlib urllib so no extra tools are required
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=4)" \
    || exit 1

# Set AUTO_RUN_MIGRATIONS=true in your environment (or docker-compose.yml) to
# let the app apply Alembic migrations automatically on startup.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
