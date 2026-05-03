#!/bin/bash

# Update script: pull code, rebuild, restart, migrate, collectstatic.
# Uses block storage override automatically if docker-compose.prod.block.yml exists.

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

# Compose: use block storage override when present (so one script works for both setups)
COMPOSE_OPTS="-f docker-compose.prod.yml"
[ -f "$APP_DIR/docker-compose.prod.block.yml" ] && COMPOSE_OPTS="$COMPOSE_OPTS -f docker-compose.prod.block.yml"

echo -e "${BLUE}=========================================="
echo "KMS-Connect - Update"
echo "==========================================${NC}"
echo ""

cd "$APP_DIR" || {
    echo -e "${RED}Error: Cannot access $APP_DIR${NC}"
    exit 1
}

# Check if services are running
if ! docker compose $COMPOSE_OPTS ps | grep -q "Up"; then
    echo -e "${YELLOW}⚠ No services are running. Use deploy.sh instead.${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}[1/5] Pulling latest code...${NC}"
if [ -d ".git" ]; then
    git pull || {
        echo -e "${YELLOW}⚠ Git pull had issues, continuing anyway...${NC}"
    }
    echo -e "${GREEN}✓ Code updated${NC}"
else
    echo -e "${YELLOW}⚠ Not a git repository, skipping git pull${NC}"
fi

echo ""
echo -e "${BLUE}[2/5] Stopping services...${NC}"
docker compose $COMPOSE_OPTS down
echo -e "${GREEN}✓ Services stopped${NC}"

echo ""
echo -e "${BLUE}[3/5] Building new images...${NC}"
docker compose $COMPOSE_OPTS build --no-cache api celery celery-beat || {
    echo -e "${RED}Error: Failed to build images${NC}"
    exit 1
}
echo -e "${GREEN}✓ Images built${NC}"

echo ""
echo -e "${BLUE}[4/5] Starting services...${NC}"
docker compose $COMPOSE_OPTS up -d
echo -e "${GREEN}✓ Services started${NC}"

echo ""
echo -e "${BLUE}[5/5] Running migrations...${NC}"
# Wait for the api container to actually accept commands AND for the DB to be reachable.
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if docker compose $COMPOSE_OPTS exec -T api python manage.py migrate --check >/dev/null 2>&1; then
        echo -e "${GREEN}✓ DB reachable, migrations up to date${NC}"
        break
    fi
    if docker compose $COMPOSE_OPTS exec -T api python -c "import django; django.setup()" >/dev/null 2>&1; then
        break
    fi
    echo -e "${YELLOW}…api not ready yet (attempt $attempt/10), retrying in 3s${NC}"
    sleep 3
done

if ! docker compose $COMPOSE_OPTS exec -T api python manage.py migrate --noinput; then
    echo -e "${RED}❌ Migrations FAILED. Aborting deploy so you can investigate before traffic hits a half-migrated DB.${NC}"
    echo -e "${YELLOW}Inspect with:${NC}"
    echo "  docker compose $COMPOSE_OPTS exec -T api python manage.py showmigrations"
    echo "  docker compose $COMPOSE_OPTS logs --tail 200 api"
    exit 1
fi
echo -e "${GREEN}✓ Migrations completed${NC}"

echo ""
echo -e "${BLUE}Collecting static files...${NC}"
docker compose $COMPOSE_OPTS exec -T api python manage.py collectstatic --noinput --clear || {
    echo -e "${YELLOW}⚠ Static files collection had warnings${NC}"
}
echo -e "${GREEN}✓ Static files collected${NC}"

echo ""
echo -e "${GREEN}=========================================="
echo "✅ Update Complete!"
echo "==========================================${NC}"
echo ""

# Show service status
docker compose $COMPOSE_OPTS ps

echo ""
echo -e "${GREEN}Update successful! 🎉${NC}"
echo ""
