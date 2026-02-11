# DigitalOcean Spaces for Media (Better Performance)

Use **DigitalOcean Spaces** for media (uploaded documents, photos) so they are served via **CDN** for faster delivery to admin web and mobile apps (Android/iOS) for thousands of users.

Your app already supports Spaces: set the env vars below and redeploy. No code changes needed.

---

## 1. Create a Space (DigitalOcean)

1. In [DigitalOcean Control Panel](https://cloud.digitalocean.com/) go to **Spaces** → **Create Space**.
2. Choose:
   - **Datacenter:** Same as your Droplet (e.g. **SGP1**).
   - **Enable CDN:** **Yes** (for better performance).
   - **Name:** e.g. `kms-connect-media`.
3. Create the Space.

---

## 2. Create Spaces API keys

1. **API** → **Spaces Keys** → **Generate New Key**.
2. Name it (e.g. `kms-connect-spaces`).
3. Copy **Access Key** and **Secret** (you won’t see the secret again).

---

## 3. Get the CDN URL (for performance)

1. Open your Space → **Settings**.
2. Under **CDN**, note the **Edge URL**, e.g.  
   `https://kms-connect-media.sgp1.cdn.digitaloceanspaces.com`

---

## 4. Set env vars on the server

On the server, edit `.env` in the backend directory:

```bash
cd ~/kms-connect/backend
nano .env
```

Add or set (replace with your values):

```env
# DigitalOcean Spaces – media storage (CDN for better performance)
DO_SPACES_BUCKET_NAME=kms-connect-media
DO_SPACES_REGION=sgp1
DO_SPACES_ACCESS_KEY_ID=your-spaces-access-key
DO_SPACES_SECRET_ACCESS_KEY=your-spaces-secret

# CDN URL (from Space → Settings → CDN → Edge URL, without https://)
DO_SPACES_CDN_DOMAIN=kms-connect-media.sgp1.cdn.digitaloceanspaces.com

# Required for CDN: files must be public-read so the CDN can serve them
DO_SPACES_ACL=public-read
```

Save and exit.

---

## 5. Redeploy

Restart the API so it picks up the new env and uses Spaces for new uploads:

```bash
cd ~/kms-connect/backend
sudo ./deploy/update.sh
```

Or manually:

```bash
docker compose -f docker-compose.prod.yml restart api celery celery-beat
```

---

## 6. Optional: migrate existing media to Spaces

If you already have media on the Droplet (or Block Storage) and want it in Spaces:

1. Install Django’s `collectstatic`-style approach won’t move media. Use a one-off script or `django-admin` + custom command to list `ApplicantDocument` and other models with `FileField`, then for each file: read from current storage, write to default storage (Spaces). Or use `s3cmd` / `rclone` to sync the `media/` directory to the Space bucket (same path structure).
2. After migration, new uploads go to Spaces; old URLs may need updating if you change `MEDIA_URL` (your app uses `MEDIA_URL` from settings; with `AWS_S3_CUSTOM_DOMAIN` set, django-storages will generate CDN URLs for new files).

---

## Summary

| Before (Droplet/Block) | After (Spaces + CDN) |
|------------------------|----------------------|
| Media served from your Droplet | Media served from CDN edge |
| All traffic hits one server     | Static/media traffic offloaded |
| Slower for users far from Droplet | Faster for mobile users everywhere |

**Dependencies:** Your app already has `django-storages` and `boto3` in `requirements.txt`. No extra install needed.

**Security:** With `DO_SPACES_ACL=public-read`, anyone with the URL can access the file. For sensitive documents you can keep `DO_SPACES_ACL=private` and serve files via signed URLs (requires a small code change to generate presigned URLs in the API).
