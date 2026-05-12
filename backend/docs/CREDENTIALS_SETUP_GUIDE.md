# Credentials Setup Guide

This guide explains how to properly manage Firebase and Google Cloud Vision service account credentials in your KMS-Connect project.

## Overview

You have two service account credentials:
1. **Firebase Service Account** (`firebase-service-account.json`) - For Firebase Cloud Messaging (push notifications)
2. **Google Cloud Vision Service Account** (`vision-sa.json`) - For OCR document processing

## File Structure

```
backend/
├── .env                                    # Local environment config (Git ignored)
├── .gitignore                             # Git ignore rules
├── env.example                            # Template for environment variables
├── firebase-service-account.json          # Firebase credentials (⚠️ NOT in Git)
├── vision-sa.json                         # Vision API credentials (⚠️ NOT in Git)
└── backend/
    └── settings.py                        # Django settings
```

## Git Protection

### What's Ignored (Never Committed)

Both credential files are protected in `.gitignore`:

```gitignore
# Service account credentials (Firebase, Google Cloud Vision, etc.)
firebase-service-account.json
vision-sa.json
*.json.key
```

✅ **These files are safe** - they won't be accidentally committed to Git.

## Environment Variables Setup

### Local Development

In `/backend/.env` (not version controlled):

```dotenv
# Google Cloud Vision - OCR for documents
GOOGLE_APPLICATION_CREDENTIALS=vision-sa.json

# Firebase Cloud Messaging - Push notifications  
FIREBASE_CREDENTIALS_PATH=firebase-service-account.json
```

### Docker/Production Environment

For Docker or production servers, use absolute paths or mount volumes:

```dotenv
# Example in Docker container
GOOGLE_APPLICATION_CREDENTIALS=/app/secrets/vision-sa.json
FIREBASE_CREDENTIALS_PATH=/app/secrets/firebase-service-account.json
```

## Setup Instructions

### 1. Acquire Firebase Credentials

1. Go to **Firebase Console** → Your Project → Project Settings
2. Click **Service Accounts** tab
3. Click **Generate New Private Key**
4. Save as `backend/firebase-service-account.json`

### 2. Acquire Google Cloud Vision Credentials

1. Go to **Google Cloud Console** → Your Project
2. Enable **Cloud Vision API**
3. Create a Service Account: **IAM & Admin** → **Service Accounts**
4. Create a new key (JSON format)
5. Grant role: **Cloud Vision API User** or **Editor**
6. Save as `backend/vision-sa.json`

### 3. Verify .gitignore

Confirm both files are in `/backend/.gitignore`:

```bash
grep -E "firebase-service-account|vision-sa" backend/.gitignore
```

Should return:
```
firebase-service-account.json
vision-sa.json
```

### 4. Update Django Settings

The settings are already configured to use environment variables:

**At startup**, `settings.py` does:

```python
# Google Cloud Vision
GOOGLE_APPLICATION_CREDENTIALS = _env("GOOGLE_APPLICATION_CREDENTIALS", "")
if GOOGLE_APPLICATION_CREDENTIALS:
    if not os.path.isabs(GOOGLE_APPLICATION_CREDENTIALS):
        GOOGLE_APPLICATION_CREDENTIALS = os.path.join(BASE_DIR, GOOGLE_APPLICATION_CREDENTIALS)
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = GOOGLE_APPLICATION_CREDENTIALS

# Firebase
FIREBASE_CREDENTIALS_PATH = _env("FIREBASE_CREDENTIALS_PATH", "")
if not FIREBASE_CREDENTIALS_PATH:
    default_path = os.path.join(BASE_DIR, "firebase-service-account.json")
    if os.path.exists(default_path):
        FIREBASE_CREDENTIALS_PATH = default_path
elif not os.path.isabs(FIREBASE_CREDENTIALS_PATH):
    FIREBASE_CREDENTIALS_PATH = os.path.join(BASE_DIR, FIREBASE_CREDENTIALS_PATH)
```

## Deployment Scenarios

### Local Development

