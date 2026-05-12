#!/bin/bash
# Run after a successful `certbot renew` (see ssl-setup.sh cron).
# Copies renewed PEMs into the repo nginx/ssl mount and reloads nginx.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
DOMAIN="data.kms-connect.com"

cd "$APP_DIR"

COMPOSE_OPTS=(-f docker-compose.prod.yml)
if [ -f "$APP_DIR/docker-compose.prod.block.yml" ]; then
  COMPOSE_OPTS+=(-f docker-compose.prod.block.yml)
fi

mkdir -p "$APP_DIR/nginx/ssl/$DOMAIN"
cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$APP_DIR/nginx/ssl/$DOMAIN/fullchain.pem"
cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$APP_DIR/nginx/ssl/$DOMAIN/privkey.pem"
cp "/etc/letsencrypt/live/$DOMAIN/chain.pem" "$APP_DIR/nginx/ssl/$DOMAIN/chain.pem"
chmod 644 "$APP_DIR/nginx/ssl/$DOMAIN/fullchain.pem" "$APP_DIR/nginx/ssl/$DOMAIN/chain.pem"
chmod 600 "$APP_DIR/nginx/ssl/$DOMAIN/privkey.pem"

if docker compose "${COMPOSE_OPTS[@]}" exec -T nginx nginx -s reload 2>/dev/null; then
  :
else
  docker compose "${COMPOSE_OPTS[@]}" restart nginx
fi
