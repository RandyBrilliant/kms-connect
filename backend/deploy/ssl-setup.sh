#!/bin/bash

# SSL Certificate Setup - KMS-Connect (data.kms-connect.com)
# Uses HTTP-01 webroot so Nginx can keep port 80; avoids standalone / port bind failures.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get directories
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="${APP_DIR:-$PROJECT_DIR}"

cd "$APP_DIR" || exit 1
COMPOSE_OPTS=(-f docker-compose.prod.yml)
if [ -f "$APP_DIR/docker-compose.prod.block.yml" ]; then
  COMPOSE_OPTS+=(-f docker-compose.prod.block.yml)
fi

echo -e "${BLUE}=========================================="
echo "SSL Certificate Setup"
echo "==========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

# Domain configuration
DOMAIN="data.kms-connect.com"
EMAIL="${SSL_EMAIL:-admin@kms-connect.com}"

echo -e "${YELLOW}Domain: ${DOMAIN}${NC}"
echo -e "${YELLOW}Email: ${EMAIL}${NC}"
echo ""

# Check if DNS is configured
echo -e "${BLUE}[1/7] Checking DNS configuration...${NC}"
SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)
if command -v dig &>/dev/null; then
    DNS_IP=$(dig +short $DOMAIN | tail -n1)
else
    DNS_IP=$(getent ahosts "$DOMAIN" 2>/dev/null | awk '{print $1; exit}' || host -t A "$DOMAIN" 2>/dev/null | awk '/has address/ {print $NF; exit}')
fi

if [ -z "$DNS_IP" ]; then
    echo -e "${RED}Error: DNS not configured for $DOMAIN${NC}"
    echo "Please configure an A record pointing to: $SERVER_IP"
    exit 1
fi

if [ "$DNS_IP" != "$SERVER_IP" ]; then
    echo -e "${YELLOW}⚠ Warning: DNS IP ($DNS_IP) doesn't match server IP ($SERVER_IP)${NC}"
    read -p "Continue anyway? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        exit 0
    fi
else
    echo -e "${GREEN}✓ DNS configured correctly${NC}"
fi

# Check if services are running
echo ""
echo -e "${BLUE}[2/7] Checking if services are running...${NC}"
if ! docker compose "${COMPOSE_OPTS[@]}" ps | grep -q "Up"; then
    echo -e "${RED}Error: Services are not running!${NC}"
    echo "Please run: sudo ./deploy/deploy.sh first"
    exit 1
fi
echo -e "${GREEN}✓ Services are running${NC}"

# ACME webroot on host; nginx must mount /var/www/certbot (see docker-compose.prod.yml)
echo ""
echo -e "${BLUE}[3/7] Preparing ACME webroot and reloading Nginx...${NC}"
mkdir -p /var/www/certbot
chmod 755 /var/www/certbot
chmod +x "$APP_DIR/deploy/ssl-renew-deploy-hook.sh" 2>/dev/null || true
docker compose "${COMPOSE_OPTS[@]}" up -d nginx
sleep 3
echo -e "${GREEN}✓ Nginx is up (must expose /.well-known/acme-challenge/ on port 80)${NC}"

# Issue / renew certificate (webroot — does not bind port 80 itself)
echo ""
echo -e "${BLUE}[4/7] Requesting certificate (Let's Encrypt webroot)...${NC}"
CERTBOT_BASE=(certonly --webroot -w /var/www/certbot -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive)
if [ "${FORCE_SSL_RENEWAL:-0}" = "1" ]; then
    echo -e "${YELLOW}FORCE_SSL_RENEWAL=1 → --force-renewal${NC}"
    certbot "${CERTBOT_BASE[@]}" --force-renewal
else
    certbot "${CERTBOT_BASE[@]}" --keep-until-expiring
fi

# Copy certificates to nginx directory
echo ""
echo -e "${BLUE}[5/7] Copying certificates...${NC}"
mkdir -p "$APP_DIR/nginx/ssl/$DOMAIN"
cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$APP_DIR/nginx/ssl/$DOMAIN/fullchain.pem"
cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$APP_DIR/nginx/ssl/$DOMAIN/privkey.pem"
cp "/etc/letsencrypt/live/$DOMAIN/chain.pem" "$APP_DIR/nginx/ssl/$DOMAIN/chain.pem"
chmod 644 "$APP_DIR/nginx/ssl/$DOMAIN/fullchain.pem"
chmod 644 "$APP_DIR/nginx/ssl/$DOMAIN/chain.pem"
chmod 600 "$APP_DIR/nginx/ssl/$DOMAIN/privkey.pem"
echo -e "${GREEN}✓ Certificates copied${NC}"

