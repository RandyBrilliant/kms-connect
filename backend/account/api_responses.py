"""
Shared API response format dan pesan untuk frontend.
Semua error/success mengembalikan struktur konsisten: detail, code, (errors untuk validasi).
"""
from rest_framework.views import exception_handler
from rest_framework import status


# ---------------------------------------------------------------------------
# Kode untuk frontend (untuk i18n atau conditional messaging)
# ---------------------------------------------------------------------------

class ApiCode:
    """Kode string untuk response; frontend dapat pakai untuk pesan atau logic."""

    # Umum
    SUCCESS = "success"
    VALIDATION_ERROR = "validation_error"
    NOT_FOUND = "not_found"
    PERMISSION_DENIED = "permission_denied"
    METHOD_NOT_ALLOWED = "method_not_allowed"

    # Akun / status
    DELETE_NOT_ALLOWED = "delete_not_allowed"
    ALREADY_DEACTIVATED = "already_deactivated"
    ALREADY_ACTIVATED = "already_activated"
    DEACTIVATED = "deactivated"
    ACTIVATED = "activated"
    PROFILE_UPDATED = "profile_updated"
    EMAIL_SENT = "email_sent"
    EMAIL_ALREADY_VERIFIED = "email_already_verified"
    RESET_PASSWORD_SUCCESS = "reset_password_success"

    # Validasi field
    EMAIL_TAKEN = "email_taken"
    PASSWORD_REQUIRED_ON_CREATE = "password_required_on_create"
    PROFILE_FULL_NAME_REQUIRED = "profile_full_name_required"
    PROFILE_COMPANY_NAME_REQUIRED = "profile_company_name_required"
    NIK_TAKEN = "nik_taken"
    NIK_INVALID = "nik_invalid"


# ---------------------------------------------------------------------------
# Pesan (Indonesian) – satu sumber kebenaran
# ---------------------------------------------------------------------------

class ApiMessage:
    """Pesan siap pakai untuk response API."""

    # Umum
    VALIDATION_ERROR = "Data tidak valid. Periksa field yang dilampirkan."
    NOT_FOUND = "Resource tidak ditemukan."
    PERMISSION_DENIED = "Anda tidak memiliki izin untuk aksi ini."
    METHOD_NOT_ALLOWED = "Metode tidak diizinkan."

    # Akun
    DELETE_NOT_ALLOWED = "Penghapusan tidak diizinkan. Gunakan aksi deactivate untuk menonaktifkan akun."
    ALREADY_DEACTIVATED = "Akun sudah nonaktif."
    ALREADY_ACTIVATED = "Akun sudah aktif."
    DEACTIVATED = "Akun berhasil dinonaktifkan."
    ACTIVATED = "Akun berhasil diaktifkan kembali."
    PROFILE_UPDATED = "Profil berhasil diperbarui."
    EMAIL_SENT = "Email berhasil dikirim."
    EMAIL_ALREADY_VERIFIED = "Email sudah terverifikasi."
    RESET_PASSWORD_SUCCESS = "Kata sandi berhasil diatur ulang."

    # Validasi
    EMAIL_TAKEN = "Pengguna dengan email ini sudah terdaftar."
    PASSWORD_REQUIRED_ON_CREATE = "Password wajib diisi saat membuat akun baru."
    PROFILE_FULL_NAME_REQUIRED = "Nama lengkap wajib diisi."
    PROFILE_COMPANY_NAME_REQUIRED = "Nama perusahaan wajib diisi."
    APPLICANT_FULL_NAME_REQUIRED = "Nama lengkap CPMI wajib diisi."
    APPLICANT_NIK_REQUIRED = "NIK wajib diisi."
    NIK_TAKEN = "NIK ini sudah terdaftar untuk pelamar lain."
    NIK_INVALID = "NIK harus 16 digit angka."


# ---------------------------------------------------------------------------
# Helper response (return dict untuk Response(data=..., status=...))
# ---------------------------------------------------------------------------

