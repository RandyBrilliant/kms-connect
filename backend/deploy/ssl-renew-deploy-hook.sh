#!/bin/bash
# Run after a successful certbot renew / certonly.
# Copies renewed PEMs into the repo nginx/ssl mount and reloads nginx.
#
# Works when invoked as root (systemd certbot / cron) or as a docker-group
# user (copies via a short-lived alpine container if host cp is denied).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
DOMAIN="${SSL_DOMAIN:-data.kms-connect.com}"
SSL_DIR="$APP_DIR/nginx/ssl/$DOMAIN"
LE_LIVE="/etc/letsencrypt/live/$DOMAIN"

cd "$APP_DIR"

COMPOSE_OPTS=(-f docker-compose.prod.yml)
if [ -f "$APP_DIR/docker-compose.prod.block.yml" ]; then
  COMPOSE_OPTS+=(-f docker-compose.prod.block.yml)
fi

copy_pems() {
  mkdir -p "$SSL_DIR"
  if cp "$LE_LIVE/fullchain.pem" "$SSL_DIR/fullchain.pem" \
    && cp "$LE_LIVE/privkey.pem" "$SSL_DIR/privkey.pem" \
    && cp "$LE_LIVE/chain.pem" "$SSL_DIR/chain.pem"; then
    chmod 644 "$SSL_DIR/fullchain.pem" "$SSL_DIR/chain.pem"
    chmod 600 "$SSL_DIR/privkey.pem"
    return 0
  fi
  return 1
}

if ! copy_pems 2>/dev/null; then
  # Root-owned ssl dir / letsencrypt — copy as root inside Docker.
  docker run --rm \
    -v /etc/letsencrypt:/etc/letsencrypt:ro \
    -v "$APP_DIR/nginx/ssl:/ssl" \
    alpine sh -c "
      set -e
      mkdir -p /ssl/$DOMAIN
      cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /ssl/$DOMAIN/fullchain.pem
      cp /etc/letsencrypt/live/$DOMAIN/privkey.pem /ssl/$DOMAIN/privkey.pem
      cp /etc/letsencrypt/live/$DOMAIN/chain.pem /ssl/$DOMAIN/chain.pem
      chmod 644 /ssl/$DOMAIN/fullchain.pem /ssl/$DOMAIN/chain.pem
      chmod 600 /ssl/$DOMAIN/privkey.pem
    "
fi

reload_nginx() {
  if docker compose "${COMPOSE_OPTS[@]}" exec -T nginx nginx -s reload 2>/dev/null; then
    return 0
  fi
  if docker exec kms-connect-nginx nginx -s reload 2>/dev/null; then
    return 0
  fi
  docker compose "${COMPOSE_OPTS[@]}" restart nginx
}

reload_nginx
echo "ssl-renew-deploy-hook: installed PEMs for $DOMAIN and reloaded nginx"
