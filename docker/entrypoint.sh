#!/bin/sh
set -e

echo "Running database migrations..."
alembic upgrade head

echo "Starting services..."
exec supervisord -c /etc/supervisor/conf.d/securo.conf
