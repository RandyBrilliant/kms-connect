# Firebase Setup Guide for Push Notifications

This guide will walk you through setting up Firebase Cloud Messaging (FCM) for web push notifications in the KMS-Connect application.

## Step 1: Create a Firebase Project

1. **Go to Firebase Console**
   - Visit [https://console.firebase.google.com](https://console.firebase.google.com)
   - Sign in with your Google account

2. **Create a New Project**
   - Click "Add project" or "Create a project"
   - Enter project name: `kms-connect` (or your preferred name)
   - Click "Continue"
   
3. **Configure Google Analytics** (Optional)
   - You can disable it or enable it based on your needs
   - Click "Create project"
   - Wait for project creation to complete (usually 30-60 seconds)

## Step 2: Register Your Web App

1. **Add a Web App to Your Project**
   - From the Firebase console project overview, click the **Web icon** (`</>`)
   - Enter app nickname: `KMS-Connect Web Admin`
   - Check "Also set up Firebase Hosting" (optional - you can skip this)
   - Click "Register app"

2. **Save Your Firebase Config**
   - You'll see a configuration object like this:
   
   ```javascript
   const firebaseConfig = {
     apiKey: "AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
     authDomain: "kms-connect.firebaseapp.com",
     projectId: "kms-connect",
     storageBucket: "kms-connect.appspot.com",
     messagingSenderId: "123456789012",
     appId: "1:123456789012:web:xxxxxxxxxxxx"
   };
   ```
   
   - **IMPORTANT**: Copy this configuration - you'll need it later
   - Click "Continue to console"

## Step 3: Enable Cloud Messaging

1. **Go to Cloud Messaging Settings**
   - In Firebase Console, click the gear icon (⚙️) next to "Project Overview"
   - Click "Project settings"
   - Click on the "Cloud Messaging" tab

2. **Get Your Server Key and Sender ID**
   - You'll see:
     - **Sender ID**: Already visible (same as `messagingSenderId`)
     - **Server key**: Click "Show" to reveal
   - **Note**: For Firebase Admin SDK, we'll use a service account instead of the server key

## Step 4: Generate Service Account Key (For Backend)

1. **Navigate to Service Accounts**
   - In Firebase Console, go to Project Settings (⚙️)
   - Click on the "Service accounts" tab
   - You should see "Firebase Admin SDK"

2. **Generate Private Key**
   - Click "Generate new private key"
   - A dialog will appear warning you to keep it secure
   - Click "Generate key"
   - A JSON file will download automatically
   
3. **Save the Service Account JSON**
   - Rename the file to: `firebase-service-account.json`
   - The file contents look like this:
   
   ```json
   {
     "type": "service_account",
     "project_id": "kms-connect",
     "private_key_id": "xxxxxxxxxxxx",
     "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
     "client_email": "firebase-adminsdk-xxxxx@kms-connect.iam.gserviceaccount.com",
     "client_id": "123456789012345678901",
     "auth_uri": "https://accounts.google.com/o/oauth2/auth",
     "token_uri": "https://oauth2.googleapis.com/token",
     "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
     "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/..."
   }
   ```

4. **Store Securely**
   - Move `firebase-service-account.json` to your project's `backend/` folder
   - **CRITICAL**: Add to `.gitignore` to prevent committing to Git
   - For production, use environment variables or secret management

## Step 5: Get VAPID Key (For Web Push)

1. **Generate Web Push Certificates**
   - Still in Project Settings → Cloud Messaging tab
   - Scroll down to "Web Push certificates" section
   - If no key pair exists, click "Generate key pair"
   
2. **Copy the VAPID Key**
   - You'll see a long string like: `BGpN...` (65+ characters)
   - Save this key - you'll use it in the frontend
   - Example: `BGpNzYQ8RjxxxxxxxxxxxxxxxxxxxxxxxxxxvElC4S0`

## Step 6: Configure Backend

1. **Place Service Account File**
   ```bash
   # Your project structure should look like:
   backend/
   ├── firebase-service-account.json   ← Place here
   ├── backend/
   ├── account/
   ├── manage.py
   └── requirements.txt
   ```

2. **Update .gitignore**
   Add to `backend/.gitignore`:
   ```
   firebase-service-account.json
   ```

3. **Create Environment Variable (Production)**
   For production deployment, instead of a file, use environment variable:
   
   ```bash
   # .env (production)
   FIREBASE_CREDENTIALS_JSON='{"type":"service_account","project_id":"kms-connect",...}'
   ```

## Step 7: Configure Frontend

1. **Create Firebase Config File**
   
   Create `frontend/src/config/firebase.ts`:
   
   ```typescript
   export const firebaseConfig = {
     apiKey: "YOUR_API_KEY_FROM_STEP_2",
     authDomain: "kms-connect.firebaseapp.com",
     projectId: "kms-connect",
     storageBucket: "kms-connect.appspot.com",
     messagingSenderId: "YOUR_SENDER_ID",
     appId: "YOUR_APP_ID"
   }
   
   export const vapidKey = "YOUR_VAPID_KEY_FROM_STEP_5"
   ```

2. **Add to .env (Alternative - Recommended)**
   
   Create `frontend/.env.local`:
   
   ```env
   VITE_FIREBASE_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
   VITE_FIREBASE_AUTH_DOMAIN=kms-connect.firebaseapp.com
   VITE_FIREBASE_PROJECT_ID=kms-connect
   VITE_FIREBASE_STORAGE_BUCKET=kms-connect.appspot.com
   VITE_FIREBASE_MESSAGING_SENDER_ID=123456789012
   VITE_FIREBASE_APP_ID=1:123456789012:web:xxxxxxxxxxxx
   VITE_FIREBASE_VAPID_KEY=BGpNzYQ8RjxxxxxxxxxxxxxxxxxxxxxxxxxxvElC4S0
   ```
   
   Then in your config:
   
   ```typescript
   export const firebaseConfig = {
     apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
     authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
     projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
     storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
     messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
     appId: import.meta.env.VITE_FIREBASE_APP_ID
   }
   
   export const vapidKey = import.meta.env.VITE_FIREBASE_VAPID_KEY
   ```

## Step 8: Verify Setup

### Check Firebase Console
1. Go to Cloud Messaging in Firebase Console
2. You should see:
   - ✅ Cloud Messaging API enabled
   - ✅ Service account created
   - ✅ VAPID key generated

### Check Backend Files
```bash
cd backend
ls -la firebase-service-account.json  # Should exist
cat .gitignore | grep firebase         # Should show firebase-service-account.json
```

### Check Frontend Files
```bash
cd frontend
cat .env.local | grep FIREBASE         # Should show all VITE_FIREBASE_* variables
```

## Security Checklist

- [ ] `firebase-service-account.json` is in `.gitignore`
- [ ] Service account JSON is NOT committed to Git
- [ ] VAPID key is in environment variables (not hardcoded)
- [ ] Firebase config is in `.env.local` (not committed to Git)
- [ ] Production uses environment variables for sensitive data

## Troubleshooting

### Issue: "Firebase Admin SDK not initialized"
**Solution**: Check that `firebase-service-account.json` exists and path is correct in settings.py

### Issue: "Permission denied" when sending notifications
**Solution**: Verify service account has correct permissions in Firebase Console

### Issue: "Invalid VAPID key"
**Solution**: Ensure VAPID key is copied correctly (should be 65+ characters starting with 'B')

### Issue: "Request had insufficient authentication scopes"
**Solution**: Regenerate service account key or check Firebase Admin SDK initialization

## Next Steps

After completing this setup:

1. ✅ Install Python dependencies: `pip install firebase-admin`
2. ✅ Install JavaScript dependencies: `npm install firebase`
3. ✅ Run migrations to add notification models
4. ✅ Test sending a notification from Django admin
5. ✅ Test receiving notification in browser

## Additional Resources

- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Firebase Admin SDK Setup](https://firebase.google.com/docs/admin/setup)
- [Web Push Notifications](https://firebase.google.com/docs/cloud-messaging/js/client)
- [VAPID Keys Explained](https://developers.google.com/web/fundamentals/push-notifications/web-push-protocol)

---

**Important Security Note**: 
- The `firebase-service-account.json` contains private keys with full access to your Firebase project
- NEVER commit it to version control
- NEVER share it publicly
- For production, use environment variables or secret management services
