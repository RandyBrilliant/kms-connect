#!/bin/bash
# Renew Let's Encrypt cert for data.kms-connect.com and deploy PEMs to nginx.
#
# Prefer host certbot when root; otherwise use the official certbot Docker image
# (works for docker-group users without sudo). Always runs the deploy hook so
# nginx/ssl copies stay in sync with /etc/letsencrypt.
#
# Usage:
#   sudo ./deploy/ssl-renew.sh              # preferred on production
#   ./deploy/ssl-renew.sh                   # docker fallback (no sudo)
#   FORCE_SSL_RENEWAL=1 ./deploy/ssl-renew.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
DOMAIN="${SSL_DOMAIN:-data.kms-connect.com}"
EMAIL="${SSL_EMAIL:-admin@kms-connect.com}"
HOOK="$SCRIPT_DIR/ssl-renew-deploy-hook.sh"
RENEWAL_CONF="/etc/letsencrypt/renewal/${DOMAIN}.conf"
WEBROOT="/var/www/certbot"
LOG_TAG="[kms-ssl-renew]"

cd "$APP_DIR"
chmod +x "$HOOK" 2>/dev/null || true

mkdir -p "$WEBROOT" 2>/dev/null || docker run --rm -v /var/www/certbot:/var/www/certbot alpine mkdir -p /var/www/certbot

needs_webroot_migration() {
  if [ ! -f "$RENEWAL_CONF" ]; then
    # May be unreadable without root — check via docker
    docker run --rm -v /etc/letsencrypt:/etc/letsencrypt:ro alpine \
      grep -qE '^[[:space:]]*authenticator[[:space:]]*=[[:space:]]*standalone[[:space:]]*$' \
      "/etc/letsencrypt/renewal/${DOMAIN}.conf" 2>/dev/null
    return $?
  fi
  grep -qE '^[[:space:]]*authenticator[[:space:]]*=[[:space:]]*standalone[[:space:]]*$' "$RENEWAL_CONF"
}

run_certbot_host() {
  local extra=("$@")
  certbot certonly --webroot -w "$WEBROOT" -d "$DOMAIN" \
    --email "$EMAIL" --agree-tos --non-interactive "${extra[@]}"
}

run_certbot_docker() {
  local extra=("$@")
  docker run --rm \
    -v /etc/letsencrypt:/etc/letsencrypt \
    -v "$WEBROOT:$WEBROOT" \
    -v /var/log/letsencrypt:/var/log/letsencrypt \
    certbot/certbot certonly --webroot -w "$WEBROOT" -d "$DOMAIN" \
    --email "$EMAIL" --agree-tos --non-interactive "${extra[@]}"
}

run_certbot() {
  if [ "${EUID:-0}" -eq 0 ] && command -v certbot >/dev/null 2>&1; then
    run_certbot_host "$@"
  else
    run_certbot_docker "$@"
  fi
}

run_renew() {
  if [ "${EUID:-0}" -eq 0 ] && command -v certbot >/dev/null 2>&1; then
    # Host certbot runs /etc/letsencrypt/renewal-hooks/deploy/* on success.
    certbot renew --quiet
  else
    # Hooks inside the certbot image cannot see host paths / docker.socket.
    # Skip directory hooks here; always deploy from the host afterward.
    docker run --rm \
      -v /etc/letsencrypt:/etc/letsencrypt \
      -v "$WEBROOT:$WEBROOT" \
      -v /var/log/letsencrypt:/var/log/letsencrypt \
      certbot/certbot renew --quiet --no-directory-hooks
    bash "$HOOK"
  fi
}

echo "$LOG_TAG starting for $DOMAIN"

if needs_webroot_migration || [ "${FORCE_SSL_RENEWAL:-0}" = "1" ]; then
  if needs_webroot_migration; then
    echo "$LOG_TAG migrating authenticator standalone → webroot (required while nginx binds :80)"
  else
    echo "$LOG_TAG FORCE_SSL_RENEWAL=1"
  fi
  run_certbot --force-renewal
  bash "$HOOK"
else
  run_renew
fi

echo "$LOG_TAG done"
