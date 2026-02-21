#!/bin/bash

# Production Database Reset Script
# This script resets the database in Docker production environment
# Use this when you've reset your migrations and need to start fresh
# WARNING: This will DELETE ALL DATA in the database

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

echo -e "${RED}=========================================="
echo "⚠️  PRODUCTION DATABASE RESET ⚠️"
echo "==========================================${NC}"
echo ""
echo -e "${YELLOW}This will PERMANENTLY DELETE:${NC}"
echo "  ❌ ALL database data"
echo "  ❌ ALL migrations history"
echo "  ❌ ALL user accounts"
echo "  ❌ ALL application data"
echo ""
echo -e "${YELLOW}This will:${NC}"
echo "  ✓ Keep Docker containers and images"
echo "  ✓ Keep media files (uploaded files)"
echo "  ✓ Keep static files"
echo "  ✓ Reset database to fresh state"
echo "  ✓ Apply fresh migrations"
echo ""
echo -e "${RED}THIS CANNOT BE UNDONE!${NC}"
echo ""

# Safety check - require explicit confirmation
read -p "Type 'RESET DATABASE' to confirm: " confirm

if [ "$confirm" != "RESET DATABASE" ]; then
    echo -e "${YELLOW}Reset cancelled.${NC}"
    exit 0
fi

cd "$APP_DIR" || {
    echo -e "${RED}Error: Cannot access $APP_DIR${NC}"
    exit 1
}

