#!/bin/bash
# Install daily database backup cron (midnight local time → DigitalOcean Spaces).
#
# Usage (on production server, from backend repo):
#   sudo ./deploy/install-backup-cron.sh
#
# Optional in .env:
#   BACKUP_TZ=Asia/Jakarta          # cron timezone (default: Asia/Jakarta)
#   BACKUP_RETENTION_DAYS=30        # days to keep in Spaces
#   DO_SPACES_BACKUP_PREFIX=db-backups/kmsconnect

set -euo pipefail

if [ "${EUID:-0}" -ne 0 ]; then
    echo "Run as root: sudo ./deploy/install-backup-cron.sh" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_SCRIPT="$APP_DIR/deploy/backup-db.sh"
LOG_FILE="/var/log/kms-connect-db-backup.log"
CRON_FILE="/etc/cron.d/kms-connect-db-backup"

if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo "Missing backup script: $BACKUP_SCRIPT" >&2
    exit 1
fi
chmod +x "$BACKUP_SCRIPT"

read_env_var() {
    local key="$1"
    local default="${2:-}"
    local val=""
    if [ -f "$APP_DIR/.env" ]; then
        val="$(grep -E "^${key}=" "$APP_DIR/.env" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '\r\"')"
    fi
    echo "${val:-$default}"
}

BACKUP_TZ="$(read_env_var BACKUP_TZ Asia/Jakarta)"

if ! grep -q '^DO_SPACES_BUCKET_NAME=' "$APP_DIR/.env" 2>/dev/null; then
    echo "WARNING: DO_SPACES_BUCKET_NAME is not set in $APP_DIR/.env" >&2
    echo "  Add Spaces credentials before the first scheduled backup runs." >&2
fi

cat > "$CRON_FILE" <<EOF
# KMS-Connect — daily PostgreSQL backup to DigitalOcean Spaces (midnight local time)
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
CRON_TZ=${BACKUP_TZ}

0 0 * * * root ${BACKUP_SCRIPT} >>${LOG_FILE} 2>&1
EOF

chmod 644 "$CRON_FILE"
touch "$LOG_FILE"
chmod 640 "$LOG_FILE" 2>/dev/null || true

echo "Installed ${CRON_FILE}"
echo "  Schedule: every day at 00:00 (${BACKUP_TZ})"
echo "  Script:   ${BACKUP_SCRIPT}"
echo "  Log:      ${LOG_FILE}"
echo ""
echo "Test now:  sudo ${BACKUP_SCRIPT}"
echo "View log:  sudo tail -f ${LOG_FILE}"