# Update docker-compose.prod.yml to use SSL config
echo ""
echo -e "${BLUE}[6/7] Updating Docker Compose configuration for SSL...${NC}"

sed -i 's|- ./nginx/data.kms-connect.com.http-only.conf:/etc/nginx/conf.d/data.kms-connect.com.conf:ro|# - ./nginx/data.kms-connect.com.http-only.conf:/etc/nginx/conf.d/data.kms-connect.com.conf:ro|g' docker-compose.prod.yml

if ! grep -q "./nginx/data.kms-connect.com.conf:/etc/nginx/conf.d/data.kms-connect.com.conf:ro" docker-compose.prod.yml || \
   grep -q "# - ./nginx/data.kms-connect.com.conf" docker-compose.prod.yml; then
    sed -i 's|# - ./nginx/data.kms-connect.com.conf:/etc/nginx/conf.d/data.kms-connect.com.conf:ro|- ./nginx/data.kms-connect.com.conf:/etc/nginx/conf.d/data.kms-connect.com.conf:ro|g' docker-compose.prod.yml
    if ! grep -q "./nginx/data.kms-connect.com.conf:/etc/nginx/conf.d/data.kms-connect.com.conf:ro" docker-compose.prod.yml; then
        sed -i '/# - .\/nginx\/data.kms-connect.com.http-only.conf/a\      - ./nginx/data.kms-connect.com.conf:/etc/nginx/conf.d/data.kms-connect.com.conf:ro' docker-compose.prod.yml
    fi
fi

sed -i 's|# - ./nginx/ssl:/etc/nginx/ssl:ro|- ./nginx/ssl:/etc/nginx/ssl:ro|g' docker-compose.prod.yml
if ! grep -q "./nginx/ssl:/etc/nginx/ssl:ro" docker-compose.prod.yml; then
    sed -i '/- .\/nginx\/data.kms-connect.com.conf/a\      - ./nginx/ssl:/etc/nginx/ssl:ro' docker-compose.prod.yml
fi

echo -e "${GREEN}✓ Configuration updated${NC}"

echo ""
echo -e "${BLUE}[7/7] Starting Nginx with SSL...${NC}"
docker compose "${COMPOSE_OPTS[@]}" up -d nginx
sleep 5

if docker compose "${COMPOSE_OPTS[@]}" exec -T nginx nginx -t > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
else
    echo -e "${RED}Error: Nginx configuration is invalid!${NC}"
    docker compose "${COMPOSE_OPTS[@]}" exec -T nginx nginx -t
    exit 1
fi

if docker compose "${COMPOSE_OPTS[@]}" ps nginx | grep -q "Up"; then
    echo -e "${GREEN}✓ Nginx started successfully${NC}"
else
    echo -e "${RED}Error: Nginx failed to start${NC}"
    docker compose "${COMPOSE_OPTS[@]}" logs nginx | tail -20
    exit 1
fi

# Auto-renewal: systemd certbot.timer deploy-hook + cron (see install-ssl-auto-renewal.sh)
echo ""
echo -e "${BLUE}Setting up certificate auto-renewal...${NC}"
bash "$APP_DIR/deploy/install-ssl-auto-renewal.sh"
echo -e "${GREEN}✓ Auto-renewal installed${NC}"

echo ""
echo -e "${GREEN}=========================================="
echo "✅ SSL Setup Complete!"
echo "=========================================="
echo "${NC}"

echo -e "${BLUE}Certificate Details:${NC}"
certbot certificates

echo ""
echo -e "${GREEN}Your site is now available at: https://$DOMAIN${NC}"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "  - Auto-renewal: sudo ./deploy/install-ssl-auto-renewal.sh (re-run if you move this app directory)."
echo "  - Manual renew: sudo ./deploy/ssl-renew.sh  (or ./deploy/ssl-renew.sh with docker)."
echo "  - Renewal must use webroot (not standalone) while nginx binds port 80 — install script migrates this."
echo "  - Update your .env file:"
echo "    ${BLUE}SECURE_SSL_REDIRECT=1${NC}"
echo "    ${BLUE}SESSION_COOKIE_SECURE=1${NC}"
echo "    ${BLUE}CSRF_COOKIE_SECURE=1${NC}"
echo ""
echo -e "${GREEN}SSL setup complete!${NC}"
echo ""