```bash
# Credentials are in backend/ directory
# .env contains relative paths
GOOGLE_APPLICATION_CREDENTIALS=vision-sa.json
FIREBASE_CREDENTIALS_PATH=firebase-service-account.json
```

### Docker Compose (Local/Testing)

```yaml
# docker-compose.yml
services:
  web:
    volumes:
      - ./backend/firebase-service-account.json:/app/secrets/firebase-service-account.json:ro
      - ./backend/vision-sa.json:/app/secrets/vision-sa.json:ro
    environment:
      FIREBASE_CREDENTIALS_PATH=/app/secrets/firebase-service-account.json
      GOOGLE_APPLICATION_CREDENTIALS=/app/secrets/vision-sa.json
```

### Docker (Production)

Options:
1. **Store in Docker secrets** (recommended for Swarm)
2. **Use environment-based credentials** (Google Cloud Run has default service account)
3. **Mount from secure volume** (Kubernetes, etc.)

```bash
# Example: Cloud Run with mounted secrets
gcloud run deploy kms-connect \
  --set-env-vars=FIREBASE_CREDENTIALS_PATH=/var/secrets/firebase-sa.json \
  --update-secrets=/var/secrets=firebase-sa:latest \
  --update-secrets=/var/secrets/vision-sa=vision-sa:latest
```

### Google Cloud Run

If using **Cloud Run**, the default service account can be used:

```python
# Django settings.py already handles empty credentials
# Cloud Run automatically uses the service account
if not GOOGLE_APPLICATION_CREDENTIALS:
    # Uses Application Default Credentials (service account)
    pass
```

## Troubleshooting

### Vision API Not Working

1. **Check if credential file exists:**
   ```bash
   ls -la backend/vision-sa.json
   ```

2. **Test the path:**
   ```bash
   python -c "import os; print(os.path.exists(os.environ.get('GOOGLE_APPLICATION_CREDENTIALS', 'vision-sa.json')))"
   ```

3. **Verify API is enabled:**
   - Go to [Google Cloud Console](https://console.cloud.google.com)
   - Search "Cloud Vision API"
   - Click **Enable**

4. **Check service account permissions:**
   - Service account needs **Cloud Vision API User** role

### Firebase Push Notifications Not Working

1. **Check file exists:**
   ```bash
   ls -la backend/firebase-service-account.json
   ```

2. **Verify Firebase project settings:**
   - Go to Firebase Console
   - Check your project is correctly configured
   - Cloud Messaging tab is enabled

3. **Test the connection:**
   ```bash
   python manage.py shell
   >>> from django.conf import settings
   >>> print(settings.FIREBASE_CREDENTIALS_PATH)
   ```

## Security Best Practices

✅ **Do**
- Keep credentials in `.gitignore`
- Use environment variables
- Rotate keys periodically
- Use separate service accounts for different services
- Grant minimal required permissions
- Store secrets in secure vaults (1Password, HashiCorp Vault, etc.)

❌ **Don't**
- Commit credential files to Git
- Share credentials via Slack/Email
- Store credentials in code
- Use production credentials in development
- Hardcode paths

## Environment Template

Use `env.example` as a template. For new developers:

```bash
# Copy template
cp backend/env.example backend/.env

# Edit with your credentials
nano backend/.env

# Add the credential files
# Download from Firebase & Google Cloud Console
# Place in backend/ directory
```

## Next Steps

1. ✅ Both credential files exist in `backend/`
2. ✅ `.gitignore` updated to exclude credentials
3. ✅ `settings.py` configured to use env variables
4. ✅ `.env` and `env.example` updated
5. 🔄 Ensure credentials have correct permissions in Google Cloud
6. 🔄 Test Vision API: Run OCR on a document
7. 🔄 Test Firebase: Send test push notification

## Additional Resources

- [Firebase Setup Guide](./FIREBASE_SETUP_GUIDE.md)
- [Django Settings](./backend/backend/settings.py#L300)
- [Google Cloud Console](https://console.cloud.google.com)
- [Firebase Console](https://console.firebase.google.com)
