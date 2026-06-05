# Google & Apple Sign-In Setup Guide

Complete guide to make Google Sign-In and Apple Sign-In work across the
KMS Connect stack (Backend + Mobile).

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Current State Audit](#2-current-state-audit)
3. [Google Sign-In Setup](#3-google-sign-in-setup)
4. [Apple Sign-In Setup](#4-apple-sign-in-setup)
5. [Backend Configuration](#5-backend-configuration)
6. [Mobile Configuration Verification](#6-mobile-configuration-verification)
7. [Testing Checklist](#7-testing-checklist)
8. [Authentication Flow Diagrams](#8-authentication-flow-diagrams)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Architecture Overview

```
Mobile App (Flutter)
  │
  ├── GoogleSignIn plugin ─► Google native SDK ─► returns ID token
  ├── SignInWithApple plugin ─► Apple native SDK ─► returns identity token
  │
  └── POST /api/auth/google/  { id_token }
      POST /api/auth/apple/   { identity_token, full_name }
          │
          ▼
      Backend (Django)
        ├── Verifies token with Google/Apple public keys
        ├── Creates or finds user
        ├── Returns JWT access + refresh tokens
        └── Returns needs_registration: true if profile incomplete
```

**The flow is "server-side token verification"** — the mobile app gets a
signed token from Google/Apple natively, then sends it to the backend.
The backend verifies it independently (no redirect URLs needed for mobile).

---

## 2. Current State Audit

### What's Already Done (code is ready)

| Component | Status |
|-----------|--------|
| `SocialAuthService` (Dart) | Implemented — calls `google_sign_in` and `sign_in_with_apple` plugins |
| `AuthRepository.googleSignIn()` / `.appleSignIn()` | Implemented — sends tokens to backend |
| `AuthProvider.googleSignIn()` / `.appleSignIn()` | Implemented — state management wired |
| `GoogleOAuthView` (Django) | Implemented — verifies Google ID token, creates/finds user |
| `AppleOAuthView` (Django) | Implemented — verifies Apple identity token via JWKS |
| `GoogleCompleteRegistrationView` | Implemented — profile completion after social sign-up |
| Login page UI (3 buttons) | Implemented — redesigned in this update |
| `needs_registration` flow | Implemented — redirects to `/register` when profile incomplete |

### What's NOT Done (needs configuration)

| Item | Issue |
|------|-------|
| **Google OAuth Client ID** | `google-services.json` has empty `oauth_client` array |
| **`GOOGLE_CLIENT_ID` in backend `.env`** | Not set |
| **`APPLE_CLIENT_ID` in backend `.env`** | Not set |
| **iOS "Sign in with Apple" capability** | Missing from entitlements |
| **iOS bundle ID** | `id.kmsconnect.app` (Xcode, entitlements, `GoogleService-Info.plist`) |
| **Android SHA-1 fingerprint** | Not registered in Firebase/GCP for OAuth |

---

## 3. Google Sign-In Setup

### Step 3.1 — Get SHA-1 Fingerprints

Google Sign-In on Android requires your app's SHA-1 signing certificate
fingerprint to be registered.

**Debug fingerprint:**

```bash
# Windows
cd mobile/android
.\gradlew signingReport
```

Look for the `SHA1` line under `Variant: debug`. Example output:
```
SHA1: DA:39:A3:EE:5E:6B:4B:0D:32:55:BF:EF:95:60:18:90:AF:D8:07:09
```

**Release fingerprint:**

```bash
keytool -list -v -keystore <path-to-your-keystore.jks> -alias <alias>
```

Copy both SHA-1 values.

### Step 3.2 — Register SHA-1 in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project **kms-connect-1541d**
3. Go to **Project Settings** > **General**
4. Under **Your apps**, find the Android app **id.kmsconnect.app**
5. Click **Add fingerprint**
6. Paste the **debug SHA-1** and save
7. Paste the **release SHA-1** and save
8. **Download the updated `google-services.json`**
9. Replace `mobile/android/app/google-services.json` with the new file

After this, `google-services.json` should have an `oauth_client` entry
with `client_type: 3` (Web client).

### Step 3.2b — Firebase: "Can't enable Google sign-in — identical OAuth client already exists"

Firebase tries to create **Android** OAuth clients when you enable Google as a
sign-in provider. Google Cloud **does not allow** two Android clients with the
same **package name + SHA-1 certificate fingerprint**. If you (or an earlier
setup) already created that Android client manually, Firebase cannot create a
second one, so the console shows this warning and `google-services.json` may
keep an empty `oauth_client` array.

**Fix (pick one path):**

1. **Remove the duplicate in Google Cloud (preferred)**  
   - Open [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials) for the **same** project as Firebase (`kms-connect-1541d`).  
   - Under **OAuth 2.0 Client IDs**, find **Android** clients for `id.kmsconnect.app`.  
   - If there are two entries with the **same** SHA-1 (or one is clearly an old manual test), delete the **redundant** one — usually keep the client Firebase would manage, or the oldest stable one, and remove the duplicate you created by hand.  
   - Return to Firebase → **Authentication** → **Sign-in method** → enable **Google** again, then re-download `google-services.json`.

2. **Do not delete if unsure** — use the manual Web client ID instead (next step and Step 3.6): copy the **Web client** ID from Credentials, set it in the mobile `.env` as `GOOGLE_WEB_CLIENT_ID` and in the backend as `GOOGLE_CLIENT_ID`. The Android client that already exists (with your SHA-1) can still satisfy the native sign-in flow; the Web client ID is what your app uses to obtain an **ID token** for the backend.

3. **Clean up stale Firebase apps** — if you still have an Android app registered as `com.example.mobile` in Firebase, remove it from **Project settings → Your apps** if you no longer use that package. It does not fix the duplicate by itself, but it reduces confusion and stray OAuth entries.

### Step 3.3 — Get the Web Client ID

After adding SHA-1, Firebase automatically creates OAuth 2.0 client IDs
in Google Cloud Console.

1. Go to [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials)
2. Select project **kms-connect-1541d**
3. Under **OAuth 2.0 Client IDs**, find the entry labeled
   **"Web client (auto created by Google Service)"**
4. Copy the **Client ID** (format: `268800410479-xxxx.apps.googleusercontent.com`)

This is your `GOOGLE_CLIENT_ID` — used by both mobile (via `google-services.json`)
and the backend (for token verification).

### Step 3.4 — Configure iOS for Google Sign-In

1. Go to [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials)
2. Create a new **OAuth 2.0 Client ID** → type **iOS**
3. Set **Bundle ID** = `id.kmsconnect.app`
4. Copy the iOS client ID
5. Add a **URL scheme** to `mobile/ios/Runner/Info.plist`:

```xml
<!-- Inside the existing CFBundleURLTypes array -->
<dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
        <!-- Reversed iOS client ID from Google Cloud Console -->
        <string>com.googleusercontent.apps.268800410479-XXXXXXXXXXXX</string>
    </array>
</dict>
```

Replace `268800410479-XXXXXXXXXXXX` with your actual reversed iOS client ID.

6. Download the updated `GoogleService-Info.plist` from Firebase Console
   and replace `mobile/ios/Runner/GoogleService-Info.plist`.

### Step 3.5 — Update Backend `.env`

```env
# Google Sign-In: Web Client ID (from Step 3.3)
GOOGLE_CLIENT_ID=268800410479-xxxxxxxxxxxx.apps.googleusercontent.com
```

### Step 3.6 — Mobile: Web client ID (`GOOGLE_WEB_CLIENT_ID`)

**`mobile/pubspec.yaml`** already has `google_sign_in` — no changes needed.

The app reads the **Web** OAuth client ID from `mobile/.env` when set:

```env
# Same string as backend GOOGLE_CLIENT_ID (from Step 3.3).
GOOGLE_WEB_CLIENT_ID=268800410479-xxxxxxxxxxxx.apps.googleusercontent.com
```

`SocialAuthService` passes this as `GoogleSignIn.serverClientId`, which is what
you need for a consistent **ID token** for `POST /api/auth/google/`, especially
when `google-services.json` has `"oauth_client": []` after a Firebase / OAuth
conflict (Step 3.2b).

If `GOOGLE_WEB_CLIENT_ID` is omitted and `google-services.json` is fully
populated, Android can still resolve the Web client from the config file.

---

## 4. Apple Sign-In Setup

### Step 4.1 — Enable Sign in with Apple Capability

In Xcode:

1. Open `mobile/ios/Runner.xcworkspace`
2. Select the **Runner** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Sign in with Apple**

This will update both entitlements files automatically.

Alternatively, manually add to both
`mobile/ios/Runner/Runner.entitlements` and
`mobile/ios/Runner/RunnerDebug.entitlements`:

```xml
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

### Step 4.2 — Configure in Apple Developer Portal

1. Go to [Apple Developer → Certificates, IDs & Profiles](https://developer.apple.com/account/resources/identifiers/list)
2. Select your **App ID** (Bundle ID: `id.kmsconnect.app`)
3. Enable **Sign in with Apple** capability
4. Click **Configure** and set it to **Enable as a primary App ID**
5. Save

### Step 4.3 — Create a Service ID (for Web — optional)

If you also want Apple Sign-In on the web frontend in the future:

1. Register a new **Services ID** (e.g., `id.kmsconnect.app.service`)
2. Enable **Sign in with Apple**
3. Configure the domain and return URL

For mobile-only, the **Bundle ID** itself serves as the audience.

### Step 4.4 — Update Backend `.env`

```env
# Apple Sign-In: The iOS Bundle ID (audience for token verification)
APPLE_CLIENT_ID=id.kmsconnect.app
```

### Step 4.5 — Verify the `sign_in_with_apple` Plugin

**`mobile/pubspec.yaml`** already has `sign_in_with_apple` — no changes needed.

The plugin works natively on iOS 13+. It reads the entitlements automatically.

**Apple Sign-In on Android:**

Apple Sign-In is not natively available on Android. The current code
correctly only shows the Apple button on iOS:

```dart
if (Platform.isIOS) ...[ /* Apple button */ ]
```

---

## 5. Backend Configuration

### Step 5.1 — Install Python Dependencies

Already in `requirements.txt`:
- `google-auth` — for verifying Google ID tokens
- `PyJWT` — for verifying Apple identity tokens (JWT + JWKS)

No new packages needed.

### Step 5.2 — Set Environment Variables

Add to `backend/.env`:

```env
# ── Social Auth ──────────────────────────────────────────────────────────
# Google Sign-In: Web Client ID from Google Cloud Console
GOOGLE_CLIENT_ID=268800410479-xxxxxxxxxxxx.apps.googleusercontent.com

# Apple Sign-In: iOS Bundle ID
APPLE_CLIENT_ID=id.kmsconnect.app
```

### Step 5.3 — Verify Backend Views

All views are already implemented in `backend/account/registration_views.py`:

| Endpoint | View | Purpose |
|----------|------|---------|
| `POST /api/auth/google/` | `GoogleOAuthView` | Verify Google token, login/create user |
| `POST /api/auth/apple/` | `AppleOAuthView` | Verify Apple token, login/create user |
| `POST /api/auth/google-complete/` | `GoogleCompleteRegistrationView` | Complete profile after social signup |
| `POST /api/auth/link-google/` | `LinkGoogleAccountView` | Link Google to existing account |
| `POST /api/auth/link-apple/` | `LinkAppleAccountView` | Link Apple to existing account |

### Step 5.4 — Fix Google OAuth View Bug

There is a variable shadowing bug in `GoogleOAuthView` where the parameter
`id_token` shadows the imported `google.oauth2.id_token` module. This is
already present in the code — verify it works by testing, or apply this fix:

In `backend/account/registration_views.py`, the `GoogleOAuthView.post()` method:

```python
# Current (potential issue):
id_token = request.data.get("id_token", "").strip()
# ...
from google.oauth2 import id_token  # <-- shadows the variable above!
idinfo = id_token.verify_oauth2_token(id_token, ...)
#        ^^^^^^^^ now refers to the module, not the string

# Fix: rename the variable
id_token_raw = request.data.get("id_token", "").strip()
# ...
from google.oauth2 import id_token as google_id_token
idinfo = google_id_token.verify_oauth2_token(id_token_raw, ...)
```

---

## 6. Mobile Configuration Verification

### Step 6.1 — Fix iOS Bundle ID

iOS uses `id.kmsconnect.app` everywhere that matters for Firebase and Sign in with Apple.
It should be `id.kmsconnect.app` to match your Apple Developer account.

**Files to check/update:**
- `mobile/ios/Runner.xcodeproj/project.pbxproj` → `PRODUCT_BUNDLE_IDENTIFIER`
- `mobile/ios/Runner/GoogleService-Info.plist` → `BUNDLE_ID`
- `mobile/ios/Runner/GoogleService-Info.plist` → `BUNDLE_ID` (Dart no longer embeds Firebase keys; see `lib/config/firebase_init.dart`)

The easiest way: open Xcode, change the Bundle Identifier in the
General tab, then re-run `flutterfire configure`.

### Step 6.2 — Verify Android Config

- `mobile/android/app/build.gradle.kts` → `applicationId = "id.kmsconnect.app"` ✅
- `mobile/android/app/google-services.json` → has entry for `id.kmsconnect.app` ✅
- SHA-1 fingerprints → Must be added (Step 3.2)

### Step 6.3 — Run `flutterfire configure` (Recommended)

After making all Firebase/bundle ID changes:

```bash
cd mobile
flutterfire configure --project=kms-connect-1541d
```

This regenerates `google-services.json` and `GoogleService-Info.plist`
(do not commit `lib/firebase_options.dart` if the CLI recreates it — it is gitignored).

---

## 7. Testing Checklist

### Google Sign-In

- [ ] `google-services.json` has `oauth_client` with `client_type: 3`
- [ ] `GOOGLE_CLIENT_ID` set in backend `.env`
- [ ] SHA-1 (debug) registered in Firebase Console
- [ ] Tap "Lanjutkan dengan Google" → Google account picker appears
- [ ] Select account → backend receives valid ID token
- [ ] New user → `needs_registration: true` → redirected to `/register`
- [ ] Existing user → logged in → redirected to `/home`
- [ ] Existing user with placeholder NIK → `needs_registration: true`

### Apple Sign-In (iOS only)

- [ ] "Sign in with Apple" capability added in Xcode
- [ ] `APPLE_CLIENT_ID` set in backend `.env` (= `id.kmsconnect.app`)
- [ ] App ID has Sign in with Apple enabled in Apple Developer Portal
- [ ] Tap "Lanjutkan dengan Apple" → Apple sign-in sheet appears
- [ ] New user → `needs_registration: true` → redirected to `/register`
- [ ] Existing user → logged in → redirected to `/home`

### Email Login

- [ ] Tap "Lanjutkan dengan Email" → email login form appears
- [ ] Back button returns to method selection
- [ ] Login works with valid credentials
- [ ] "Daftar Akun Baru" → goes to registration
- [ ] "Lupa Password?" → goes to forgot password

---

## 8. Authentication Flow Diagrams

### New User via Google/Apple

```
Method Selection → Tap "Google"/"Apple"
    │
    ▼
Native SDK sign-in (account picker / Face ID)
    │
    ▼
Backend: POST /api/auth/google/ or /api/auth/apple/
    │
    ├── User exists + profile complete → { needs_registration: false }
    │   └── Go to /home
    │
    └── User new or profile incomplete → { needs_registration: true }
        └── Go to /register (KTP upload, NIK, etc.)
            │
            ▼
        POST /api/auth/google-complete/ (authenticated)
            │
            ▼
        Go to /home
```

### New User via Email

```
Method Selection → Tap "Lanjutkan dengan Email"
    │
    ▼
Email Login Page → Tap "Daftar Akun Baru"
    │
    ▼
Registration Page (Step 1: credentials, Step 2: KTP/NIK)
    │
    ▼
POST /api/auth/register/
    │
    ▼
Email Verification → Go to /home
```

### Returning User

```
Method Selection → Tap their usual method
    │
    ├── Google/Apple → instant login → /home
    └── Email → enter credentials → /home
```

---

## 9. Troubleshooting

### "Google Sign-In gagal" with no account picker

**Cause:** Missing OAuth client configuration.
**Fix:** Follow Step 3.1–3.2 to add SHA-1 and re-download `google-services.json`.

### "Google ID token tidak valid" from backend

**Cause:** `GOOGLE_CLIENT_ID` in backend doesn't match the Web Client ID.
**Fix:** Copy the exact Web Client ID from Google Cloud Console → Credentials.

### Apple Sign-In button doesn't appear

**Cause:** `Platform.isIOS` check — Apple button only shows on iOS.
This is intentional.

### "Apple identity token tidak valid"

**Cause:** `APPLE_CLIENT_ID` mismatch or wrong bundle ID.
**Fix:** Set `APPLE_CLIENT_ID` to your iOS bundle ID (`id.kmsconnect.app`).

### "Sign in with Apple" not available in simulator

**Cause:** Apple Sign-In requires a real device or a simulator signed in
with an Apple ID that has 2FA enabled.
**Fix:** Test on a physical iOS device.

### PlatformException(sign_in_failed, ...)

**Cause:** `google-services.json` SHA-1 doesn't match the APK signing key.
**Fix:** Make sure both debug and release SHA-1 are registered.

### Firebase: "identical OAuth client already exists"

**Cause:** An Android OAuth client for your package + SHA-1 already exists in
Google Cloud, so Firebase cannot create another when enabling Google sign-in.
**Fix:** See **Step 3.2b**. Short term: set `GOOGLE_WEB_CLIENT_ID` in `mobile/.env`
and `GOOGLE_CLIENT_ID` in the backend from the existing **Web client** in
Google Cloud Console → Credentials.

### Variable shadowing in GoogleOAuthView

**Cause:** The local variable `id_token` and the import `google.oauth2.id_token`
have the same name.
**Fix:** See Step 5.4 above.

---

## Quick Start Summary

1. **Get SHA-1** → `cd mobile/android && ./gradlew signingReport`
2. **Add SHA-1 to Firebase** → Firebase Console → Project Settings → Android app
3. **Download new `google-services.json`** → replace in `mobile/android/app/`
4. **Copy Web Client ID** → Google Cloud Console → Credentials
5. **Backend `.env`:**
   ```
   GOOGLE_CLIENT_ID=<web-client-id>
   APPLE_CLIENT_ID=id.kmsconnect.app
   ```
6. **Add "Sign in with Apple"** capability in Xcode
7. **Enable Sign in with Apple** on the App ID in Apple Developer Portal
8. **Confirm iOS bundle ID** is `id.kmsconnect.app` in Xcode and Firebase Console
9. **Test** Google on Android, Apple on iOS, Email on both
