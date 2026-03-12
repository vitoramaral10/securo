# ---- Stage 1: Build frontend ----
FROM node:22-slim AS frontend-build

WORKDIR /app

COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci

COPY frontend/ .
RUN npm run build

# ---- Stage 2: Final image (backend + frontend static) ----
FROM python:3.13-slim

WORKDIR /app

# Install system deps: asyncpg build deps + nginx + supervisor
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Dedicated non-root runtime user for app processes
RUN useradd --system --create-home --uid 10001 appuser

# Copy backend code and install deps
COPY backend/ .
RUN pip install --no-cache-dir .

# Copy built frontend into nginx serve path
COPY --from=frontend-build /app/dist /usr/share/nginx/html

# Copy configs
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/securo.conf
COPY docker/entrypoint.sh /entrypoint.sh

# Remove default nginx site
RUN rm -f /etc/nginx/sites-enabled/default \
    && chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
