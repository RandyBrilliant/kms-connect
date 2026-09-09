# Mobile store release runbook

Automated uploads go to **Play internal testing** and **TestFlight** only.
Production store tracks and the backend VPS stay manual / separate.

Related files:

- Workflow: [`.github/workflows/mobile-release.yml`](../.github/workflows/mobile-release.yml)
- PR checks only: [`.github/workflows/mobile-ci.yml`](../.github/workflows/mobile-ci.yml)
- Android Fastlane: [`android/fastlane/`](android/fastlane/)
- iOS Fastlane: [`ios/fastlane/`](ios/fastlane/)
- Manual Play Console steps: [`ANDROID_BUILD_GUIDE.md`](ANDROID_BUILD_GUIDE.md) §9

## What this does / does not do

| Does | Does not |
|---|---|
| Build signed AAB + IPA with production API default | Deploy backend / touch the database |
| Upload AAB to Play **internal** track | Upload to Play **production** |
| Upload IPA to TestFlight (**internal** testers) | Submit for App Store review |
| Skip Play listing metadata/images/screenshots | Rewrite store listings |
| Reuse existing keystore + Apple Distribution cert | Create a new signing identity |

In-app force update only sees **public** store versions, so internal / TestFlight builds will not push production users.

## Prerequisites (one-time)

### GitHub Actions secrets

Add these under the repo **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64 of the existing `kmsconnect-release.jks` (`base64 -i kmsconnect-release.jks \| pbcopy`) |
| `ANDROID_KEYSTORE_PASSWORD` | Same as local `key.properties` `storePassword` |
| `ANDROID_KEY_PASSWORD` | Same as local `key.properties` `keyPassword` |
| `ANDROID_KEY_ALIAS` | Usually `kmsconnect` |
| `PLAY_STORE_JSON` | Full Play Console service-account JSON |
| `GOOGLE_SERVICES_JSON` | Full contents of production `android/app/google-services.json` |
| `GOOGLE_SERVICE_INFO_PLIST` | Full contents of production `ios/Runner/GoogleService-Info.plist` |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect Issuer ID |
| `APP_STORE_CONNECT_KEY_P8` | Contents of the `.p8` private key |
| `IOS_DIST_CERT_P12` | Base64 of the existing iOS Distribution `.p12` |
| `IOS_DIST_CERT_PASSWORD` | Password for that `.p12` |
| `IOS_PROVISIONING_PROFILE` | Base64 of the **KMS Connect App Store** `.mobileprovision` |

### Play Console

1. Enable Google Play Android Developer API for a Google Cloud project.
2. Create a service account, download its JSON → `PLAY_STORE_JSON`.
3. In Play Console → Users and permissions, invite that service account with permission to release to **testing tracks** (not production admin).
4. Confirm Play App Signing is enabled and keep using the **existing** upload keystore.

### App Store Connect

1. Create an App Store Connect API key (Developer / App Manager) → Key ID, Issuer ID, `.p8`.
2. Export the current **Apple Distribution** certificate as `.p12`.
3. Download the **KMS Connect App Store** provisioning profile for `id.kmsconnect.app` (team `RLQHLFX576`).
4. Base64-encode the `.p12` and `.mobileprovision` for the secrets above.

## Release steps

1. Bump version in [`pubspec.yaml`](pubspec.yaml). `versionCode` (after `+`) **must** increase every Play upload:

   ```yaml
   version: 1.0.24+24
   ```

2. Commit on your release branch / `main` as usual. Do **not** rely on push-to-`main` for mobile upload (that only deploys the backend).

3. Prefer a dry run first:

   - GitHub → **Actions** → **Mobile Store Release** → **Run workflow**
   - Choose `android` the first time, then `ios`, then `both`
   - Use a `versionCode` that is **not** already on Play

4. After the first successful manual run, tag releases:

   ```bash
   git tag mobile-v1.0.24
   git push origin mobile-v1.0.24
   ```

   Tag pattern must match `mobile-v*`.

5. Verify testers:

   - **Android:** Play Console → Testing → Internal testing → opt-in link → install and smoke-test login, jobs, notifications.
   - **iOS:** App Store Connect → TestFlight → Internal testing → install via TestFlight and smoke-test the same flows.

6. Promote to production **manually** only after smoke tests pass:

   - Play: promote the internal release to Production (see ANDROID_BUILD_GUIDE §9.9).
   - iOS: in App Store Connect, submit the TestFlight build for App Store review (not done by CI).

## Local Fastlane (optional)

From a machine that already has Ruby, the keystore, and Play credentials:

```bash
cd mobile
flutter build appbundle --release
cd android
bundle install
PLAY_STORE_JSON_PATH=/path/to/play-store-key.json \
  AAB_PATH=../build/app/outputs/bundle/release/app-release.aab \
  bundle exec fastlane internal
```

iOS:

```bash
cd mobile
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
cd ios
bundle install
ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_PATH=/path/to/AuthKey.p8 \
  IPA_PATH=../build/ios/ipa/mobile.ipa \
  bundle exec fastlane testflight_internal
```

## Safety checklist

- [ ] Backend workflow path filters still exclude `mobile/**`
- [ ] Release workflow is tag / `workflow_dispatch` only (no push to `main`)
- [ ] Fastlane Play lane keeps `track: "internal"` and skips metadata/images/screenshots
- [ ] Fastlane iOS lane keeps `distribute_external: false` and does not submit for review
- [ ] No `--dart-define=API_BASE_URL` in CI (production default in `lib/config/env.dart`)
- [ ] Same package / bundle id: `id.kmsconnect.app`
- [ ] Same Android upload keystore as previous releases
- [ ] Same Apple team `RLQHLFX576` and profile **KMS Connect App Store**
