# Testing Guide - KMS Connect Mobile App

## Prerequisites

1. **Backend running** on `http://localhost:8000`
2. **Flutter SDK** installed
3. **Android Studio / Xcode** for running mobile app
4. **Postman / curl** for API testing (optional)

---

## 1. Backend Testing

### Start Backend Server

```bash
cd backend
python manage.py runserver
```

The server should start on `http://localhost:8000`

### Test Health Endpoint

```bash
curl http://localhost:8000/health/
```

Expected response: `{"status": "ok"}`

### Test Public Endpoints (No Auth Required)

#### Get Public Jobs
```bash
curl http://localhost:8000/api/jobs/public/
```

#### Get Public News
```bash
curl http://localhost:8000/api/news/public/
```

#### Get Public Document Types
```bash
curl http://localhost:8000/api/document-types/public/
```

---

## 2. Flutter App Testing

### Setup

1. **Install Dependencies**
```bash
cd mobile
flutter pub get
```

2. **Verify Environment**
   - Check `mobile/.env` exists
   - Ensure `API_BASE_URL=http://localhost:8000`

3. **For Android Testing:**
   - Use `10.0.2.2` instead of `localhost` (Android emulator)
   - Update `.env`: `API_BASE_URL=http://10.0.2.2:8000`

4. **For iOS Testing:**
   - Use `localhost` or your machine's IP
   - If using physical device, use your computer's IP: `API_BASE_URL=http://192.168.x.x:8000`

### Run the App

```bash
cd mobile
flutter run
```

---

## 3. Testing Authentication Flow

### Test Registration with KTP Upload

1. **Open the app** - should show Login page
2. **Tap "Daftar"** (Register)
3. **Fill in:**
   - Email: `test@example.com`
   - Password: `password123`
   - Confirm Password: `password123`
4. **Upload KTP Photo:**
   - Tap "Pilih Foto KTP"
   - Select a KTP image from gallery
5. **Tap "Daftar"** (Register button)
6. **Expected:**
   - Success message: "Registrasi berhasil! Silakan lengkapi profil Anda."
   - Redirected to Home page
   - User email displayed on home page

### Test Login

1. **From Login page**, enter:
   - Email: `test@example.com`
   - Password: `password123`
2. **Tap "Masuk"** (Login)
3. **Expected:**
   - Redirected to Home page
   - User email displayed

### Test Logout

1. **From Home page**, tap logout icon (top right)
2. **Expected:**
   - Redirected to Login page
   - Tokens cleared

---

## 4. API Testing with Postman/curl

### Registration Endpoint

```bash
curl -X POST http://localhost:8000/api/auth/register/ \
  -F "email=test@example.com" \
  -F "password=password123" \
  -F "ktp=@/path/to/ktp.jpg"
```

**Expected Response:**
```json
{
  "code": "success",
  "detail": "Registrasi berhasil. KTP sedang diproses dengan OCR.",
  "data": {
    "user": {
      "id": 1,
      "email": "test@example.com",
      "role": "APPLICANT",
      ...
    },
    "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
    "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
  }
}
```

### Login Endpoint

```bash
curl -X POST http://localhost:8000/api/auth/token/ \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

**Expected Response:**
```json
{
  "code": "success",
  "detail": "Login berhasil.",
  "data": {
    "user": {...},
    "access": "...",
    "refresh": "..."
  }
}
```

### Get Current User (Requires Auth)

```bash
curl -X GET http://localhost:8000/api/me/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Get My Profile (Requires Auth)

```bash
curl -X GET http://localhost:8000/api/applicants/me/profile/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

## 5. Common Issues & Solutions

### Issue: "Connection refused" or "Network error"

**Solution:**
- **Android Emulator:** Change `API_BASE_URL` to `http://10.0.2.2:8000`
- **iOS Simulator:** Use `http://localhost:8000`
- **Physical Device:** Use your computer's IP address: `http://192.168.x.x:8000`
- Ensure backend is running: `python manage.py runserver`

### Issue: "CORS error" (if testing from browser)

**Solution:**
- CORS is configured in Django settings
- For mobile app, CORS shouldn't be an issue
- If testing from web browser, ensure `CORS_ALLOWED_ORIGINS` includes your frontend URL

### Issue: "Token expired" or "Unauthorized"

**Solution:**
- Logout and login again
- Check if tokens are being stored correctly
- Verify `flutter_secure_storage` is working

### Issue: "File upload failed"

**Solution:**
- Ensure KTP image is valid (JPG/PNG)
- Check file size (max 5MB)
- Verify `image_picker` permissions are granted

### Issue: Flutter app crashes on startup

**Solution:**
- Check `.env` file exists in `mobile/` directory
- Run `flutter pub get` again
- Check for missing dependencies
- Verify Firebase is initialized (if using Firebase features)

---

## 6. Testing Checklist

### Authentication
- [ ] Registration with email + password + KTP upload works
- [ ] Login with email + password works
- [ ] Logout clears tokens and redirects to login
- [ ] Protected routes redirect to login when not authenticated
- [ ] Authenticated routes are accessible after login

### API Integration
- [ ] Registration API call succeeds
- [ ] Login API call succeeds
- [ ] Tokens are stored securely
- [ ] API errors are displayed to user
- [ ] Loading states show during API calls

### UI/UX
- [ ] Forms validate input correctly
- [ ] Error messages display properly
- [ ] Loading indicators show during operations
- [ ] Navigation works correctly
- [ ] Theme colors match logo

---

## 7. Debugging Tips

### Enable API Logging

The `LoggingInterceptor` in `mobile/lib/core/api/interceptors.dart` logs all requests/responses in debug mode.

### Check Secure Storage

```dart
// In Flutter app, check if tokens are stored:
final storage = FlutterSecureStorage();
final token = await storage.read(key: 'access_token');
print('Access Token: $token');
```

### Backend Logs

Check Django console output for:
- Request logs
- Error messages
- Database queries
- Celery task execution (for OCR)

### Flutter Debug Console

Check Flutter console for:
- API request/response logs
- Error messages
- State changes

---

## 8. Next Steps for Testing

Once basic auth works, test:
1. **Profile Management** - View/edit profile
2. **Document Upload** - Upload documents, view OCR results
3. **Job Browsing** - List jobs, view details, apply
4. **News** - View news list and details
5. **Notifications** - Push notifications (when implemented)

---

## 9. Performance Testing

### Test with Multiple Users

1. Register multiple test accounts
2. Test concurrent API calls
3. Monitor backend performance
4. Check database query optimization

### Test File Upload Performance

1. Test with different image sizes
2. Monitor upload progress
3. Check OCR processing time
4. Verify image optimization

---

## Need Help?

- Check backend logs: `python manage.py runserver` console
- Check Flutter logs: `flutter run` console
- Review API responses in network tab (if using browser dev tools)
- Check database: `python manage.py dbshell`
