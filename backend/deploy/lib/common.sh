#!/bin/bash
# Shared helpers for registry-based deploy (deploy-registry.sh).

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(dirname "$LIB_DIR")"
PROJECT_ROOT="$(dirname "$DEPLOY_DIR")"

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
ENV_FILE="${ENV_FILE:-.env}"
APP_CONTAINER_NAME="${APP_CONTAINER_NAME:-kms-backend}"
API_SERVICE="${API_SERVICE:-api}"
WORKER_SERVICES="${WORKER_SERVICES:-celery celery-beat}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}=========================================="
    echo "$1"
    echo -e "==========================================${NC}"
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

require_project_root() {
    if [ ! -f "$PROJECT_ROOT/$COMPOSE_FILE" ]; then
        print_error "Expected $COMPOSE_FILE in $PROJECT_ROOT"
        exit 1
    fi
    cd "$PROJECT_ROOT"
}

DOCKER_CMD=(docker)

require_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        print_error "docker is not installed"
        exit 1
    fi
    if docker info >/dev/null 2>&1; then
        DOCKER_CMD=(docker)
    elif sudo docker info >/dev/null 2>&1; then
        DOCKER_CMD=(sudo docker)
        print_warning "Using sudo for Docker (consider: sudo usermod -aG docker \$USER)"
    else
        print_error "Cannot access Docker daemon (permission denied on /var/run/docker.sock)"
        print_error "Fix: sudo usermod -aG docker \$USER  then log out and back in"
        exit 1
    fi
    if ! "${DOCKER_CMD[@]}" compose version >/dev/null 2>&1; then
        print_error "docker compose is not available"
        exit 1
    fi
}

docker_cmd() {
    "${DOCKER_CMD[@]}" "$@"
}

make_scripts_executable() {
    chmod +x "$DEPLOY_DIR"/*.sh 2>/dev/null || true
    chmod +x "$PROJECT_ROOT/entrypoint.sh" 2>/dev/null || true
}

compose() {
    local args=()
    if [ -f "$PROJECT_ROOT/$ENV_FILE" ]; then
        args+=(--env-file "$PROJECT_ROOT/$ENV_FILE")
    fi
    "${DOCKER_CMD[@]}" compose -f "$PROJECT_ROOT/$COMPOSE_FILE" "${args[@]}" "$@"
}

persist_app_image() {
    local image="$1"
    local env_path="$PROJECT_ROOT/$ENV_FILE"
    [ -n "$image" ] || return 0
    touch "$env_path"
    if grep -q '^APP_IMAGE=' "$env_path" 2>/dev/null; then
        sed -i "s|^APP_IMAGE=.*|APP_IMAGE=${image}|" "$env_path"
    else
        echo "APP_IMAGE=${image}" >> "$env_path"
    fi
}

read_persisted_app_image() {
    grep -E '^APP_IMAGE=' "$PROJECT_ROOT/$ENV_FILE" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '\r\"' || true
}

read_running_app_image() {
    "${DOCKER_CMD[@]}" inspect "$APP_CONTAINER_NAME" --format '{{.Config.Image}}' 2>/dev/null | tr -d '\r' || true
}

read_last_good_app_image() {
    if [ -f "$PROJECT_ROOT/.deploy-last-good-image" ]; then
        head -n1 "$PROJECT_ROOT/.deploy-last-good-image" | tr -d '\r'
    fi
    return 0
}

save_last_good_app_image() {
    [ -n "$1" ] && printf '%s\n' "$1" > "$PROJECT_ROOT/.deploy-last-good-image"
}

resolve_app_port() {
    local port
    port="$(grep -E '^PORT=' "$PROJECT_ROOT/$ENV_FILE" 2>/dev/null | head -n1 | cut -d= -f2 | tr -d ' \r\"')"
    echo "${port:-8000}"
}

probe_app_http_health() {
    local max_attempts="${2:-12}"
    local i

    for i in $(seq 1 "$max_attempts"); do
        if compose exec -T "$API_SERVICE" curl -fsS --max-time 5 "http://localhost:8000/health/" 2>/dev/null \
            | grep -qE '"success"[[:space:]]*:[[:space:]]*true|"up"[[:space:]]*:[[:space:]]*true|"status"[[:space:]]*:[[:space:]]*"ok"'; then
            return 0
        fi
        sleep 5
    done
    return 1
}

wait_for_healthy() {
    local service="$1"
    local max_attempts="${2:-40}"
    local i

    for i in $(seq 1 "$max_attempts"); do
        if compose ps "$service" 2>/dev/null | grep -q "(healthy)"; then
            return 0
        fi
        sleep 3
    done
    return 1
}

rollback_app_deployment() {
    local rollback_image="$1"
    [ -n "$rollback_image" ] || return 1

    print_warning "Rolling back to $rollback_image"
    export APP_IMAGE="$rollback_image"
    compose pull "$API_SERVICE" 2>/dev/null || true
    compose up -d --no-deps "$API_SERVICE"

    if wait_for_healthy "$API_SERVICE" 40 && probe_app_http_health 12; then
        # shellcheck disable=SC2086
        compose up -d --no-deps $WORKER_SERVICES
        persist_app_image "$rollback_image"
        save_last_good_app_image "$rollback_image"
        return 0
    fi
    return 1
}
