#!/bin/bash
# Install automatic TLS renewal: certbot renew twice daily + copy PEMs + nginx reload.
# Safe to re-run after deploys. Requires: webroot at /var/www/certbot, nginx mount (docker-compose).
#
# Usage (on production server, from repo):
#   sudo ./deploy/install-ssl-auto-renewal.sh

set -euo pipefail

if [ "${EUID:-0}" -ne 0 ]; then
  echo "Run as root: sudo ./deploy/install-ssl-auto-renewal.sh" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
DOMAIN="data.kms-connect.com"
HOOK="$APP_DIR/deploy/ssl-renew-deploy-hook.sh"
LOG_FILE="/var/log/kms-connect-certbot.log"

if [ ! -f "$HOOK" ]; then
  echo "Missing hook script: $HOOK" >&2
  exit 1
fi
chmod +x "$HOOK"

mkdir -p /var/www/certbot
chmod 755 /var/www/certbot

if ! grep -q '/var/www/certbot:/var/www/certbot' "$APP_DIR/docker-compose.prod.yml" 2>/dev/null; then
  echo "WARNING: nginx should mount host /var/www/certbot for HTTP-01 webroot renewals." >&2
  echo "  Add under nginx volumes: - /var/www/certbot:/var/www/certbot:ro" >&2
  echo "  Then: cd $APP_DIR && docker compose -f docker-compose.prod.yml up -d nginx" >&2
fi

RENEWAL_CONF="/etc/letsencrypt/renewal/${DOMAIN}.conf"
if [ -f "$RENEWAL_CONF" ] && grep -qE '^[[:space:]]*authenticator[[:space:]]*=[[:space:]]*standalone[[:space:]]*$' "$RENEWAL_CONF"; then
  echo "WARNING: renewal still uses STANDALONE (renew will fail while nginx uses port 80)." >&2
  echo "  Switch to webroot once (nginx up, webroot mounted):" >&2
  echo "  cd $APP_DIR && sudo certbot certonly --webroot -w /var/www/certbot -d $DOMAIN \\" >&2
  echo "    --force-renewal --email YOUR@EMAIL --agree-tos --non-interactive" >&2
fi

CRON_FILE="/etc/cron.d/kms-connect-certbot"
# Twice daily (Let's Encrypt recommendation). Times avoid common :00 spikes.
cat > "$CRON_FILE" <<EOF
# KMS-Connect — Let's Encrypt renew + deploy hook (PEM copy + nginx reload)
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

12 3,15 * * * root certbot renew --quiet --deploy-hook $HOOK >>$LOG_FILE 2>&1
EOF
chmod 644 "$CRON_FILE"
touch "$LOG_FILE"
chmod 640 "$LOG_FILE" 2>/dev/null || true

# Avoid duplicate renew runs from older installers
rm -f /etc/cron.daily/kms-connect-renew-ssl /etc/cron.monthly/renew-ssl-cert

echo "Installed $CRON_FILE (runs certbot renew at 03:12 and 15:12 server local time)."
echo "Hook: $HOOK"
echo "Log:  $LOG_FILE"
echo "Test: certbot renew --dry-run"
