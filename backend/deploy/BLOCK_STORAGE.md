# DigitalOcean Block Storage for KMS-Connect

This guide adds **DigitalOcean Block Storage** so your database and uploaded files (media/static) live on a separate volume. Benefits:

- **Persistent** – Data survives Droplet rebuilds if you detach and reattach the volume
- **Resizable** – Increase size later without migrating the Droplet
- **Backups** – Use DO Volume Snapshots for database/media backups

---

## Overview

1. Create a Block Storage volume in the DigitalOcean control panel (same region/datacenter as your Droplet).
2. Attach the volume to your Droplet.
3. On the server: format (if new), mount, and create directories.
4. Use the provided Compose override so Docker uses the mounted path.

**Mount path used here:** `/mnt/kms-data`  
**Subdirectories:** `postgres`, `media`, `static` (used by Docker).

---

## Storage size: matching your app for thousands of pelamar

Your app stores per applicant (pelamar):

| Data | Per applicant | Notes |
|------|----------------|--------|
| **Profile photo** | ≤ 500 KB | Pas photo (one per pelamar) |
| **Documents** | Up to ~19 MB max | 8 PDF types (max 2 MB each) + 5 image types (max 500 KB each): KTP, KK, BPJS, paspor, ijasah, surat kesehatan, perjanjian, dll. |
| **Typical real usage** | ~4–8 MB | Not every pelamar uploads every doc; many files under the limit. |
| **PostgreSQL** | ~50–200 KB | Biodata, NIK, status, OCR text, review notes, etc. |

**Recommended Block Storage size by scale:**

| Jumlah pelamar | Suggested volume size | Notes |
|----------------|------------------------|--------|
| **1,000** | **25 GB** | Plenty for media + DB + static; room to grow. |
| **2,000–5,000** | **50 GB** | Comfortable for “thousands”; can resize later. |
| **5,000–10,000** | **100 GB** | Fits heavy usage (many docs per pelamar). |
| **10,000+** | **100 GB+** or resize | DigitalOcean lets you resize volume up without recreating. |

**First requirement that matches your current app and supports thousands of pelamar:** start with **50 GB**. That fits roughly 5,000–7,000 pelamar at typical usage (4–8 MB each) plus database and static files, with buffer. You can resize the volume later in the DO control panel if you need more.

---

## Step 1: Create and attach the volume (DigitalOcean)

