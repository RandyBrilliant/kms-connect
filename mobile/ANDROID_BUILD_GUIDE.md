# Android APK Build Guide

Panduan lengkap untuk membuat APK Android dari aplikasi KMS Connect untuk keperluan pengujian klien.

---

## Daftar Isi

1. [Prasyarat](#1-prasyarat)
2. [Konfigurasi Sebelum Build](#2-konfigurasi-sebelum-build)
3. [Option A — Debug-Signed APK (Cepat, untuk testing awal)](#3-option-a--debug-signed-apk-cepat-untuk-testing-awal)
4. [Option B — Release APK dengan Keystore Sendiri (Direkomendasikan)](#4-option-b--release-apk-dengan-keystore-sendiri-direkomendasikan)
5. [Menjalankan Build](#5-menjalankan-build)
6. [Distribusi APK ke Klien](#6-distribusi-apk-ke-klien)
7. [Instruksi untuk Klien](#7-instruksi-untuk-klien)
8. [Troubleshooting](#8-troubleshooting)

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
keytool -genkey -v `
  -keystore C:\Users\randy\kmsconnect-release.jks `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias kmsconnect
```

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
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
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
