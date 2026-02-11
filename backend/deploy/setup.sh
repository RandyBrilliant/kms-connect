#!/bin/bash

# Initial Server Setup Script - KMS-Connect
# Run this ONCE on a fresh Digital Ocean droplet
# Supported: Ubuntu 22.04 LTS (Jammy), Ubuntu 24.04 LTS (Noble)
# Optimized for 1 vCPU, 2GB RAM

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect Ubuntu version (optional check)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    UBUNTU_VERSION="${VERSION_ID:-unknown}"
    UBUNTU_CODENAME="${VERSION_CODENAME:-}"
else
    UBUNTU_VERSION="unknown"
    UBUNTU_CODENAME=""
fi

echo -e "${BLUE}=========================================="
echo "KMS-Connect - Server Setup"
echo "Optimized for: 1 vCPU, 2GB RAM"
echo "==========================================${NC}"
if [ "$UBUNTU_VERSION" != "unknown" ]; then
    echo -e "${BLUE}Detected: $PRETTY_NAME${NC}"
fi
echo ""

# Optional: warn on unsupported Ubuntu (older than 22.04)
if [ -n "$UBUNTU_CODENAME" ]; then
    case "$UBUNTU_CODENAME" in
        jammy|noble) ;;
        *) echo -e "${YELLOW}⚠ This script is tested on Ubuntu 22.04 (jammy) and 24.04 (noble). Continuing anyway.${NC}" ;;
    esac
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}[1/8] Updating system packages...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
echo -e "${GREEN}✓ System updated${NC}"

echo ""
echo -e "${BLUE}[2/8] Installing essential packages...${NC}"
apt-get install -y -qq \
    curl \
    wget \
    git \
    ufw \
    certbot \
    python3-certbot-nginx \
    dnsutils \
    htop \
    nano \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release
# dnsutils provides dig (used by ssl-setup.sh for DNS checks)
echo -e "${GREEN}✓ Essential packages installed${NC}"

echo ""
echo -e "${BLUE}[3/9] Disabling system nginx/apache (Docker nginx will use ports 80/443)...${NC}"
systemctl stop nginx 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true
systemctl stop apache2 2>/dev/null || true
systemctl disable apache2 2>/dev/null || true
echo -e "${GREEN}✓ Ports 80 and 443 left for Docker nginx${NC}"

echo ""
echo -e "${BLUE}[4/9] Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start Docker
    systemctl enable docker
    systemctl start docker
    echo -e "${GREEN}✓ Docker installed${NC}"
else
    echo -e "${GREEN}✓ Docker already installed${NC}"
fi

echo ""
echo -e "${BLUE}[5/9] Optimizing system for 2GB RAM...${NC}"

# Configure memory overcommit for Redis
if ! grep -q "vm.overcommit_memory = 1" /etc/sysctl.conf; then
    echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf
    sysctl vm.overcommit_memory=1
fi

# Reduce swappiness
if ! grep -q "vm.swappiness = 10" /etc/sysctl.conf; then
    echo "vm.swappiness = 10" >> /etc/sysctl.conf
    sysctl vm.swappiness=10
fi

# Apply sysctl settings (ignore errors from missing/invalid keys)
sysctl -p 2>/dev/null || true
echo -e "${GREEN}✓ System optimized${NC}"

echo ""
echo -e "${BLUE}[6/9] Setting up swap space...${NC}"
if ! swapon --show | grep -q '/swapfile'; then
    # Create 2GB swap file (fallocate is fast; dd fallback for some filesystems)
    if ! fallocate -l 2G /swapfile 2>/dev/null; then
        dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048
    fi
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    echo -e "${GREEN}✓ 2GB swap file created${NC}"
else
    echo -e "${GREEN}✓ Swap already exists${NC}"
fi

echo ""
echo -e "${BLUE}[7/9] Configuring firewall (UFW)...${NC}"
# Allow SSH (important!)
ufw allow 22/tcp
# Allow HTTP and HTTPS
ufw allow 80/tcp
ufw allow 443/tcp
# Enable firewall (non-interactive)
ufw --force enable
echo -e "${GREEN}✓ Firewall configured${NC}"

echo ""
echo -e "${BLUE}[8/9] Optimizing Docker for low memory...${NC}"
# Configure Docker daemon
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
systemctl restart docker
sleep 2
echo -e "${GREEN}✓ Docker optimized${NC}"

echo ""
echo -e "${BLUE}[9/9] Creating necessary directories...${NC}"
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/nginx/logs"
mkdir -p "$PROJECT_DIR/media"
mkdir -p "$PROJECT_DIR/staticfiles"
mkdir -p "$PROJECT_DIR/nginx/ssl"
chmod 755 "$PROJECT_DIR/logs" "$PROJECT_DIR/nginx/logs" "$PROJECT_DIR/media" "$PROJECT_DIR/staticfiles" "$PROJECT_DIR/nginx/ssl"
echo -e "${GREEN}✓ Directories created${NC}"

echo ""
echo -e "${GREEN}=========================================="
echo "✅ Server Setup Complete!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}System Information:${NC}"
echo "  OS: $(lsb_release -ds 2>/dev/null || echo 'Unknown')"
echo "  Memory: $(free -h | awk '/^Mem:/ {print $2}')"
echo "  Swap: $(free -h | awk '/^Swap:/ {print $2}')"
echo "  vCPUs: $(nproc)"
echo "  Docker: $(docker --version)"
echo "  Docker Compose: $(docker compose version 2>/dev/null | head -1 || echo 'N/A')"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Configure your .env file:"
echo "   ${BLUE}cd $PROJECT_DIR${NC}"
echo "   ${BLUE}cp env.example .env${NC}"
echo "   ${BLUE}nano .env${NC}"
echo ""
echo "2. Deploy the application:"
echo "   ${BLUE}sudo ./deploy/deploy.sh${NC}"
echo ""
echo -e "${GREEN}Setup complete! 🎉${NC}"
echo ""

