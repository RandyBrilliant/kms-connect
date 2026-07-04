#!/bin/bash
# Pull a prebuilt image from GHCR and deploy with automatic rollback on failure.
# Usage: APP_IMAGE=ghcr.io/owner/kms-connect-backend:<sha> ./deploy/deploy-registry.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

print_header "Registry Deploy (pull prebuilt image)"
require_project_root
require_docker
make_scripts_executable

if [ -z "${APP_IMAGE:-}" ]; then
    print_error "APP_IMAGE is required (e.g. ghcr.io/<org>/kms-connect-backend:<sha>)"
    exit 1
fi

if [ ! -f "$PROJECT_ROOT/$ENV_FILE" ]; then
    print_error "$ENV_FILE missing — run ./deploy/deploy.sh first"
    exit 1
fi

log() { echo "[deploy-registry] $*"; }

TARGET_APP_IMAGE="$APP_IMAGE"
log "Target image: $TARGET_APP_IMAGE"

PREVIOUS_APP_IMAGE="$(read_running_app_image || true)"
if [ -z "$PREVIOUS_APP_IMAGE" ]; then
    PREVIOUS_APP_IMAGE="$(read_persisted_app_image || true)"
fi
if [ -z "$PREVIOUS_APP_IMAGE" ]; then
    PREVIOUS_APP_IMAGE="$(read_last_good_app_image || true)"
fi
if [ -n "$PREVIOUS_APP_IMAGE" ]; then
    log "Previous image: $PREVIOUS_APP_IMAGE"
else
    log "No previous image found (first registry deploy)"
fi

export APP_IMAGE="$TARGET_APP_IMAGE"

if [ "${AUTO_DEPLOY:-}" != "true" ]; then
    read -r -p "Pull and deploy this image? (yes/no): " confirm
    [ "$confirm" = "yes" ] || exit 0
fi

if [ "${SKIP_PULL_CODE:-false}" != "true" ]; then
    GIT_ROOT="$PROJECT_ROOT"
    if [ -d "$(dirname "$PROJECT_ROOT")/.git" ]; then
        GIT_ROOT="$(dirname "$PROJECT_ROOT")"
    elif [ ! -d "$PROJECT_ROOT/.git" ]; then
        GIT_ROOT=""
    fi
    if [ -n "$GIT_ROOT" ]; then
        BEFORE_HEAD="$(git -C "$GIT_ROOT" rev-parse HEAD 2>/dev/null || true)"
        git -C "$GIT_ROOT" pull origin "${DEPLOY_BRANCH:-main}" || true
        AFTER_HEAD="$(git -C "$GIT_ROOT" rev-parse HEAD 2>/dev/null || true)"
        if [ -z "${CHANGED_FILES:-}" ]; then
            CHANGED_FILES="$(git -C "$GIT_ROOT" diff --name-only "$BEFORE_HEAD" "$AFTER_HEAD" 2>/dev/null || true)"
        fi
    fi
fi

log "Pulling image from registry..."
if ! docker pull "$TARGET_APP_IMAGE"; then
    print_error "docker pull failed for $TARGET_APP_IMAGE"
    print_error "Ensure GHCR login succeeded and the package allows this token to pull"
    exit 1
fi

log "Updating api service..."
if ! compose up -d --no-deps --pull always "$API_SERVICE"; then
    print_error "docker compose up failed for $API_SERVICE"
    compose logs --tail=30 "$API_SERVICE" || true
    exit 1
fi

DEPLOY_OK=false
if wait_for_healthy "$API_SERVICE" 40 && probe_app_http_health 12; then
    DEPLOY_OK=true
fi

if [ "$DEPLOY_OK" != true ]; then
    print_error "New deployment failed health checks"
    compose logs --tail=30 "$API_SERVICE"
    if [ -n "$PREVIOUS_APP_IMAGE" ] && [ "$PREVIOUS_APP_IMAGE" != "$TARGET_APP_IMAGE" ]; then
        rollback_app_deployment "$PREVIOUS_APP_IMAGE" && exit 1
    fi
    exit 1
fi

persist_app_image "$TARGET_APP_IMAGE"
save_last_good_app_image "$TARGET_APP_IMAGE"

# shellcheck disable=SC2086
compose up -d --no-deps $WORKER_SERVICES

if [ -n "${CHANGED_FILES:-}" ] && echo "$CHANGED_FILES" | grep -q 'backend/nginx/'; then
    compose up -d --no-deps nginx
fi

print_success "Deployed $TARGET_APP_IMAGE"
