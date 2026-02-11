#!/bin/sh

set -euo pipefail

# Build DATABASE_URL from SQL_* when running in Docker and DATABASE_URL not set
if [ -z "${DATABASE_URL:-}" ] && [ -n "${SQL_DATABASE:-}" ]; then
    export DATABASE_URL="postgres://${SQL_USER:-postgres}:${SQL_PASSWORD:-}@${SQL_HOST:-db}:${SQL_PORT:-5432}/${SQL_DATABASE}"
fi

# Run as root: fix ownership of mounted volumes so appuser (1000) can write
APP_UID=1000
APP_GID=1000
mkdir -p /app/logs /app/media /app/staticfiles
mkdir -p /app/media/account/staff /app/media/account/applicants /app/media/account/documents
chown -R ${APP_UID}:${APP_GID} /app/logs /app/media /app/staticfiles 2>/dev/null || true
if [ -f /app/media/profile_photos ]; then
    rm -f /app/media/profile_photos
fi

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

# Run Django commands as appuser (so DB/files are owned correctly)
# Create migrations if missing (e.g. first run with no migration files)
gosu ${APP_UID}:${APP_GID} python manage.py makemigrations --noinput

# Run migrations
gosu ${APP_UID}:${APP_GID} python manage.py migrate --noinput

# Production: collect static files (for nginx to serve)
if [ "${DEBUG:-0}" = "0" ]; then
    gosu ${APP_UID}:${APP_GID} python manage.py collectstatic --noinput --clear 2>/dev/null || true
fi

# Run the main command (gunicorn) as appuser
exec gosu ${APP_UID}:${APP_GID} "$@"
