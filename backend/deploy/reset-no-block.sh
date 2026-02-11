#!/bin/bash
# Stop using Block Storage and reset so deploy.sh / update.sh use only the Droplet (no block volume).
# Run from backend dir: sudo ./deploy/reset-no-block.sh
# Then run: sudo ./deploy/deploy.sh for a fresh deploy without block storage.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$(dirname "$SCRIPT_DIR")"
BLOCK_FILE="$APP_DIR/docker-compose.prod.block.yml"
BLOCK_DISABLED="$APP_DIR/docker-compose.prod.block.yml.disabled"

echo -e "${BLUE}=========================================="
echo "Reset: Stop using Block Storage"
echo "==========================================${NC}"
echo ""

cd "$APP_DIR" || { echo -e "${RED}Cannot access $APP_DIR${NC}"; exit 1; }

# Stop stack (with block override if it exists, so we stop the right containers)
COMPOSE_OPTS="-f docker-compose.prod.yml"
[ -f "$BLOCK_FILE" ] && COMPOSE_OPTS="$COMPOSE_OPTS -f docker-compose.prod.block.yml"

echo -e "${BLUE}[1/2] Stopping services...${NC}"
echo y | docker compose $COMPOSE_OPTS down 2>/dev/null || true
docker compose -f docker-compose.prod.yml down 2>/dev/null || true
echo -e "${GREEN}✓ Services stopped${NC}"
echo ""

# Disable block override so deploy.sh and update.sh use only docker-compose.prod.yml
echo -e "${BLUE}[2/2] Disabling Block Storage compose override...${NC}"
if [ -f "$BLOCK_FILE" ]; then
    mv "$BLOCK_FILE" "$BLOCK_DISABLED"
    echo -e "${GREEN}✓ Renamed docker-compose.prod.block.yml → docker-compose.prod.block.yml.disabled${NC}"
    echo "  (deploy.sh and update.sh will now use only Droplet volumes)"
else
    echo "  Block override not found; already not in use."
fi
echo ""

echo -e "${GREEN}=========================================="
echo "✅ Reset done"
echo "==========================================${NC}"
echo ""
echo "Deploy fresh without block storage:"
echo -e "  ${YELLOW}sudo ./deploy/deploy.sh${NC}"
echo ""
echo "Updates will also use Droplet only (no block):"
echo -e "  ${YELLOW}sudo ./deploy/update.sh${NC}"
echo ""
echo "To use Block Storage again later: rename the file back:"
echo -e "  ${YELLOW}mv docker-compose.prod.block.yml.disabled docker-compose.prod.block.yml${NC}"
echo ""
