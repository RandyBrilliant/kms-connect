#!/bin/sh

set -euo pipefail

# Build DATABASE_URL from SQL_* when running in Docker and DATABASE_URL not set
if [ -z "${DATABASE_URL:-}" ] && [ -n "${SQL_DATABASE:-}" ]; then
    export DATABASE_URL="postgres://${SQL_USER:-postgres}:${SQL_PASSWORD:-}@${SQL_HOST:-db}:${SQL_PORT:-5432}/${SQL_DATABASE}"
fi

# Create logs directory (for Django logging). When bind-mounted, chmod may fail; ignore.
mkdir -p /app/logs
chmod 755 /app/logs 2>/dev/null || true

# Create media directories (KMS-connect). When bind/volume-mounted, chmod may fail; ignore.
if [ ! -d /app/media ]; then
    mkdir -p /app/media
fi
if [ -f /app/media/profile_photos ]; then
    rm -f /app/media/profile_photos
fi
mkdir -p /app/media/account/staff \
         /app/media/account/applicants \
         /app/media/account/documents 2>/dev/null || true
chmod -R 755 /app/media 2>/dev/null || true

# Production checks
if [ "${DEBUG:-0}" = "0" ]; then
    if [ -z "${SECRET_KEY:-}" ] || [ "${SECRET_KEY}" = "change-me" ] || [ "${SECRET_KEY}" = "change-me-to-secure-random-key" ]; then
        echo "ERROR: SECRET_KEY must be set to a secure value in production!"
        exit 1
    fi
    if [ -z "${ALLOWED_HOSTS:-}" ]; then
        echo "WARNING: ALLOWED_HOSTS is not set in production!"
    fi
fi

# Create migrations if missing (e.g. first run with no migration files)
python manage.py makemigrations --noinput

# Run migrations
python manage.py migrate --noinput

# Production: collect static files (for nginx to serve)
if [ "${DEBUG:-0}" = "0" ]; then
    python manage.py collectstatic --noinput --clear 2>/dev/null || true
fi

exec "$@"
