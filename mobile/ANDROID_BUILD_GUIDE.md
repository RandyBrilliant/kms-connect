# Android APK Build Guide

Panduan lengkap untuk membuat APK Android dari aplikasi KMS Connect untuk keperluan pengujian klien.

---

## Daftar Isi

1. [Prasyarat](#1-prasyarat)
2. [Konfigurasi Sebelum Build](#2-konfigurasi-sebelum-build)
3. [Option A — Debug-Signed APK (Cepat, untuk testing awal)](#3-option-a--debug-signed-apk-cepat-untuk-testing-awal)
4. [Option B — Release APK dengan Keystore Sendiri (Direkomendasikan)](#4-option-b--release-apk-dengan-keystore-sendiri-direkomendasikan)
   - [4.4 Pakai keystore yang sama di Windows dan MacBook](#44-pakai-keystore-yang-sama-di-windows-dan-macbook)
5. [Menjalankan Build](#5-menjalankan-build)
6. [Distribusi APK ke Klien](#6-distribusi-apk-ke-klien)
7. [Instruksi untuk Klien](#7-instruksi-untuk-klien)
8. [Troubleshooting](#8-troubleshooting)
9. [Deploy ke Google Play Store](#9-deploy-ke-google-play-store)
   - [9.1 Prasyarat Play Store](#91-prasyarat-play-store)
   - [9.2 Build Android App Bundle (AAB)](#92-build-android-app-bundle-aab--format-wajib-play-store)
   - [9.3 Tambahkan SHA-1 Release ke Firebase](#93-tambahkan-sha-1-release-ke-firebase)
   - [9.4 Persiapan Aset Play Store](#94-persiapan-aset-play-store)
   - [9.5 Membuat Aplikasi di Play Console](#95-membuat-aplikasi-di-play-console)
   - [9.6 Mengisi Store Listing](#96-mengisi-store-listing)
   - [9.7 Melengkapi Informasi Wajib](#97-melengkapi-informasi-wajib)
   - [9.8 Upload AAB ke Internal Testing](#98-upload-aab-ke-internal-testing-direkomendasikan-sebagai-langkah-pertama)
   - [9.9 Promosi ke Production](#99-promosi-ke-production)
   - [9.10 App Signing by Google Play](#910-app-signing-by-google-play-opsional-tapi-direkomendasikan)
   - [9.11 Update Aplikasi](#911-update-aplikasi-rilis-selanjutnya)
   - [9.12 Checklist Sebelum Submit](#912-checklist-sebelum-submit-ke-play-store)

---

## 1. Prasyarat

Pastikan semua tools berikut sudah terinstal dan berjalan:

| Tool | Versi Minimum | Cek |
|---|---|---|
| Flutter SDK | 3.10.x+ | `flutter --version` |
| Android SDK | API 33+ | `flutter doctor` |
| Java (JDK) | 17+ | `java -version` |

Jalankan `flutter doctor` dan pastikan tidak ada masalah pada bagian Android:

```powershell
flutter doctor -v
```

---

## 2. Konfigurasi Sebelum Build

### 2.1 Pastikan `.env` mengarah ke backend yang benar

File: `mobile/.env`

```dotenv
# Untuk build client testing, pastikan URL ini adalah URL backend yang bisa diakses klien
API_BASE_URL=https://data.kms-connect.com

# Google Sign-In (isi jika sudah punya client ID dari Google Cloud Console)
GOOGLE_CLIENT_ID_ANDROID=your-android-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_ID_IOS=your-ios-client-id.apps.googleusercontent.com
```

> ⚠️ Jangan gunakan `http://localhost:8000` untuk APK yang dikirim ke klien — klien tidak memiliki server tersebut di perangkatnya.

### 2.2 Perbarui versi aplikasi

File: `mobile/pubspec.yaml`

```yaml
version: 1.0.0+1
#         ^^^^^  ^
#     versionName  versionCode (integer, naik tiap build)
```

Setiap kali mengirim build baru ke klien, naikkan `versionCode` (angka setelah `+`):

```yaml
version: 1.0.1+2   # build kedua
version: 1.0.2+3   # build ketiga
```

### 2.3 Pastikan `google-services.json` sudah ada

File `android/app/google-services.json` harus sudah ada dan sesuai dengan Firebase project yang aktif. Jika belum:

1. Buka [Firebase Console](https://console.firebase.google.com)
2. Pilih project KMS Connect
3. Settings → Tambah aplikasi Android → `id.kmsconnect.app`
4. Download `google-services.json` dan letakkan di `android/app/`

### 2.4 Install dependencies

```powershell
cd C:\Users\randy\Documents\programming\kms-connect\mobile
flutter pub get
```

---

## 3. Option A — Debug-Signed APK (Cepat, untuk testing awal)

Cara paling cepat. APK menggunakan debug keystore bawaan Flutter dan sudah dikonfigurasi di `android/app/build.gradle.kts`. Tidak perlu setup tambahan.

**Kekurangan:** Tidak cocok untuk distribusi publik / Play Store. Cukup untuk testing internal klien.

Langsung lanjut ke [bagian 5 — Menjalankan Build](#5-menjalankan-build).

---

## 4. Option B — Release APK dengan Keystore Sendiri (Direkomendasikan)

Gunakan ini jika ingin distribusi yang lebih profesional atau jika rencana ke Play Store.

### 4.1 Buat Keystore (satu kali saja)

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v `
  -keystore C:\Users\randy\kmsconnect-release.jks `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias kmsconnect
```

> ℹ️ `keytool` tidak ada di PATH secara default. Gunakan path lengkap ke JRE bawaan Android Studio di atas.

Isi pertanyaan yang muncul:
- `What is your first and last name?` → nama Anda / nama perusahaan
- `What is the name of your organizational unit?` → boleh kosong
- `What is the name of your organization?` → KMS Connect
- `What is the name of your City or Locality?` → kota Anda
- `What is the name of your State or Province?` → provinsi Anda
- `What is the two-letter country code?` → ID

> 🔑 **SIMPAN file `.jks` dan passwordnya di tempat aman.** Kehilangan keystore berarti tidak bisa update aplikasi dengan ID yang sama (`id.kmsconnect.app`).

### 4.2 Buat file `key.properties`

Buat file `mobile/android/key.properties` (file ini sudah di `.gitignore` Flutter):

```properties
storePassword=PASSWORD_KEYSTORE_ANDA
keyPassword=PASSWORD_KEY_ANDA
keyAlias=kmsconnect
storeFile=C:\\Users\\randy\\kmsconnect-release.jks
```

> Gunakan double backslash `\\` untuk path di Windows.

### 4.3 Update `android/app/build.gradle.kts`

Ganti seluruh isi file dengan yang berikut:

```kotlin
plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = java.util.Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

android {
    namespace = "com.example.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "id.kmsconnect.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            keyPassword = keyProperties["keyPassword"] as String
            storeFile = file(keyProperties["storeFile"] as String)
            storePassword = keyProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
```

### 4.4 Pakai keystore yang sama di Windows dan MacBook

Tujuan section ini: build dari Windows dan Mac tetap memakai **keystore yang sama** agar update aplikasi tetap valid (signature tidak berubah).

#### Langkah 1 - Pastikan data keystore yang wajib disimpan

Catat dan simpan data berikut dari mesin Windows:

- File `.jks` (contoh: `kmsconnect-release.jks`)
- `keyAlias`
- `storePassword`
- `keyPassword`

> Jika salah satu berbeda di Mac, proses signing release akan gagal atau menghasilkan signature berbeda.

#### Langkah 2 - Transfer file `.jks` ke Mac secara aman

Metode yang aman:

- AirDrop
- USB terenkripsi
- Password manager yang mendukung secure file attachment

Hindari mengirim file keystore lewat chat biasa tanpa enkripsi.

#### Langkah 3 - Simpan keystore di path khusus di Mac

Di Mac:

```bash
mkdir -p ~/keystores
```

Lalu letakkan file keystore di:

`/Users/<username>/keystores/kmsconnect-release.jks`

#### Langkah 4 - Buat `android/key.properties` khusus Mac

File: `mobile/android/key.properties`

```properties
storePassword=PASSWORD_KEYSTORE_ANDA
keyPassword=PASSWORD_KEY_ANDA
keyAlias=kmsconnect
storeFile=/Users/<username>/keystores/kmsconnect-release.jks
```

Catatan penting:
- Di macOS gunakan slash biasa `/`, bukan `\\`.
- Nilai password dan alias harus sama persis dengan yang dipakai di Windows.

#### Langkah 5 - Verifikasi fingerprint SHA-1 di kedua mesin

Di Windows (PowerShell):

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v `
  -keystore C:\Users\randy\kmsconnect-release.jks `
  -alias kmsconnect `
  -storepass PASSWORD_KEYSTORE_ANDA
```

Di Mac (Terminal):

```bash
keytool -list -v \
  -keystore /Users/<username>/keystores/kmsconnect-release.jks \
  -alias kmsconnect \
  -storepass PASSWORD_KEYSTORE_ANDA
```

Bandingkan nilai `SHA1` dari output keduanya. Harus identik.

#### Langkah 6 - Build release di Mac

Dari folder `mobile/`:

```bash
flutter clean
flutter pub get
flutter build apk --release --split-per-abi
```

Jika build sukses, berarti Mac sudah menggunakan keystore yang sama.

#### Checklist cepat (Windows + Mac sinkron)

- [ ] File `.jks` yang sama dipakai di dua mesin
- [ ] `keyAlias`, `storePassword`, `keyPassword` sama persis
- [ ] `SHA1` hasil `keytool -list -v` identik
- [ ] `android/key.properties` sudah pakai path yang sesuai OS

---

## 5. Menjalankan Build

Dari direktori `mobile/`:

```powershell
cd C:\Users\randy\Documents\programming\kms-connect\mobile
```

### Build APK fat (satu file, semua arsitektur):

```powershell
flutter build apk --release
```

Output: `build\app\outputs\flutter-apk\app-release.apk`

### Build APK split per arsitektur (ukuran lebih kecil, DIREKOMENDASIKAN):

```powershell
flutter build apk --release --split-per-abi
```

Output:
```
build\app\outputs\flutter-apk\app-arm64-v8a-release.apk    ← untuk HP modern (2016+) ✅
build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk  ← untuk HP lama 32-bit
build\app\outputs\flutter-apk\app-x86_64-release.apk       ← untuk emulator
```

**Kirim `app-arm64-v8a-release.apk` ke klien** — file ini kompatibel dengan hampir semua smartphone Android modern.

### Cek ukuran file yang dihasilkan:

```powershell
ls build\app\outputs\flutter-apk\
```

---

## 6. Distribusi APK ke Klien

### Opsi 1 — Google Drive / WhatsApp (paling sederhana)

1. Upload `app-arm64-v8a-release.apk` ke Google Drive
2. Bagikan link ke klien
3. Klien download dan install

### Opsi 2 — Firebase App Distribution (direkomendasikan untuk testing berulang)

Cocok jika ada banyak tester atau ingin tracking siapa yang sudah install.

#### Setup (satu kali):

```powershell
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login
```

#### Upload setiap build:

```powershell
firebase appdistribution:distribute build\app\outputs\flutter-apk\app-arm64-v8a-release.apk `
  --app "YOUR_FIREBASE_ANDROID_APP_ID" `
  --groups "testers" `
  --release-notes "v1.0.0 - Build untuk testing klien"
```

Firebase Android App ID ada di: Firebase Console → Project Settings → Your apps → Android app → App ID  
Format: `1:1234567890:android:abcdef1234567890`

Tester akan menerima email undangan dan bisa install langsung tanpa perlu enable "Unknown Sources" secara manual.

### Opsi 3 — Diawi.com (cepat, tanpa akun)

1. Buka [diawi.com](https://www.diawi.com)
2. Drag & drop file APK
3. Dapatkan link atau QR code
4. Bagikan ke klien

---

## 7. Instruksi untuk Klien

Sampaikan hal berikut kepada klien:

### Cara Install APK

**Android 8.0 ke atas:**

1. Download file APK yang dikirimkan
2. Buka file APK dari notifikasi atau file manager
3. Jika muncul peringatan "Install unknown apps":
   - Tap **Settings**
   - Aktifkan **Allow from this source**
   - Kembali dan tap **Install**
4. Tunggu instalasi selesai → tap **Open**

**Android 7.0 ke bawah:**

1. Buka **Settings** → **Security**
2. Aktifkan **Unknown sources**
3. Download dan install APK

### Troubleshooting Instalasi Klien

| Pesan Error | Solusi |
|---|---|
| "App not installed" | Uninstall versi lama dulu, lalu install ulang |
| "Parse error" | File APK rusak saat download, minta kirim ulang |
| "Install blocked" | Aktifkan "Install unknown apps" (lihat di atas) |
| Aplikasi crash saat buka | Pastikan koneksi internet aktif, coba restart HP |

---

## 8. Troubleshooting Build

### `flutter build apk` gagal dengan error Gradle

```powershell
# Bersihkan cache Gradle dan Flutter
flutter clean
flutter pub get
cd android
.\gradlew clean
cd ..
flutter build apk --release
```

### Error `keystore file not found`

- Pastikan path di `key.properties` menggunakan double backslash `\\`
- Pastikan file `.jks` ada di path yang sesuai

### Error `google-services.json` missing atau salah

- Download ulang dari Firebase Console
- Pastikan `applicationId` di `build.gradle.kts` sama dengan yang didaftarkan di Firebase (`id.kmsconnect.app`)

### APK tidak bisa login Google

- Pastikan SHA-1 fingerprint debug key sudah ditambahkan di Firebase Console
- Jalankan untuk mendapatkan SHA-1:

```powershell
# SHA-1 untuk debug keystore
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v `
  -keystore "$env:USERPROFILE\.android\debug.keystore" `
  -alias androiddebugkey `
  -storepass android -keypass android
```

Copy SHA-1 → Firebase Console → Project Settings → Android app → Add fingerprint.

---

## Ringkasan Quick Build

```powershell
# 1. Pastikan .env sudah benar
# 2. Update versi di pubspec.yaml jika perlu
# 3. Build
cd C:\Users\randy\Documents\programming\kms-connect\mobile
flutter clean && flutter pub get
flutter build apk --release --split-per-abi

# 4. APK siap di:
# build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

---

## 9. Deploy ke Google Play Store

Bagian ini memandu proses lengkap dari persiapan hingga aplikasi live di Play Store.

---

### 9.1 Prasyarat Play Store

| Kebutuhan | Keterangan |
|---|---|
| Google Play Developer Account | Biaya pendaftaran satu kali **USD 25** |
| Keystore Release (`.jks`) | Sudah dibuat di [section 4.1](#41-buat-keystore-satu-kali-saja) |
| App Icon 512×512 px | PNG, tanpa transparansi |
| Screenshot perangkat | Min. 2 screenshot per form factor (phone wajib) |
| Koneksi ke backend production | `API_BASE_URL` harus URL production, bukan localhost |

Daftar Google Play Developer Account di: https://play.google.com/console/signup

---

### 9.2 Build Android App Bundle (AAB) — Format Wajib Play Store

Play Store **tidak menerima APK biasa** untuk aplikasi baru sejak Agustus 2021. Format yang diperlukan adalah **AAB (Android App Bundle)**.

Pastikan keystore release sudah dikonfigurasi ([section 4.2](#42-buat-file-keyproperties) & [4.3](#43-update-androidappbuildgradlekts)), lalu:

```powershell
cd C:\Users\randy\Documents\programming\kms-connect\mobile

# Bersihkan build sebelumnya
flutter clean
flutter pub get

# Build AAB release
flutter build appbundle --release
```

Output: `build\app\outputs\bundle\release\app-release.aab`

> ✅ File `.aab` inilah yang diupload ke Play Console, bukan `.apk`.

---

### 9.3 Tambahkan SHA-1 Release ke Firebase

Google Sign-In di production memerlukan SHA-1 dari **release keystore** (bukan debug keystore).

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v `
  -keystore C:\Users\randy\kmsconnect-release.jks `
  -alias kmsconnect `
  -storepass PASSWORD_KEYSTORE_ANDA
```

Copy nilai **SHA-1** dari output, lalu:

1. Buka [Firebase Console](https://console.firebase.google.com) → Project KMS Connect
2. **Project Settings** → tab **Your apps** → pilih Android app (`id.kmsconnect.app`)
3. Klik **Add fingerprint** → paste SHA-1 release → Save
4. Download ulang `google-services.json` → ganti file di `android/app/google-services.json`
5. Rebuild AAB

---

### 9.4 Persiapan Aset Play Store

Siapkan aset berikut sebelum membuat listing:

#### App Icon
- Ukuran: **512 × 512 px**, format PNG, background tidak transparan
- Bisa export dari Figma atau tools desain lainnya

#### Screenshots (wajib untuk Phone)
- Ukuran: min. 320 px, maks. 3840 px per sisi; rasio 16:9 atau 9:16
- Minimal **2 screenshot**, maksimal 8 per perangkat
- Kategori perangkat: **Phone** (wajib), Tablet, Chromebook (opsional)

#### Feature Graphic (opsional, namun direkomendasikan)
- Ukuran: **1024 × 500 px**, format PNG atau JPG

#### Cara cepat ambil screenshot dari emulator:
```powershell
# Jalankan app di emulator lalu screenshot via adb
adb exec-out screencap -p > screenshot1.png
```

---

### 9.5 Membuat Aplikasi di Play Console

1. Buka [Google Play Console](https://play.google.com/console)
2. Klik **Create app**
3. Isi form:
   - **App name**: KMS Connect
   - **Default language**: Indonesian
   - **App or game**: App
   - **Free or paid**: sesuaikan
4. Centang semua pernyataan Developer Program Policy → **Create app**

---

### 9.6 Mengisi Store Listing

Navigasi ke: **Play Console → App → Store presence → Main store listing**

| Field | Isi |
|---|---|
| App name | KMS Connect |
| Short description | Maks. 80 karakter — ringkasan singkat aplikasi |
| Full description | Maks. 4000 karakter — deskripsi lengkap fitur |
| App icon | Upload PNG 512×512 |
| Feature graphic | Upload PNG 1024×500 (jika ada) |
| Phone screenshots | Upload min. 2 screenshot |

Klik **Save**.

---

### 9.7 Melengkapi Informasi Wajib

Sebelum bisa publish, Play Console meminta beberapa informasi tambahan:

#### a) App content → Privacy Policy
- URL ke halaman Privacy Policy wajib diisi
- Halaman sudah tersedia di frontend: `https://kms-connect.com/privacy`
- Masukkan URL tersebut di kolom Privacy Policy URL di Play Console

#### b) App content → Target audience
- Tentukan target usia pengguna
- Jika **bukan** untuk anak-anak, pilih **13 and over** atau **18 and over**

#### c) App content → Content rating
1. Play Console → **App content** → **Content ratings**
2. Klik **Start questionnaire**
3. Masukkan email kontak → pilih kategori app → jawab kuesioner
4. Submit → rating akan otomatis diberikan (biasanya **Everyone** atau **Teen**)

#### d) App access
- Jika app memerlukan login, beri tahu Google cara mengakses:
  - **App access** → **All or most functionality is restricted** → tambahkan instruksi login dan akun demo jika ada

---

### 9.8 Upload AAB ke Internal Testing (Direkomendasikan sebagai Langkah Pertama)

Mulai dari **Internal Testing** sebelum langsung ke Production — lebih cepat diproses (biasanya menit, bukan hari).

1. Play Console → **Testing** → **Internal testing** → **Create new release**
2. Klik **Upload** → pilih `build\app\outputs\bundle\release\app-release.aab`
3. Isi **Release name** (contoh: `1.0.0`) dan **Release notes**:
   ```
   - Rilis perdana KMS Connect
   - Fitur: login, dashboard, notifikasi push
   ```
4. Klik **Save** → **Review release** → **Start rollout to Internal testing**

#### Tambahkan tester internal:
- **Internal testing** → tab **Testers** → **Create email list**
- Tambahkan email tester (akun Google)
- Bagikan link opt-in ke tester

---

### 9.9 Promosi ke Production

Setelah testing di internal/closed testing selesai dan tidak ada bug kritis:

1. Play Console → **Production** → **Create new release**
2. Pilih AAB yang sudah pernah diupload (dari internal testing) atau upload ulang
3. Isi release notes (ini yang dilihat pengguna di Play Store)
4. **Review release** → **Start rollout to production**

> ⏳ Review Google memakan waktu **beberapa jam hingga 3 hari kerja** untuk rilis pertama. Setelah approved, app akan live di Play Store.

---

### 9.10 App Signing by Google Play (Opsional tapi Direkomendasikan)

Google Play menawarkan fitur **Play App Signing** di mana Google menyimpan signing key utama dan menandatangani ulang APK yang dikirimkan ke pengguna.

**Keuntungan:**
- Jika keystore lokal hilang, app masih bisa diupdate
- Ukuran APK yang diterima pengguna bisa lebih kecil

**Cara mengaktifkan:**
- Saat pertama kali membuat release, Play Console akan menawarkan untuk ikut di App Signing
- Pilih **Use Google Play's app signing key** → ikuti wizard

> 🔑 Jika mengaktifkan Play App Signing, SHA-1 yang perlu didaftarkan di Firebase adalah **SHA-1 dari Google Play App Signing certificate**, bukan dari keystore lokal.  
> Dapatkan dari: Play Console → **Setup** → **App signing** → salin SHA-1 di bagian *App signing key certificate*.

---

### 9.11 Update Aplikasi (Rilis Selanjutnya)

Setiap kali merilis update:

1. **Naikkan versionCode** di `mobile/pubspec.yaml` (wajib, harus lebih besar dari versi sebelumnya):
   ```yaml
   version: 1.0.1+2   # versionName+versionCode
   ```

2. Build AAB baru:
   ```powershell
   flutter clean
   flutter pub get
   flutter build appbundle --release
   ```

3. Upload ke Play Console → buat release baru di track yang diinginkan

---

### 9.12 Checklist Sebelum Submit ke Play Store

```
[ ] versionCode di pubspec.yaml sudah dinaikkan
[ ] API_BASE_URL di .env mengarah ke backend production
[ ] google-services.json sudah berisi SHA-1 dari release keystore
[ ] App icon 512×512 sudah disiapkan
[ ] Minimal 2 screenshot phone sudah disiapkan
[ ] Privacy Policy URL sudah tersedia
[ ] Content rating questionnaire sudah diisi
[ ] AAB sudah berhasil di-build (flutter build appbundle --release)
[ ] Tested di internal testing track sebelum ke production
```

---

### Ringkasan Quick Deploy ke Play Store

```powershell
# 1. Naikkan versionCode di pubspec.yaml (misal: 1.0.0+1 → 1.0.1+2)
# 2. Pastikan .env → API_BASE_URL ke production
# 3. Build AAB
cd C:\Users\randy\Documents\programming\kms-connect\mobile
flutter clean ; flutter pub get
flutter build appbundle --release

# 4. AAB siap di:
# build\app\outputs\bundle\release\app-release.aab

# 5. Upload ke Google Play Console → buat release baru
```
