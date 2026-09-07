# Quick Testing Guide - Flutter Mobile App

## Quick Start

1. **Start Backend:**
```bash
cd backend
python manage.py runserver
```

2. **Point the app at your backend** (defaults to production if omitted):
   - **Android Emulator:** `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`
   - **iOS Simulator:** `flutter run --dart-define=API_BASE_URL=http://localhost:8000`
   - **Physical Device:** `flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_IP:8000`

3. **Run Flutter App:**
```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

## Test Registration

1. Open app → Tap "Daftar"
2. Enter email: `test@example.com`
3. Enter password: `password123`
4. Confirm password: `password123`
5. Upload KTP photo
6. Tap "Daftar"
7. ✅ Should see success message and redirect to home

## Test Login

1. Open app → Enter credentials
2. Tap "Masuk"
3. ✅ Should redirect to home page

## Test Logout

1. From home page → Tap logout icon
2. ✅ Should redirect to login page

## Troubleshooting

**"Connection refused":**
- Check backend is running
- Pass `--dart-define=API_BASE_URL=...` for your platform (see Quick Start #2)

**"Token expired":**
- Logout and login again

**App crashes:**
- Run `flutter pub get`
- Check console for error messages
