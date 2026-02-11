#!/bin/bash
# Mount DigitalOcean Block Storage for KMS-Connect
# Run as root/sudo. Creates /mnt/kms-data with postgres, media, static subdirs.
# See deploy/BLOCK_STORAGE.md for full guide.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MOUNT_POINT="/mnt/kms-data"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

echo -e "${BLUE}=========================================="
echo "KMS-Connect – Block Storage Mount"
echo "==========================================${NC}"
echo ""

# Find DigitalOcean volume (attached block device by id)
DO_DEVICE=""
for d in /dev/disk/by-id/scsi-0DO_Volume_*; do
    [ -e "$d" ] || continue
    # Resolve to actual device
    real=$(readlink -f "$d")
    if [ -b "$real" ]; then
        DO_DEVICE=$d
        break
    fi
done

if [ -z "$DO_DEVICE" ]; then
    echo -e "${RED}No DigitalOcean Block Storage volume found.${NC}"
    echo "1. Create a Volume in DigitalOcean (Volumes → Create Volume)."
    echo "2. Attach it to this Droplet (same datacenter)."
    echo "3. Run this script again."
    exit 1
fi

echo -e "${GREEN}Found volume: $DO_DEVICE${NC}"
REAL_DEVICE=$(readlink -f "$DO_DEVICE")

# Already mounted?
if mount | grep -q "$MOUNT_POINT"; then
    echo -e "${GREEN}$MOUNT_POINT is already mounted.${NC}"
else
    # New filesystem?
    if ! blkid -o value -s TYPE "$REAL_DEVICE" &>/dev/null; then
        echo -e "${YELLOW}Formatting new volume with ext4 (this may take a moment)...${NC}"
        mkfs.ext4 -F "$REAL_DEVICE"
    fi

    mkdir -p "$MOUNT_POINT"
    mount -o defaults,nofail,discard "$REAL_DEVICE" "$MOUNT_POINT"
    echo -e "${GREEN}Mounted at $MOUNT_POINT${NC}"

    # Add to fstab if not present
    if ! grep -q "$MOUNT_POINT" /etc/fstab; then
        echo "$DO_DEVICE $MOUNT_POINT ext4 defaults,nofail,discard 0 2" >> /etc/fstab
        echo -e "${GREEN}Added to /etc/fstab for mount on boot${NC}"
    fi
fi

# Create directories for Docker
mkdir -p "$MOUNT_POINT/postgres" "$MOUNT_POINT/media" "$MOUNT_POINT/static"
# Postgres in container typically runs as UID 999
chown -R 999:999 "$MOUNT_POINT/postgres"
# App/nginx often run as root in container but static/media written by app (often 1000)
chown -R 1000:1000 "$MOUNT_POINT/media" "$MOUNT_POINT/static"
chmod 755 "$MOUNT_POINT/postgres" "$MOUNT_POINT/media" "$MOUNT_POINT/static"
echo -e "${GREEN}Created postgres, media, static with correct ownership${NC}"

echo ""
echo -e "${GREEN}=========================================="
echo "✅ Block Storage ready at $MOUNT_POINT"
echo "==========================================${NC}"
echo ""
echo "Next: start the stack with the block-storage override:"
echo "  ${BLUE}docker compose -f docker-compose.prod.yml -f docker-compose.prod.block.yml up -d${NC}"
echo ""
echo "See deploy/BLOCK_STORAGE.md for full instructions."
echo ""