# Check if .env exists
if [ ! -f "$APP_DIR/.env" ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please create .env file from env.example:"
    echo "  cp env.example .env"
    echo "  nano .env"
    exit 1
fi

echo ""
echo -e "${BLUE}=========================================="
echo "Starting Database Reset..."
echo "==========================================${NC}"
echo ""

# Stop all services except database to allow migration operations
echo -e "${BLUE}[1/8] Stopping application services...${NC}"
docker compose -f docker-compose.prod.yml stop api celery celery-beat nginx 2>/dev/null || true
echo -e "${GREEN}✓ Application services stopped${NC}"

# Wait a moment for services to fully stop
sleep 2

# Check if database container exists and is running
echo ""
echo -e "${BLUE}[2/8] Checking database status...${NC}"
if docker compose -f docker-compose.prod.yml ps db | grep -q "Up"; then
    echo "  ✓ Database container is running"
    
    # Wait for database to be ready
    echo "  → Waiting for database to be ready..."
    timeout=30
    counter=0
    while ! docker compose -f docker-compose.prod.yml exec -T db pg_isready -U "${SQL_USER:-postgres}" > /dev/null 2>&1; do
        sleep 1
        counter=$((counter + 1))
        if [ $counter -ge $timeout ]; then
            echo -e "${YELLOW}⚠ Database not ready after ${timeout}s, continuing anyway...${NC}"
            break
        fi
    done
    echo -e "${GREEN}✓ Database is ready${NC}"
else
    echo "  → Starting database container..."
    docker compose -f docker-compose.prod.yml up -d db
    echo "  → Waiting for database to start..."
    timeout=60
    counter=0
    while ! docker compose -f docker-compose.prod.yml exec -T db pg_isready -U "${SQL_USER:-postgres}" > /dev/null 2>&1; do
        sleep 2
        counter=$((counter + 2))
        if [ $counter -ge $timeout ]; then
            echo -e "${RED}Error: Database not ready after ${timeout}s${NC}"
            exit 1
        fi
        echo -n "."
    done
    echo ""
    echo -e "${GREEN}✓ Database started and ready${NC}"
fi

# Get database name from .env or use default (must match docker-compose.prod.yml)
DB_NAME="${SQL_DATABASE:-kmsconnect}"
DB_USER="${SQL_USER:-postgres}"
DB_PASSWORD="${SQL_PASSWORD:-}"

# Set PGPASSWORD if password is provided
if [ -n "$DB_PASSWORD" ]; then
    export PGPASSWORD="$DB_PASSWORD"
fi

# Option 1: Drop and recreate the database (cleanest approach)
echo ""
echo -e "${BLUE}[3/8] Dropping existing database...${NC}"

# First, stop the Django container to close connections
echo "  → Stopping Django container to close connections..."
docker compose -f docker-compose.prod.yml stop web 2>&1

# Check if database exists first
echo "  → Checking if database exists..."
DB_EXISTS=$(docker compose -f docker-compose.prod.yml exec -T db psql -U "$DB_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';" 2>/dev/null || echo "")

if [ "$DB_EXISTS" = "1" ]; then
    echo "  → Database '$DB_NAME' exists, checking for active connections..."
    
    # Show active connections for debugging
    echo "  → Active connections:"
    docker compose -f docker-compose.prod.yml exec -T db psql -U "$DB_USER" -d postgres -c "SELECT pid, usename, application_name, client_addr FROM pg_stat_activity WHERE datname = '$DB_NAME';" 2>&1 || true
    
    # Terminate all connections forcefully
    echo "  → Terminating connections..."
    docker compose -f docker-compose.prod.yml exec -T db psql -U "$DB_USER" -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();" 2>&1 || true
    
    # Wait a moment for connections to close
    sleep 1
    
    # Drop the database using FORCE mode directly (PostgreSQL 13+)
    echo "  → Dropping database '$DB_NAME' with FORCE..."
    if docker compose -f docker-compose.prod.yml exec -T db psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS \"$DB_NAME\" WITH (FORCE);" 2>&1; then
        echo -e "${GREEN}✓ Database dropped successfully${NC}"
    else
        echo -e "${YELLOW}⚠ DROP WITH FORCE failed, trying without FORCE...${NC}"
        docker compose -f docker-compose.prod.yml exec -T db psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS \"$DB_NAME\";" 2>&1 || {
            echo -e "${RED}Error: Failed to drop database${NC}"
            exit 1
        }
    fi
else
    echo "  → Database '$DB_NAME' does not exist, skipping drop."
fi

echo -e "${GREEN}✓ Database cleanup complete${NC}"

echo ""
echo -e "${BLUE}[4/8] Creating fresh database...${NC}"
echo "  → Creating database '$DB_NAME'..."

# Create the database with explicit settings
if docker compose -f docker-compose.prod.yml exec -T db psql -U "$DB_USER" -d postgres -c "CREATE DATABASE \"$DB_NAME\" WITH ENCODING 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' TEMPLATE template0;" 2>&1; then
    echo -e "${GREEN}✓ Fresh database '$DB_NAME' created${NC}"
else
    echo -e "${RED}Error: Failed to create database${NC}"
    exit 1
fi

# Unset password if it was set
if [ -n "$DB_PASSWORD" ]; then
    unset PGPASSWORD
fi

# Alternative approach: If dropping database doesn't work, we can use fake migrations
# This approach drops all tables and resets migration state
echo ""
echo -e "${BLUE}[5/8] Starting API container to run migrations...${NC}"
docker compose -f docker-compose.prod.yml up -d api
echo "  → Waiting for API container to be ready..."
timeout=60
counter=0
while ! docker compose -f docker-compose.prod.yml exec -T api curl -f http://localhost:8000/health/ > /dev/null 2>&1; do
    sleep 2
    counter=$((counter + 2))
    if [ $counter -ge $timeout ]; then
        echo -e "${YELLOW}⚠ API health check timeout, but continuing with migrations...${NC}"
        break
    fi
    echo -n "."
done
echo ""
echo -e "${GREEN}✓ API container ready${NC}"

# Show current migrations (for debugging)
echo ""
echo -e "${BLUE}[6/8] Checking migration files...${NC}"
echo "  → Account migrations:"
docker compose -f docker-compose.prod.yml exec -T api python manage.py showmigrations account 2>&1 | head -20 || true
echo "  → Travel migrations:"
docker compose -f docker-compose.prod.yml exec -T api python manage.py showmigrations travel 2>&1 | head -20 || true
echo -e "${GREEN}✓ Migration files checked${NC}"

# Apply migrations
echo ""
echo -e "${BLUE}[7/8] Applying fresh migrations...${NC}"
if ! docker compose -f docker-compose.prod.yml exec -T api python manage.py migrate --noinput; then
    echo -e "${RED}Error: Migrations failed${NC}"
    echo -e "${YELLOW}Showing last 50 lines of API logs:${NC}"
    docker compose -f docker-compose.prod.yml logs api | tail -50
    exit 1
fi
echo -e "${GREEN}✓ Migrations applied successfully${NC}"

# Show migration status
echo ""
echo -e "${BLUE}Migration Status:${NC}"
docker compose -f docker-compose.prod.yml exec -T api python manage.py showmigrations

# Collect static files
echo ""
echo -e "${BLUE}[8/8] Collecting static files...${NC}"
docker compose -f docker-compose.prod.yml exec -T api python manage.py collectstatic --noinput --clear || {
    echo -e "${YELLOW}⚠ Static files collection had warnings${NC}"
}
echo -e "${GREEN}✓ Static files collected${NC}"

# Restart all services
echo ""
echo -e "${BLUE}Restarting all services...${NC}"
docker compose -f docker-compose.prod.yml up -d
echo -e "${GREEN}✓ All services restarted${NC}"

echo ""
echo -e "${GREEN}=========================================="
echo "✅ Database Reset Complete!"
echo "==========================================${NC}"
echo ""

# Show service status
echo -e "${BLUE}Service Status:${NC}"
docker compose -f docker-compose.prod.yml ps

echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Create a superuser:"
echo "   ${YELLOW}docker compose -f docker-compose.prod.yml exec api python manage.py createsuperuser${NC}"
echo ""
echo "2. Check service health:"
echo "   ${YELLOW}docker compose -f docker-compose.prod.yml ps${NC}"
echo ""
echo "3. View logs:"
echo "   ${YELLOW}docker compose -f docker-compose.prod.yml logs -f api${NC}"
echo ""
echo -e "${GREEN}Database has been reset and migrations applied! 🎉${NC}"
echo ""

