# Referral Code System Implementation Guide

## Overview

This system ensures every applicant (pelamar) must input a referral code from staff or admin during registration. This helps track which staff/admin recruited each applicant and provides accountability.

## How It Works

### 1. Referral Code Format

- **Staff codes**: `S-XXXXXX` (e.g., `S-ABC123`)
- **Admin codes**: `A-XXXXXX` (e.g., `A-XYZ789`)
- Codes are 8 characters total: role prefix + hyphen + 6 random alphanumeric characters
- Codes are unique and case-insensitive

### 2. Registration Flow

1. Applicant opens registration form in mobile app
2. Applicant fills in:
   - Email
   - Password
   - **Referral Code** (REQUIRED - new field)
   - KTP photo upload
3. Backend validates:
   - Referral code exists
   - Referral code belongs to active staff/admin user
4. If valid:
   - User account created
   - ApplicantProfile created with `referrer` set to the staff/admin who owns the code
   - KTP OCR processing triggered
5. If invalid:
   - Registration rejected with clear error message

### 3. Backend Implementation

#### Model Changes

**File**: `backend/account/models.py`

Added to `CustomUser` model:
```python
referral_code = models.CharField(
    _("kode rujukan"),
    max_length=16,
    null=True,
    blank=True,
    unique=True,
    db_index=True,
    help_text=_("Kode rujukan unik untuk Staff/Admin. Pelamar harus memasukkan kode ini saat registrasi."),
)
```

#### Helper Methods

**File**: `backend/account/models.py`

```python
def generate_referral_code(self) -> str:
    """Generate a unique referral code (S-XXXXXX or A-XXXXXX)"""

def ensure_referral_code(self) -> str:
    """Ensure user has a code, generate if missing"""
```

#### Registration View Updates

**File**: `backend/account/registration_views.py`

- Added `referral_code` parameter validation (REQUIRED)
- Validates code exists and belongs to active staff/admin
- Auto-populates `ApplicantProfile.referrer` field

#### Auto-Generation Signal

**File**: `backend/account/signals.py`

Automatically generates referral codes when:
- New staff/admin users are created
- Existing staff/admin users are saved without a code

### 4. Mobile App Implementation

#### UI Changes

**File**: `mobile/lib/features/auth/presentation/pages/register_page.dart`

Added referral code field:
- Input field with uppercase auto-formatting
- Icon: QR code symbol
- Placeholder: "Contoh: S-ABC123 atau A-XYZ789"
- Helper text: "Masukkan kode rujukan dari staff atau admin"
- Validation: Required, minimum 5 characters

#### API Changes

**Files**: 
- `mobile/lib/features/auth/data/repositories/auth_repository.dart`
- `mobile/lib/features/auth/data/providers/auth_provider.dart`

Updated `register()` method to include `referral_code` parameter.

## Setup Instructions

### Step 1: Run Database Migration

```bash
cd backend
python manage.py makemigrations account
python manage.py migrate
```

### Step 2: Generate Codes for Existing Staff/Admin

Run the management command to generate referral codes for existing users:

```bash
python manage.py generate_referral_codes
```

Expected output:
```
Found 5 staff/admin users without referral codes.
✓ Generated code 'S-ABC123' for staff@example.com (Staff)
✓ Generated code 'A-XYZ789' for admin@example.com (Admin)
✓ Successfully generated 5/5 referral codes!
```

### Step 3: Test Registration

#### Backend Test (Using curl)

```bash
curl -X POST http://localhost:8000/api/auth/register/ \
  -F "email=newuser@example.com" \
  -F "password=SecurePass123" \
  -F "referral_code=S-ABC123" \
  -F "ktp=@/path/to/ktp.jpg"
```

#### Mobile App Test

1. Build and run mobile app
2. Navigate to registration page
3. Fill in all fields including referral code
4. Upload KTP photo
5. Submit form
6. Verify success message and navigation

## Admin Interface

### Viewing Referral Codes

1. Login to Django admin: `http://localhost:8000/admin/`
2. Navigate to "Daftar pengguna" (Users)
3. Referral code column visible in list view
4. Search by referral code or email

### Editing Referral Codes

1. Click on a staff/admin user
2. Find "Kode Rujukan" section
3. Edit the code manually if needed (must be unique)
4. Save changes

### Creating New Staff/Admin

When creating new staff/admin users:
- Leave referral_code blank
- Code will be auto-generated on save via signal
- Or manually enter a unique code

## Tracking Referrals

### View Applicants Referred by Staff

In Django admin or via API:

```python
# Get all applicants referred by a specific staff member
staff_user = CustomUser.objects.get(email='staff@example.com')
applicants = ApplicantProfile.objects.filter(referrer=staff_user)

# Get count
count = applicants.count()
print(f"{staff_user.email} has referred {count} applicants")
```

### Staff Performance Report

