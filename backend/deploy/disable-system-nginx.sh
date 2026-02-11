#!/bin/bash
# Stop and disable system nginx (and Apache) so Docker nginx can use ports 80 and 443.
# Run: sudo ./deploy/disable-system-nginx.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Run as root or with sudo${NC}"
    exit 1
fi

echo "Checking what is using port 80..."
if command -v ss &>/dev/null; then
    ss -tlnp | grep -E ':80\s|:443\s' || true
elif command -v netstat &>/dev/null; then
    netstat -tlnp | grep -E ':80\s|:443\s' || true
fi

echo ""
echo "Stopping and disabling system nginx and Apache..."

if systemctl is-active --quiet nginx 2>/dev/null; then
    systemctl stop nginx
    systemctl disable nginx
    echo -e "${GREEN}✓ nginx stopped and disabled${NC}"
else
    echo "  nginx not running"
fi

if systemctl is-active --quiet apache2 2>/dev/null; then
    systemctl stop apache2
    systemctl disable apache2
    echo -e "${GREEN}✓ apache2 stopped and disabled${NC}"
else
    echo "  apache2 not running"
fi

echo ""
echo -e "${GREEN}Ports 80 and 443 should now be free for Docker nginx.${NC}"
echo "Start the stack again:"
echo "  docker compose -f docker-compose.prod.yml up -d"
echo ""
