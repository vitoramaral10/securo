#!/bin/sh
set -e

echo "Waiting for infrastructure services (db/redis)..."
python - <<'PY'
import os
import socket
import sys
import time
from urllib.parse import urlparse


def wait_for_service(name: str, host: str, port: int, timeout_s: int = 120) -> None:
	deadline = time.time() + timeout_s
	attempt = 0
	while time.time() < deadline:
		attempt += 1
		try:
			socket.getaddrinfo(host, port)
			with socket.create_connection((host, port), timeout=2):
				print(f"{name} is ready at {host}:{port} (attempt {attempt})")
				return
		except OSError as exc:
			print(f"Waiting for {name} at {host}:{port} (attempt {attempt}): {exc}")
			time.sleep(2)

	print(f"Timeout waiting for {name} at {host}:{port}", file=sys.stderr)
	sys.exit(1)


db_url = os.environ.get("DATABASE_URL", "")
if db_url:
	parsed_db = urlparse(db_url)
	if parsed_db.hostname and parsed_db.port:
		wait_for_service("database", parsed_db.hostname, parsed_db.port)

redis_url = os.environ.get("REDIS_URL", "")
if redis_url:
	parsed_redis = urlparse(redis_url)
	if parsed_redis.hostname and parsed_redis.port:
		wait_for_service("redis", parsed_redis.hostname, parsed_redis.port)
PY

echo "Running database migrations..."
alembic upgrade head

echo "Starting services..."
exec supervisord -c /etc/supervisor/conf.d/securo.conf
