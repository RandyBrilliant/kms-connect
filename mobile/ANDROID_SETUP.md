# Running Flutter App on Android Device

## Prerequisites

1. **Enable Developer Options on your Android device:**
   - Go to **Settings** → **About Phone**
   - Find **Build Number** and tap it **7 times**
   - You'll see a message saying "You are now a developer!"

2. **Enable USB Debugging:**
   - Go to **Settings** → **Developer Options** (or **System** → **Developer Options**)
   - Enable **USB Debugging**
   - Enable **Stay Awake** (optional, keeps screen on while charging)

3. **For Android 11+ (Wireless Debugging - Optional):**
   - In Developer Options, enable **Wireless Debugging**
   - Tap **Wireless Debugging** → **Pair device with pairing code**
   - Note the IP address and port (e.g., `192.168.1.100:12345`)

## Connection Methods

### Method 1: USB Connection (Recommended)

1. **Connect your Android device to your computer via USB cable**
2. **On your device**, you'll see a prompt: "Allow USB debugging?"
   - Check **"Always allow from this computer"**
   - Tap **OK**

3. **Verify connection:**
   ```bash
   flutter devices
   ```
   You should see your device listed (e.g., `sdk gphone64 arm64` or your device model)

4. **Run the app:**
   ```bash
   cd mobile
   flutter run
   ```
   Or specify the device explicitly:
   ```bash
   flutter run -d <device-id>
   ```

### Method 2: Wireless Debugging (Android 11+)

1. **Connect via USB first** to pair:
   ```bash
   adb pair <IP_ADDRESS>:<PORT>
   ```
   Enter the pairing code when prompted

2. **Connect wirelessly:**
   ```bash
   adb connect <IP_ADDRESS>:<PORT>
   ```

3. **Unplug USB cable** - device should still be connected

4. **Verify connection:**
   ```bash
   flutter devices
   ```

5. **Run the app:**
   ```bash
   cd mobile
   flutter run
   ```

## Troubleshooting

### Device Not Detected

1. **Check USB drivers:**
   - Windows: Install [Google USB Driver](https://developer.android.com/studio/run/win-usb)
   - Or install device manufacturer's USB drivers (Samsung, Xiaomi, etc.)

2. **Verify ADB is working:**
   ```bash
   adb devices
   ```
   Should show your device with "device" status (not "unauthorized")

3. **If device shows "unauthorized":**
   - Unplug and replug USB cable
   - Check your device screen for "Allow USB debugging" prompt
   - Accept it

4. **Restart ADB server:**
   ```bash
   adb kill-server
   adb start-server
   adb devices
   ```

### Build Errors

1. **Check Android SDK:**
   ```bash
   flutter doctor -v
   ```
   Ensure Android toolchain is properly configured

2. **Clean and rebuild:**
   ```bash
   cd mobile
   flutter clean
   flutter pub get
   flutter run
   ```

### App Installation Issues

1. **Enable "Install via USB"** in Developer Options
2. **Check device storage** - ensure enough space
3. **Uninstall previous version** if exists:
   ```bash
   adb uninstall com.example.mobile
   ```

## Quick Commands

```bash
# List all connected devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Run in release mode (optimized)
flutter run --release

# Build APK for manual installation
flutter build apk

# Build app bundle for Play Store
flutter build appbundle
```

## Notes

- **First run** may take longer as it builds and installs the app
- Keep your device **unlocked** during installation
- Ensure device has **sufficient battery** or is charging
- For **production builds**, use `flutter build apk --release`
