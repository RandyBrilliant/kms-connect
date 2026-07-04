#!/bin/bash
# Dump PostgreSQL, upload to DigitalOcean Spaces, prune backups older than retention period.
#
# Requires DO_SPACES_* in .env (same credentials as media storage).
# Usage: ./deploy/backup-db.sh
# Cron:  sudo ./deploy/install-backup-cron.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

LOG_PREFIX="[kms-connect-db-backup]"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX $*"
}

read_env_var() {
    local key="$1"
    local default="${2:-}"
    local val=""
    if [ -f "$PROJECT_ROOT/$ENV_FILE" ]; then
        val="$(grep -E "^${key}=" "$PROJECT_ROOT/$ENV_FILE" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '\r\"')"
    fi
    echo "${val:-$default}"
}

aws_cli() {
    local endpoint="https://${DO_SPACES_REGION}.digitaloceanspaces.com"
    docker run --rm \
        -e AWS_ACCESS_KEY_ID="${DO_SPACES_ACCESS_KEY_ID}" \
        -e AWS_SECRET_ACCESS_KEY="${DO_SPACES_SECRET_ACCESS_KEY}" \
        -e AWS_DEFAULT_REGION="${DO_SPACES_REGION}" \
        amazon/aws-cli:2.15.30 \
        --endpoint-url "$endpoint" \
        "$@"
}

aws_s3_cp() {
    local local_file="$1"
    local s3_uri="$2"
    local endpoint="https://${DO_SPACES_REGION}.digitaloceanspaces.com"
    docker run --rm \
        -e AWS_ACCESS_KEY_ID="${DO_SPACES_ACCESS_KEY_ID}" \
        -e AWS_SECRET_ACCESS_KEY="${DO_SPACES_SECRET_ACCESS_KEY}" \
        -e AWS_DEFAULT_REGION="${DO_SPACES_REGION}" \
        -v "${local_file}:/backup.dump.gz:ro" \
        amazon/aws-cli:2.15.30 \
        --endpoint-url "$endpoint" \
        s3 cp /backup.dump.gz "$s3_uri" \
        --only-show-errors
}

require_project_root
require_docker

SQL_DATABASE="$(read_env_var SQL_DATABASE kmsconnect)"
SQL_USER="$(read_env_var SQL_USER postgres)"
DO_SPACES_BUCKET_NAME="$(read_env_var DO_SPACES_BUCKET_NAME)"
DO_SPACES_REGION="$(read_env_var DO_SPACES_REGION sgp1)"
DO_SPACES_ACCESS_KEY_ID="$(read_env_var DO_SPACES_ACCESS_KEY_ID)"
DO_SPACES_SECRET_ACCESS_KEY="$(read_env_var DO_SPACES_SECRET_ACCESS_KEY)"
DO_SPACES_BACKUP_PREFIX="$(read_env_var DO_SPACES_BACKUP_PREFIX "db-backups/${SQL_DATABASE}")"
BACKUP_RETENTION_DAYS="$(read_env_var BACKUP_RETENTION_DAYS 30)"

if [ -z "$DO_SPACES_BUCKET_NAME" ] || [ -z "$DO_SPACES_ACCESS_KEY_ID" ] || [ -z "$DO_SPACES_SECRET_ACCESS_KEY" ]; then
    print_error "Missing DO_SPACES_BUCKET_NAME, DO_SPACES_ACCESS_KEY_ID, or DO_SPACES_SECRET_ACCESS_KEY in $ENV_FILE"
    exit 1
fi

if ! compose ps db 2>/dev/null | grep -qE 'Up|running'; then
    print_error "Database container is not running"
    exit 1
fi

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
BACKUP_NAME="${SQL_DATABASE}_${TIMESTAMP}.sql.gz"
LOCAL_DIR="/tmp/kms-connect-db-backups"
LOCAL_FILE="${LOCAL_DIR}/${BACKUP_NAME}"
S3_URI="s3://${DO_SPACES_BUCKET_NAME}/${DO_SPACES_BACKUP_PREFIX}/${BACKUP_NAME}"

mkdir -p "$LOCAL_DIR"

log "Starting backup for database ${SQL_DATABASE}"

if ! compose exec -T db pg_dump -U "$SQL_USER" -d "$SQL_DATABASE" --no-owner --no-acl | gzip > "$LOCAL_FILE"; then
    print_error "pg_dump failed"
    rm -f "$LOCAL_FILE"
    exit 1
fi

LOCAL_SIZE="$(wc -c < "$LOCAL_FILE" | tr -d ' ')"
log "Dump created (${LOCAL_SIZE} bytes): ${LOCAL_FILE}"

if ! aws_s3_cp "$LOCAL_FILE" "$S3_URI"; then
    print_error "Upload to Spaces failed: ${S3_URI}"
    exit 1
fi

log "Uploaded to ${S3_URI}"
rm -f "$LOCAL_FILE"

# Remove local files older than 1 day (safety net if a previous run failed mid-way)
find "$LOCAL_DIR" -type f -name '*.sql.gz' -mtime +1 -delete 2>/dev/null || true

log "Pruning backups older than ${BACKUP_RETENTION_DAYS} days under ${DO_SPACES_BACKUP_PREFIX}/"
CUTOFF_EPOCH="$(date -d "${BACKUP_RETENTION_DAYS} days ago" +%s)"
DELETED=0

while IFS= read -r line; do
    [[ "$line" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]] || continue
    object_date="$(echo "$line" | awk '{print $1" "$2}')"
    object_key="$(echo "$line" | awk '{print $4}')"
    [ -n "$object_key" ] || continue

    object_epoch="$(date -d "$object_date" +%s 2>/dev/null || continue)"
    if [ "$object_epoch" -lt "$CUTOFF_EPOCH" ]; then
        if aws_cli s3 rm "s3://${DO_SPACES_BUCKET_NAME}/${DO_SPACES_BACKUP_PREFIX}/${object_key}" --only-show-errors; then
            log "Deleted old backup: ${object_key}"
            DELETED=$((DELETED + 1))
        else
            print_warning "Failed to delete ${object_key}"
        fi
    fi
done < <(aws_cli s3 ls "s3://${DO_SPACES_BUCKET_NAME}/${DO_SPACES_BACKUP_PREFIX}/" || true)

log "Prune complete (${DELETED} object(s) removed)"
print_success "Backup finished: ${BACKUP_NAME}"