def error_response(detail: str, code: str, errors: dict | None = None, status_code: int = status.HTTP_400_BAD_REQUEST) -> dict:
    """
    Format error konsisten untuk frontend.
    Returns dict; gunakan: Response(error_response(...), status=status_code).
    """
    payload = {"detail": detail, "code": code}
    if errors is not None:
        payload["errors"] = errors
    return payload


def success_response(data=None, detail: str | None = None, code: str = ApiCode.SUCCESS) -> dict:
    """
    Format success opsional (untuk aksi seperti deactivate/activate).
    Returns dict; gunakan: Response(success_response(...), status=200).
    """
    payload = {"code": code}
    if detail is not None:
        payload["detail"] = detail
    if data is not None:
        payload["data"] = data
    return payload


# ---------------------------------------------------------------------------
# DRF exception handler – format semua error API konsisten
# ---------------------------------------------------------------------------

def validate_email_unique(model_class, value: str, instance=None):
    """
    Cek email unik; raise rest_framework.ValidationError jika sudah dipakai.
    Reusable untuk serializer validate_email.
    """
    from rest_framework import serializers

    if not value:
        return value
    qs = model_class.objects.filter(email__iexact=value.strip().lower())
    if instance is not None:
        qs = qs.exclude(pk=instance.pk)
    if qs.exists():
        raise serializers.ValidationError(ApiMessage.EMAIL_TAKEN)
    return value.strip().lower()


def validate_nik_format(value: str) -> str:
    """NIK harus 16 digit angka. Return value yang sudah strip atau raise ValidationError."""
    from rest_framework import serializers

    if not value:
        return value
    cleaned = (value or "").strip()
    if not cleaned.isdigit() or len(cleaned) != 16:
        raise serializers.ValidationError(ApiMessage.NIK_INVALID)
    return cleaned


def validate_nik_unique(value: str, profile_instance=None) -> str:
    """
    Cek NIK format (16 digit) dan unik di ApplicantProfile.
    profile_instance: ApplicantProfile yang sedang di-update (exclude dari cek).
    """
    from rest_framework import serializers
    from .models import ApplicantProfile

    if not value:
        return value
    cleaned = validate_nik_format(value)
    qs = ApplicantProfile.objects.filter(nik=cleaned)
    if profile_instance is not None and getattr(profile_instance, "pk", None):
        qs = qs.exclude(pk=profile_instance.pk)
    if qs.exists():
        raise serializers.ValidationError(ApiMessage.NIK_TAKEN)
    return cleaned


def api_exception_handler(exc, context):
    """
    Custom exception handler agar semua error API punya bentuk: detail, code, errors (jika ada).
    Pasang di settings: REST_FRAMEWORK["EXCEPTION_HANDLER"] = "account.api_responses.api_exception_handler"
    """
    response = exception_handler(exc, context)
    if response is None:
        return response

    data = response.data
    if not isinstance(data, dict):
        return response

    # Validasi error (400): DRF mengirim { "field": ["msg"], ... } → normalisasi ke detail + code + errors
    if response.status_code == status.HTTP_400_BAD_REQUEST and "detail" not in data and "code" not in data:
        response.data = {
            "detail": ApiMessage.VALIDATION_ERROR,
            "code": ApiCode.VALIDATION_ERROR,
            "errors": data,
        }
        return response

    # Pastikan ada code dan detail untuk error lain (403, 404, 405, dll.)
    if "code" not in data:
        data["code"] = {
            status.HTTP_404_NOT_FOUND: ApiCode.NOT_FOUND,
            status.HTTP_403_FORBIDDEN: ApiCode.PERMISSION_DENIED,
            status.HTTP_405_METHOD_NOT_ALLOWED: ApiCode.METHOD_NOT_ALLOWED,
        }.get(response.status_code, ApiCode.VALIDATION_ERROR)
    if "detail" not in data:
        data["detail"] = ApiMessage.VALIDATION_ERROR
    response.data = data
    return response