1. In [DigitalOcean Control Panel](https://cloud.digitalocean.com/) go to **Volumes** → **Create Volume**.
2. Choose:
   - **Datacenter:** Same as your Droplet (e.g. SGP1, NYC1).
   - **Size:** For thousands of pelamar, **50 GB** is a good start (see [Storage size](#storage-size-matching-your-app-for-thousands-of-pelamar) above). Min 1 GB; you can resize the volume up later in DO.
   - **Name:** e.g. `kms-connect-data`.
3. Click **Create Volume**.
4. **Attach** the volume to your KMS-Connect Droplet (Volumes → ⋮ → Attach to Droplet).

After attaching, the volume appears as a block device, e.g. `/dev/disk/by-id/scsi-0DO_Volume_kms-connect-data` (exact name is shown in DO under the volume).

---

## Step 2: Mount the volume on the server

SSH into your Droplet, then run the mount script from the project (run from repo root so `deploy/` exists):

```bash
cd /path/to/kms-connect/backend
sudo ./deploy/mount-block-storage.sh
```

The script will:

- Detect the DO volume block device (e.g. `/dev/disk/by-id/scsi-0DO_Volume_*`).
- Create a filesystem if the volume is new (ext4).
- Mount it at `/mnt/kms-data`.
- Add an entry to `/etc/fstab` so it mounts on reboot.
- Create `/mnt/kms-data/postgres`, `media`, `static` with correct ownership for Docker.

**If you prefer to do it manually**, see [Manual mount steps](#manual-mount-steps) at the end of this doc.

---

## Step 3: Use Block Storage with Docker Compose

### I already ran mount-block-storage.sh and deploy.sh (first-time deployment)

Switch the running stack to use the volume so **all new data** goes to Block Storage:

```bash
cd /path/to/kms-connect/backend   # replace with your backend path

# 1. Stop the stack (containers only; old named volumes stay but we won’t use them)
docker compose -f docker-compose.prod.yml down

# 2. Start with Block Storage (postgres/media/static on /mnt/kms-data)
docker compose -f docker-compose.prod.yml -f docker-compose.prod.block.yml up -d

# 3. Wait for DB to be ready, then run migrations (entrypoint may have run them; this ensures they’re applied on the new volume)
sleep 10
docker compose -f docker-compose.prod.yml -f docker-compose.prod.block.yml exec api python manage.py migrate --noinput

# 4. Collect static files onto the volume
docker compose -f docker-compose.prod.yml -f docker-compose.prod.block.yml exec api python manage.py collectstatic --noinput --clear

# 5. Create admin user (database on block storage is fresh)
docker compose -f docker-compose.prod.yml -f docker-compose.prod.block.yml exec api python manage.py createsuperuser
```

From now on **always** use both compose files (see [below](#from-now-on-always-use-both-compose-files)).

---

**First time (existing deployment with data you want to keep):**

1. Stop the stack: `docker compose -f docker-compose.prod.yml down`
2. (Optional) Copy existing data from Docker volumes to Block Storage, then start with the override. If you skip this, you’ll start with an empty database and empty media (see [Migrating existing data](#migrating-existing-data) below).
3. Start with the Block Storage override:
   ```bash
   docker compose -f docker-compose.prod.yml -f docker-compose.prod.block.yml up -d
   ```

**New deployment (no existing data, block storage mounted before first deploy):**

Use the override from the first `up` so data goes to Block Storage from the start:

```bash
sudo ./deploy/deploy.sh
# Then switch to block storage and restart:
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml -f docker-compose.prod.block.yml up -d
docker compose -f docker-compose.prod.yml -f docker-compose.prod.block.yml exec api python manage.py migrate --noinput
docker compose -f docker-compose.prod.yml -f docker-compose.prod.block.yml exec api python manage.py collectstatic --noinput --clear
```

### From now on, always use both compose files

When using Block Storage, **always** pass both files when starting, stopping, or updating:

```bash
docker compose -f docker-compose.prod.yml -f docker-compose.prod.block.yml up -d
docker compose -f docker-compose.prod.yml -f docker-compose.prod.block.yml down
docker compose -f docker-compose.prod.yml -f docker-compose.prod.block.yml logs -f
docker compose -f docker-compose.prod.yml -f docker-compose.prod.block.yml ps
```

**Optional:** so you don’t have to type both files every time, set this in your shell or in `.env` on the server (Docker Compose reads `COMPOSE_FILE`):

```bash
export COMPOSE_FILE=docker-compose.prod.yml:docker-compose.prod.block.yml
# then you can run:
docker compose up -d
docker compose down
```

---

## Migrating existing data to Block Storage

If you already have data in Docker named volumes and want to move it to Block Storage:

1. Mount Block Storage (Step 2) so `/mnt/kms-data` exists with `postgres`, `media`, `static`.
2. Stop the stack:
   ```bash
   docker compose -f docker-compose.prod.yml down
   ```
3. Copy data from the old volumes into the mount (example; adjust volume names if different):
   ```bash
   # Create a temporary container that has the volume mounted
   docker run --rm -v kms-connect_postgres_data:/from -v /mnt/kms-data/postgres:/to alpine sh -c "cp -a /from/. /to/"
   docker run --rm -v kms-connect_media_volume:/from -v /mnt/kms-data/media:/to alpine sh -c "cp -a /from/. /to/"
   docker run --rm -v kms-connect_static_volume:/from -v /mnt/kms-data/static:/to alpine sh -c "cp -a /from/. /to/"
   ```
   (Volume names may be prefixed with the project directory name, e.g. `backend_postgres_data`. Check with `docker volume ls`.)
4. Fix ownership for Postgres (postgres user in container often uses UID 999):
   ```bash
   sudo chown -R 999:999 /mnt/kms-data/postgres
   sudo chown -R 1000:1000 /mnt/kms-data/media /mnt/kms-data/static
   ```
5. Start with the override:
   ```bash
   docker compose -f docker-compose.prod.yml -f docker-compose.prod.block.yml up -d
   ```

---

## Snapshots and backups

- In DigitalOcean: **Volumes** → select volume → **Take Snapshot**. Use snapshots to restore the volume or clone it.
- For database-only backups, continue using `pg_dump` (or your existing backup scripts); volume snapshots are a complementary, full-disk backup.

---

## Manual mount steps

If you don’t use the script, do the following (replace `VOLUME_ID` with the actual device, e.g. `scsi-0DO_Volume_kms-connect-data`):

```bash
# Find the device (after attaching in DO)
ls /dev/disk/by-id/

# Format (only if new volume; this erases data!)
sudo mkfs.ext4 -F /dev/disk/by-id/scsi-0DO_Volume_VOLUME_ID

# Mount point and mount
sudo mkdir -p /mnt/kms-data
sudo mount -o defaults,nofail,discard /dev/disk/by-id/scsi-0DO_Volume_VOLUME_ID /mnt/kms-data

# Persist in fstab (use the same by-id path)
echo '/dev/disk/by-id/scsi-0DO_Volume_VOLUME_ID /mnt/kms-data ext4 defaults,nofail,discard 0 2' | sudo tee -a /etc/fstab

# Create directories and set ownership for Docker
sudo mkdir -p /mnt/kms-data/postgres /mnt/kms-data/media /mnt/kms-data/static
sudo chown -R 999:999 /mnt/kms-data/postgres
sudo chown -R 1000:1000 /mnt/kms-data/media /mnt/kms-data/static
```

Use your actual volume ID from `ls /dev/disk/by-id/`.

---

## Troubleshooting

- **Permission denied (media/static):** If the API container cannot write to media/static, adjust ownership. If the app runs as root in the container: `sudo chown -R 0:0 /mnt/kms-data/media /mnt/kms-data/static`. If it runs as UID 1000: `sudo chown -R 1000:1000 /mnt/kms-data/media /mnt/kms-data/static`.
- **Volume not found at boot:** Ensure the fstab line uses `/dev/disk/by-id/...` (not `/dev/sdX`) and includes `nofail` so the system boots if the volume is detached.
- **Deploy/update scripts:** When using Block Storage, run compose with both files, e.g. `docker compose -f docker-compose.prod.yml -f docker-compose.prod.block.yml up -d`. You can add a one-line wrapper or set `COMPOSE_FILE=docker-compose.prod.yml:docker-compose.prod.block.yml` in `.env` on the server (Docker Compose reads that automatically).