```python
from django.db.models import Count
from account.models import CustomUser, UserRole

# Get referral counts per staff/admin
referral_counts = CustomUser.objects.filter(
    role__in=[UserRole.STAFF, UserRole.ADMIN]
).annotate(
    referral_count=Count('referred_applicants')
).order_by('-referral_count')

for user in referral_counts:
    print(f"{user.email}: {user.referral_count} referrals")
```

## API Endpoints

### Registration (Public)

**POST** `/api/auth/register/`

**Request** (multipart/form-data):
```json
{
  "email": "applicant@example.com",
  "password": "SecurePass123",
  "referral_code": "S-ABC123",
  "ktp": <file>
}
```

**Success Response** (201):
```json
{
  "success": true,
  "detail": "Registrasi berhasil. KTP sedang diproses dengan OCR.",
  "data": {
    "user": { ... },
    "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
    "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
  }
}
```

**Error Response** (400):
```json
{
  "success": false,
  "code": "VALIDATION_ERROR",
  "detail": "Kode rujukan tidak valid atau sudah tidak aktif. Pastikan Anda memasukkan kode dengan benar."
}
```

## Validation Rules

### Referral Code Validation

1. **Required**: Cannot be empty
2. **Format**: Must match pattern (letter-hyphen-6chars)
3. **Exists**: Must exist in database
4. **Active**: Owner must be active (is_active=True)
5. **Role**: Owner must be STAFF or ADMIN
6. **Case**: Automatically converted to uppercase

### Error Messages

| Error | Message (Indonesian) |
|-------|---------------------|
| Missing code | "Kode rujukan wajib diisi. Hubungi staff atau admin untuk mendapatkan kode rujukan." |
| Invalid code | "Kode rujukan tidak valid atau sudah tidak aktif. Pastikan Anda memasukkan kode dengan benar." |
| Short code | "Kode rujukan tidak valid" (mobile validation) |

## Security Considerations

1. **No Code Enumeration**: Error messages don't reveal whether code exists or is just inactive
2. **Rate Limiting**: Registration endpoint has throttling via `AuthPublicRateThrottle`
3. **Unique Codes**: Database constraint ensures no duplicate codes
4. **Case Insensitive**: Codes converted to uppercase to prevent user errors
5. **Active Check**: Inactive staff/admin codes are rejected

## Future Enhancements

### Possible Improvements

1. **QR Code Generation**: Generate QR codes for staff to share
2. **Code Expiration**: Add expiry dates for temporary codes
3. **Usage Limits**: Limit number of registrations per code
4. **Analytics Dashboard**: Visual reports of referral performance
5. **Referral Rewards**: Incentive system for high-performing staff
6. **Multi-level Referrals**: Track referral chains (applicant refers applicant)

### Code Expiration Example

```python
# Add to CustomUser model
referral_code_expires_at = models.DateTimeField(
    null=True, blank=True,
    help_text="Kode rujukan kadaluarsa pada tanggal ini"
)

# Update validation in registration_views.py
if referrer_user.referral_code_expires_at and referrer_user.referral_code_expires_at < timezone.now():
    return Response(
        error_response(
            detail="Kode rujukan sudah kadaluarsa. Hubungi staff untuk kode baru.",
            code=ApiCode.VALIDATION_ERROR,
        ),
        status=status.HTTP_400_BAD_REQUEST,
    )
```

## Troubleshooting

### Issue: Existing staff don't have codes

**Solution**: Run the management command
```bash
python manage.py generate_referral_codes
```

### Issue: Code already exists error

**Solution**: Codes are auto-generated uniquely. If manual entry conflicts, try a different code or let the system generate it.

### Issue: Registration fails with valid code

**Checks**:
1. Is the staff/admin user active? (`is_active=True`)
2. Is the code exactly correct? (case doesn't matter, but format does)
3. Check backend logs for detailed error
4. Verify in admin interface that code exists

### Issue: Signal not generating code

**Solution**: Ensure signals are connected in AppConfig:

**File**: `backend/account/apps.py`
```python
class AccountConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'account'

    def ready(self):
        import account.signals  # noqa
```

## Testing Checklist

- [ ] Existing staff/admin have codes generated
- [ ] New staff/admin get codes automatically
- [ ] Registration with valid code succeeds
- [ ] Registration without code fails with clear message
- [ ] Registration with invalid code fails with clear message
- [ ] Registration with inactive staff code fails
- [ ] Referrer is correctly set in ApplicantProfile
- [ ] Mobile UI shows referral code field
- [ ] Mobile validation works correctly
- [ ] Admin interface shows referral codes
- [ ] Search by referral code works in admin

## Summary

The referral code system is now fully implemented with:

✅ **Backend**: Model field, validation, auto-generation, signals
✅ **Mobile App**: UI field, validation, API integration
✅ **Admin Interface**: View/edit codes, search functionality
✅ **Management Command**: Generate codes for existing users
✅ **Documentation**: Complete setup and usage guide

All applicants must now provide a valid referral code from staff or admin to complete registration.
