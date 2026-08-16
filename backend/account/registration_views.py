"""
Public registration and Google OAuth views for mobile app.
Separate file to keep account/views.py focused on admin CRUD.
"""
from django.conf import settings as django_settings
from django.db import IntegrityError, transaction
from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny

from .models import (
    CustomUser,
    UserRole,
    ApplicantProfile,
    ApplicantDocument,
    DocumentType,
    ApplicantVerificationStatus,
)
from .serializers import ApplicantUserSerializer
from .api_responses import (
    ApiCode,
    ApiMessage,
    error_response,
    success_response,
)
from .jwt_cookie_auth import JWTCookieAuthentication
from .throttles import (
    AuthPublicRateThrottle,
    OcrPreviewRateThrottle,
    OcrSessionRateThrottle,
)
from .document_specs import validate_document_file, compress_image_file
from .ocr_session import (
    is_mobile_client,
    issue_ocr_session_token,
    validate_and_consume_ocr_session_token,
)
from rest_framework_simplejwt.authentication import JWTAuthentication
from .validators import validate_indonesian_phone, normalize_indonesian_phone


def _normalize_birth_place_text(raw) -> str:
    """Free-text tempat lahir; strip and uppercase (parity with mobile KTP)."""
    if raw is None:
        return ""
    s = str(raw).strip()
    if not s:
        return ""
    return s[:200].upper()


def _parse_birth_date(birth_date_str):
    """Parse an ISO date string (yyyy-MM-dd) into a date object, or return None."""
    if not birth_date_str:
        return None
    try:
        from datetime import date
        y, m, d = birth_date_str.strip().split('-')
        return date(int(y), int(m), int(d))
    except Exception:
        return None


def _inactive_account_response():
    """Google/Apple (and similar) must not sign in or re-register a deactivated user."""
    return Response(
        error_response(
            detail=ApiMessage.ACCOUNT_INACTIVE,
            code=ApiCode.ACCOUNT_INACTIVE,
            status_code=status.HTTP_403_FORBIDDEN,
        ),
        status=status.HTTP_403_FORBIDDEN,
    )


def _nik_taken_error_response():
    """Same NIK cannot be reused, including on deactivated accounts."""
    return Response(
        error_response(
            detail=ApiMessage.NIK_TAKEN,
            code=ApiCode.NIK_TAKEN,
        ),
        status=status.HTTP_400_BAD_REQUEST,
    )


def _nik_taken_by_other_user(nik: str, user=None) -> bool:
    qs = ApplicantProfile.objects.filter(nik=nik)
    if user is not None:
        qs = qs.exclude(user=user)
    return qs.exists()


def _find_oauth_user(*, social_id_field: str, social_id: str | None, email: str):
    """
    Look up an existing user by social subject then email.

    Returns (user, error_response). error_response is set when the matched
    account is inactive — callers must not issue tokens or link social IDs.
    """
    user = None
    if social_id:
        user = CustomUser.objects.filter(**{social_id_field: social_id}).first()
    if user is None and email:
        user = CustomUser.objects.filter(email__iexact=email).first()
    if user is not None and not user.is_active:
        return user, _inactive_account_response()
    return user, None


class ApplicantRegistrationView(APIView):
    """
    Public endpoint untuk registrasi pelamar dengan KTP upload.
    Menerima email, password, dan file KTP.
    Membuat user + applicant profile, upload KTP, trigger OCR processing.
    """

    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = [AuthPublicRateThrottle]

    def post(self, request):
        from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

        email = request.data.get("email", "").strip().lower()
        password = request.data.get("password")
        nik = request.data.get("nik", "").strip()
        ktp_file = request.FILES.get("ktp")
        referral_code = request.data.get("referral_code", "").strip().upper()
        phone_number = request.data.get("phone_number", "").strip()

        # Validasi email
        if not email:
            return Response(
                error_response(
                    detail="Email wajib diisi.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validasi password
        if not password:
            return Response(
                error_response(
                    detail="Password wajib diisi untuk registrasi dengan email.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validasi NIK (REQUIRED - dari KTP atau input manual)
        if not nik or len(nik) != 16 or not nik.isdigit():
            return Response(
                error_response(
                    detail="NIK wajib diisi, 16 digit angka. Gunakan NIK dari KTP.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Cek NIK sudah terdaftar (termasuk akun yang sudah dinonaktifkan)
        if _nik_taken_by_other_user(nik):
            return _nik_taken_error_response()

        # Validasi referral code (OPTIONAL - can be filled in via edit profile)
        referrer_user = None
        if referral_code:
            # Verifikasi referral code exists and belongs to staff
            try:
                referrer_user = CustomUser.objects.get(
                    referral_code=referral_code,
                    role=UserRole.STAFF,
                    is_active=True,
                )
            except CustomUser.DoesNotExist:
                return Response(
                    error_response(
                        detail="Kode rujukan tidak valid atau sudah tidak aktif. Pastikan Anda memasukkan kode dengan benar.",
                        code=ApiCode.VALIDATION_ERROR,
                    ),
                    status=status.HTTP_400_BAD_REQUEST,
                )

        # Normalize & validate phone number (optional but validated if provided)
        if phone_number:
            phone_number = normalize_indonesian_phone(phone_number)
            try:
                validate_indonesian_phone(phone_number)
            except Exception:
                return Response(
                    error_response(
                        detail="Format nomor telepon tidak valid. Gunakan format +628xxxxxxxxxx atau 08xxxxxxxxxx.",
                        code=ApiCode.VALIDATION_ERROR,
                    ),
                    status=status.HTTP_400_BAD_REQUEST,
                )

        # Validasi KTP file
        if not ktp_file:
            return Response(
                error_response(
                    detail="File KTP wajib diunggah.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validasi format dan ukuran KTP
        try:
            validate_document_file(ktp_file, "ktp")
        except Exception as e:
            return Response(
                error_response(
                    detail=str(e),
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Compress KTP image before saving
        ktp_file = compress_image_file(ktp_file)

        # Cek apakah email sudah terdaftar
        if CustomUser.objects.filter(email=email).exists():
            return Response(
                error_response(
                    detail="Email sudah terdaftar. Gunakan email lain atau lakukan login.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Ambil full_name dari form (dikirim dari mobile setelah OCR/input manual)
        full_name = request.data.get("full_name", "").strip()

        birth_place_text = _normalize_birth_place_text(
            request.data.get("birth_place_text")
        )
        birth_date = _parse_birth_date(request.data.get("birth_date", ""))

        # Validasi usia: minimal 18 tahun, maksimal 45 tahun
        if birth_date:
            from datetime import date as _date
            today = _date.today()
            age = today.year - birth_date.year - (
                (today.month, today.day) < (birth_date.month, birth_date.day)
            )
            if age < 18:
                return Response(
                    error_response(
                        detail="Usia Anda kurang dari 18 tahun. Anda tidak memenuhi syarat untuk mendaftar.",
                        code=ApiCode.VALIDATION_ERROR,
                    ),
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if age > 45:
                return Response(
                    error_response(
                        detail="Usia Anda lebih dari 45 tahun. Anda tidak memenuhi syarat untuk mendaftar.",
                        code=ApiCode.VALIDATION_ERROR,
                    ),
                    status=status.HTTP_400_BAD_REQUEST,
                )

        # Buat user
        try:
            user = CustomUser.objects.create_user(
                email=email,
                password=password,
                role=UserRole.APPLICANT,
                is_active=True,
                email_verified=False,  # Perlu verifikasi email
                full_name=full_name.upper() if full_name else full_name,
            )
        except Exception as e:
            return Response(
                error_response(
                    detail=f"Gagal membuat akun: {str(e)}",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Buat applicant profile (NIK wajib dari input/OCR saat pendaftaran)
        try:
            applicant_profile = ApplicantProfile.objects.create(
                user=user,
                nik=nik,
                verification_status=ApplicantVerificationStatus.SUBMITTED,
                submitted_at=timezone.now(),
                referrer=referrer_user,
                contact_phone=phone_number if phone_number else "",
                birth_place_text=birth_place_text,
                birth_date=birth_date,
            )
        except Exception as e:
            user.delete()  # Rollback
            return Response(
                error_response(
                    detail=f"Gagal membuat profil pelamar: {str(e)}",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Upload KTP document
        try:
            ktp_doc_type = DocumentType.objects.filter(code="ktp").first()
            if not ktp_doc_type:
                # Jika document type KTP belum ada, buat default
                ktp_doc_type = DocumentType.objects.create(
                    code="ktp",
                    name="KTP",
                    is_required=True,
                    sort_order=1,
                )

            ApplicantDocument.objects.create(
                applicant_profile=applicant_profile,
                document_type=ktp_doc_type,
                file=ktp_file,
            )

        except Exception as e:
            # Jika upload gagal, hapus user dan profile
            applicant_profile.delete()
            user.delete()
            return Response(
                error_response(
                    detail=f"Gagal mengunggah KTP: {str(e)}",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # OTP email is sent after the applicant completes biodata on mobile
        # (POST /api/auth/resend-verification-email/), not at signup.
        # try:
        #     from .email_utils import send_verification_email
        #     _logo_url = getattr(django_settings, "LOGO_URL", "") or ""
        #     send_verification_email(user, logo_url=_logo_url)
        # except Exception:
        #     pass

        # Generate JWT tokens — mobile clients get longer-lived refresh tokens
        try:
            from .auth_cookie_views import _is_mobile_client, _mobile_refresh_token_for_user

            if _is_mobile_client(request):
                tokens = _mobile_refresh_token_for_user(user)
            else:
                token_serializer = TokenObtainPairSerializer()
                token_serializer.user = user
                tokens = token_serializer.get_token(user)

            access_token = str(tokens.access_token)
            refresh_token = str(tokens)
        except Exception as e:
            return Response(
                error_response(
                    detail=f"Gagal membuat token: {str(e)}",
                    code=ApiCode.INTERNAL_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        # Return user data + tokens
        serializer = ApplicantUserSerializer(instance=user, context={"request": request})
        return Response(
            success_response(
                data={
                    "user": serializer.data,
                    "access": access_token,
                    "refresh": refresh_token,
                },
                detail="Registrasi berhasil. KTP telah diunggah.",
            ),
            status=status.HTTP_201_CREATED,
        )


def _verify_google_id_token(id_token_raw: str, google_client_id: str) -> dict:
    from google.auth.transport import requests as google_requests
    from google.oauth2 import id_token as google_id_token

    return google_id_token.verify_oauth2_token(
        id_token_raw, google_requests.Request(), google_client_id
    )


class GoogleOAuthView(APIView):
    """
    Public endpoint untuk Google Sign-In authentication.
    Menerima Google ID token, verifikasi dengan Google, buat/login user.
    Mendukung registrasi dan login.
    """

    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = [AuthPublicRateThrottle]

    def post(self, request):
        from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

        id_token_raw = request.data.get("id_token", "").strip()

        if not id_token_raw:
            return Response(
                error_response(
                    detail="Google ID token wajib diisi.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Verifikasi Google ID token
        try:
            google_client_id = getattr(django_settings, "GOOGLE_CLIENT_ID", "")
            if not google_client_id:
                return Response(
                    error_response(
                        detail="Google OAuth tidak dikonfigurasi di server.",
                        code=ApiCode.INTERNAL_ERROR,
                    ),
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR,
                )

            try:
                idinfo = _verify_google_id_token(id_token_raw, google_client_id)
            except ValueError:
                return Response(
                    error_response(
                        detail="Google ID token tidak valid.",
                        code=ApiCode.PERMISSION_DENIED,
                        status_code=status.HTTP_401_UNAUTHORIZED,
                    ),
                    status=status.HTTP_401_UNAUTHORIZED,
                )

            google_id = idinfo.get("sub")
            email = idinfo.get("email", "").strip().lower()
            name = idinfo.get("name", "")

            if not email:
                return Response(
                    error_response(
                        detail="Email tidak ditemukan di Google account.",
                        code=ApiCode.VALIDATION_ERROR,
                    ),
                    status=status.HTTP_400_BAD_REQUEST,
                )

        except ImportError:
            return Response(
                error_response(
                    detail="Google authentication library tidak tersedia.",
                    code=ApiCode.INTERNAL_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        except Exception as e:
            return Response(
                error_response(
                    detail=f"Gagal verifikasi Google token: {str(e)}",
                    code=ApiCode.INTERNAL_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        # Cari atau buat user — akun nonaktif tidak boleh login/daftar ulang via Google
        user, inactive_error = _find_oauth_user(
            social_id_field="google_id",
            social_id=google_id,
            email=email,
        )
        if inactive_error is not None:
            return inactive_error

        created = False
        if user is None:
            user = CustomUser.objects.create_user(
                email=email,
                password=None,  # OAuth users tidak punya password
                role=UserRole.APPLICANT,
                is_active=True,
                email_verified=True,  # Google sudah verifikasi email
                google_id=google_id,
                full_name=name or "",
            )
            created = True

            # Buat applicant profile - NIK sementara (max 16 char), wajib diganti saat lengkapi profil
            ApplicantProfile.objects.create(
                user=user,
                nik=f"G{user.pk:015d}",  # Placeholder Google OAuth; wajib diganti NIK asli dari KTP
                verification_status=ApplicantVerificationStatus.SUBMITTED,
                submitted_at=timezone.now(),
            )
        elif google_id and not user.google_id:
            user.google_id = google_id
            user.save(update_fields=["google_id"])

        # Generate JWT tokens — mobile clients get longer-lived refresh tokens
        try:
            from .auth_cookie_views import _is_mobile_client, _mobile_refresh_token_for_user

            if _is_mobile_client(request):
                tokens = _mobile_refresh_token_for_user(user)
            else:
                token_serializer = TokenObtainPairSerializer()
                token_serializer.user = user
                tokens = token_serializer.get_token(user)

            access_token = str(tokens.access_token)
            refresh_token = str(tokens)
        except Exception as e:
            return Response(
                error_response(
                    detail=f"Gagal membuat token: {str(e)}",
                    code=ApiCode.INTERNAL_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        # Determine if profile needs completion (new user OR has placeholder NIK)
        needs_registration = created
        if not needs_registration:
            try:
                profile = user.applicant_profile
                # Placeholder NIK starts with 'G' (set during Google OAuth creation)
                if profile.nik and profile.nik.startswith('G'):
                    needs_registration = True
            except ApplicantProfile.DoesNotExist:
                needs_registration = True

        # Return user data + tokens
        serializer = ApplicantUserSerializer(instance=user, context={"request": request})
        from audit.models import AuditAction, AuditResourceType
        from audit.services import emit

        emit(
            action=AuditAction.LOGIN,
            resource_type=AuditResourceType.AUTH,
            resource_id=user.pk,
            resource_label=user.email,
            summary=f"Login Google: {user.email}",
            actor=user,
            request=request,
            metadata={"method": "google", "created": created},
        )
        return Response(
            success_response(
                data={
                    "user": serializer.data,
                    "access": access_token,
                    "refresh": refresh_token,
                    "needs_registration": needs_registration,
                },
                detail="Login dengan Google berhasil." if not needs_registration else "Akun baru dibuat. Silakan lengkapi profil Anda.",
            ),
            status=status.HTTP_200_OK if not created else status.HTTP_201_CREATED,
        )


class GoogleCompleteRegistrationView(APIView):
    """
    Authenticated endpoint untuk melengkapi profil setelah Google Sign-In.
    Dipanggil hanya untuk user baru (needs_registration=True dari GoogleOAuthView).
    Menerima: nik, ktp file, referral_code, phone_number, full_name.
    Membuat/mengupdate ApplicantProfile, upload KTP, trigger OCR.
    """

    throttle_classes = [AuthPublicRateThrottle]

    def post(self, request):
        from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
        from .validators import validate_indonesian_phone as _validate_phone
        from .validators import normalize_indonesian_phone as _normalize_phone

        user = request.user
        nik = request.data.get("nik", "").strip()
        ktp_file = request.FILES.get("ktp")
        referral_code = request.data.get("referral_code", "").strip().upper()
        phone_number = request.data.get("phone_number", "").strip()
        full_name = request.data.get("full_name", "").strip()

        # Validasi NIK
        if not nik or len(nik) != 16 or not nik.isdigit():
            return Response(
                error_response(
                    detail="NIK wajib diisi, 16 digit angka.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validasi NIK belum dipakai user lain (termasuk akun yang sudah dinonaktifkan)
        if _nik_taken_by_other_user(nik, user):
            return _nik_taken_error_response()

        # Validasi referral code (OPTIONAL - can be filled in via edit profile)
        referrer_user = None
        if referral_code:
            try:
                referrer_user = CustomUser.objects.get(
                    referral_code=referral_code,
                    role=UserRole.STAFF,
                    is_active=True,
                )
            except CustomUser.DoesNotExist:
                return Response(
                    error_response(
                        detail="Kode rujukan tidak valid atau sudah tidak aktif.",
                        code=ApiCode.VALIDATION_ERROR,
                    ),
                    status=status.HTTP_400_BAD_REQUEST,
                )

        # Normalize & validate phone (optional)
        if phone_number:
            phone_number = _normalize_phone(phone_number)
            try:
                _validate_phone(phone_number)
            except Exception:
                return Response(
                    error_response(
                        detail="Format nomor telepon tidak valid.",
                        code=ApiCode.VALIDATION_ERROR,
                    ),
                    status=status.HTTP_400_BAD_REQUEST,
                )

        # Validasi KTP file
        if not ktp_file:
            return Response(
                error_response(
                    detail="File KTP wajib diunggah.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            validate_document_file(ktp_file, "ktp")
        except Exception as e:
            return Response(
                error_response(detail=str(e), code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Compress KTP image before saving
        ktp_file = compress_image_file(ktp_file)

        # Update full_name on user if provided
        if full_name and not user.full_name:
            user.full_name = full_name
            user.save(update_fields=["full_name"])

        birth_place_text = _normalize_birth_place_text(
            request.data.get("birth_place_text")
        )
        birth_date = _parse_birth_date(request.data.get("birth_date", ""))

        # Create or update ApplicantProfile
        try:
            with transaction.atomic():
                profile, _ = ApplicantProfile.objects.get_or_create(
                    user=user,
                    defaults={
                        "nik": nik,
                        "verification_status": ApplicantVerificationStatus.SUBMITTED,
                        "submitted_at": timezone.now(),
                        "referrer": referrer_user,
                        "contact_phone": phone_number,
                        "birth_place_text": birth_place_text,
                        "birth_date": birth_date,
                    },
                )
                # Overwrite placeholder fields regardless
                profile.nik = nik
                profile.referrer = referrer_user
                if phone_number:
                    profile.contact_phone = phone_number
                if birth_place_text:
                    profile.birth_place_text = birth_place_text
                if birth_date:
                    profile.birth_date = birth_date
                update_fields = ["nik", "referrer", "contact_phone"]
                if birth_place_text:
                    update_fields.append("birth_place_text")
                if birth_date:
                    update_fields.append("birth_date")
                profile.save(update_fields=update_fields)
        except IntegrityError:
            return _nik_taken_error_response()
        except Exception as e:
            return Response(
                error_response(
                    detail=f"Gagal membuat profil: {str(e)}",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Upload KTP document (replace existing if any)
        try:
            ktp_doc_type = DocumentType.objects.filter(code="ktp").first()
            if not ktp_doc_type:
                ktp_doc_type = DocumentType.objects.create(
                    code="ktp", name="KTP", is_required=True, sort_order=1
                )

            # Remove old placeholder KTP if exists
            ApplicantDocument.objects.filter(
                applicant_profile=profile, document_type=ktp_doc_type
            ).delete()

            ApplicantDocument.objects.create(
                applicant_profile=profile,
                document_type=ktp_doc_type,
                file=ktp_file,
            )

        except Exception as e:
            return Response(
                error_response(
                    detail=f"Gagal mengunggah KTP: {str(e)}",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = ApplicantUserSerializer(instance=user, context={"request": request})
        return Response(
            success_response(
                data={"user": serializer.data},
                detail="Profil berhasil dilengkapi. KTP telah diunggah.",
            ),
            status=status.HTTP_200_OK,
        )


def _ocr_feature_disabled_response():
    return Response(
        error_response(
            detail="Fitur OCR KTP tidak aktif. Isi data KTP secara manual.",
            code=ApiCode.NOT_FOUND,
        ),
        status=status.HTTP_404_NOT_FOUND,
    )


def _ocr_preview_mobile_required_response():
    return Response(
        error_response(
            detail="Permintaan OCR hanya dapat diproses dari aplikasi mobile.",
            code=ApiCode.PERMISSION_DENIED,
        ),
        status=status.HTTP_403_FORBIDDEN,
    )


def _ocr_preview_unauthorized_response():
    return Response(
        error_response(
            detail=(
                "Sesi OCR tidak valid atau sudah kedaluwarsa. "
                "Buka ulang langkah unggah KTP di aplikasi."
            ),
            code=ApiCode.PERMISSION_DENIED,
        ),
        status=status.HTTP_401_UNAUTHORIZED,
    )


def _extract_nik_from_ktp_upload(ktp_file):
    """
    Run Vision OCR on an uploaded KTP image; return NIK string or raise ValueError.
    Temp file is always removed.
    """
    import os
    import tempfile

    from .ocr import extract_text_with_blocks, parse_ktp_text_with_regency_match

    tmp_file_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp_file:
            for chunk in ktp_file.chunks():
                tmp_file.write(chunk)
            tmp_file_path = tmp_file.name

        ocr_result = extract_text_with_blocks(tmp_file_path)
        ocr_text = ocr_result["text"]
        blocks = ocr_result["blocks"]

        if not ocr_text:
            raise ValueError(
                "Tidak dapat mengekstrak teks dari KTP. Pastikan foto jelas dan tidak blur."
            )

        parsed_data = parse_ktp_text_with_regency_match(ocr_text, blocks)
        if not parsed_data or not parsed_data.get("nik"):
            raise ValueError(
                "Tidak dapat mengidentifikasi data KTP. Pastikan foto KTP jelas "
                "dan semua informasi terlihat."
            )

        return str(parsed_data["nik"]).strip()
    finally:
        if tmp_file_path:
            try:
                os.unlink(tmp_file_path)
            except OSError:
                pass


class KTPOcrSessionView(APIView):
    """
    Issue a short-lived, IP-bound token required before calling OCR preview
    without login (e.g. future email registration flow).

    POST /api/auth/ocr-preview/session/
    Header: X-Client-Type: mobile
    """

    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = [OcrSessionRateThrottle]

    def post(self, request):
        if not getattr(django_settings, "KTP_OCR_ENABLED", False):
            return _ocr_feature_disabled_response()
        if not is_mobile_client(request):
            return _ocr_preview_mobile_required_response()

        token = issue_ocr_session_token(request)
        if not token:
            return Response(
                error_response(
                    detail="Terlalu banyak permintaan OCR. Coba lagi nanti.",
                    code=ApiCode.RATE_LIMITED,
                ),
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

        return Response(
            success_response(
                data={"ocr_session": token},
                detail="Sesi OCR siap. Unggah foto KTP dalam 15 menit.",
            ),
            status=status.HTTP_200_OK,
        )


class KTPOcrPreviewView(APIView):
    """
    OCR preview KTP — returns **only NIK** (PII minimization on the wire).

    Authorization (one of):
      - Logged-in user (social-complete after Google/Apple), or
      - Valid one-time ``ocr_session`` from POST /api/auth/ocr-preview/session/

    Requires header ``X-Client-Type: mobile``. Throttled per user/IP (Vision API cost).
    """

    permission_classes = [AllowAny]
    authentication_classes = [
        JWTCookieAuthentication,
        JWTAuthentication,
    ]
    throttle_classes = [OcrPreviewRateThrottle]

    def _is_authorized(self, request) -> bool:
        if request.user and request.user.is_authenticated:
            return True
        token = (
            request.headers.get("X-OCR-Session")
            or request.data.get("ocr_session")
            or request.POST.get("ocr_session")
            or ""
        )
        return validate_and_consume_ocr_session_token(request, token)

    def post(self, request):
        if not getattr(django_settings, "KTP_OCR_ENABLED", False):
            return _ocr_feature_disabled_response()
        if not is_mobile_client(request):
            return _ocr_preview_mobile_required_response()

        if not self._is_authorized(request):
            return _ocr_preview_unauthorized_response()

        ktp_file = request.FILES.get("ktp")
        if not ktp_file:
            return Response(
                error_response(
                    detail="File KTP wajib diunggah.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            validate_document_file(ktp_file, "ktp")
        except Exception as e:
            return Response(
                error_response(
                    detail=str(e),
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            nik_value = _extract_nik_from_ktp_upload(ktp_file)
        except ValueError as e:
            return Response(
                error_response(
                    detail=str(e),
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        except Exception as exc:
            detail = (
                f"Gagal memproses OCR: {exc}"
                if django_settings.DEBUG
                else "Gagal memproses OCR. Silakan coba lagi atau isi NIK manual."
            )
            return Response(
                error_response(detail=detail, code=ApiCode.INTERNAL_ERROR),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return Response(
            success_response(
                data={"nik": nik_value},
                detail=(
                    "NIK berhasil dibaca dari foto KTP. Silakan isi nama, "
                    "tempat lahir, dan tanggal lahir secara manual sesuai KTP."
                ),
            ),
            status=status.HTTP_200_OK,
        )


# ---------------------------------------------------------------------------
# Apple Sign-In
# ---------------------------------------------------------------------------

def _verify_apple_identity_token(identity_token: str) -> dict | None:
    """
    Verify an Apple identity token (JWT) against Apple's public JWKS.
    Returns the decoded payload dict on success, None on failure.
    """
    import json
    import jwt as pyjwt
    from urllib.request import urlopen

    APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"

    try:
        jwks_data = json.loads(urlopen(APPLE_JWKS_URL).read())
        public_keys = {}
        for key_data in jwks_data["keys"]:
            public_key = pyjwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(key_data))
            public_keys[key_data["kid"]] = public_key

        unverified_header = pyjwt.get_unverified_header(identity_token)
        kid = unverified_header.get("kid")
        if kid not in public_keys:
            return None

        apple_client_id = getattr(django_settings, "APPLE_CLIENT_ID", "")
        payload = pyjwt.decode(
            identity_token,
            key=public_keys[kid],
            algorithms=["RS256"],
            audience=apple_client_id,
            issuer="https://appleid.apple.com",
        )
        return payload
    except Exception:
        return None


class AppleOAuthView(APIView):
    """
    POST { "identity_token": "...", "full_name": "..." }
    Verify Apple identity token, create or login user.
    Apple only sends the user's name on the FIRST authorization — the client
    must forward it. On subsequent logins only `sub` and `email` are available.
    """

    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = [AuthPublicRateThrottle]

    def post(self, request):
        from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

        identity_token = (request.data.get("identity_token") or "").strip()
        client_full_name = (request.data.get("full_name") or "").strip()

        if not identity_token:
            return Response(
                error_response(
                    detail="Apple identity token wajib diisi.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        apple_client_id = getattr(django_settings, "APPLE_CLIENT_ID", "")
        if not apple_client_id:
            return Response(
                error_response(
                    detail="Apple Sign-In tidak dikonfigurasi di server.",
                    code=ApiCode.INTERNAL_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        payload = _verify_apple_identity_token(identity_token)
        if payload is None:
            return Response(
                error_response(
                    detail="Apple identity token tidak valid.",
                    code=ApiCode.PERMISSION_DENIED,
                    status_code=status.HTTP_401_UNAUTHORIZED,
                ),
                status=status.HTTP_401_UNAUTHORIZED,
            )

        apple_sub = payload.get("sub", "")
        email = (payload.get("email") or "").strip().lower()

        if not apple_sub:
            return Response(
                error_response(
                    detail="Apple token tidak berisi subject ID.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        user, inactive_error = _find_oauth_user(
            social_id_field="apple_id",
            social_id=apple_sub,
            email=email,
        )
        if inactive_error is not None:
            return inactive_error

        created = False
        if user is None:
            if not email:
                return Response(
                    error_response(
                        detail="Email tidak ditemukan di Apple account. Pastikan Anda mengizinkan berbagi email.",
                        code=ApiCode.VALIDATION_ERROR,
                    ),
                    status=status.HTTP_400_BAD_REQUEST,
                )

            user = CustomUser.objects.create_user(
                email=email,
                password=None,
                role=UserRole.APPLICANT,
                is_active=True,
                email_verified=True,
                apple_id=apple_sub,
                full_name=client_full_name or "",
            )
            created = True

            ApplicantProfile.objects.create(
                user=user,
                nik=f"A{user.pk:015d}",
                verification_status=ApplicantVerificationStatus.SUBMITTED,
                submitted_at=timezone.now(),
            )
        elif apple_sub and not user.apple_id:
            user.apple_id = apple_sub
            user.save(update_fields=["apple_id"])

        # Generate JWT tokens
        try:
            from .auth_cookie_views import _is_mobile_client, _mobile_refresh_token_for_user

            if _is_mobile_client(request):
                tokens = _mobile_refresh_token_for_user(user)
            else:
                token_serializer = TokenObtainPairSerializer()
                token_serializer.user = user
                tokens = token_serializer.get_token(user)

            access_token = str(tokens.access_token)
            refresh_token = str(tokens)
        except Exception as e:
            return Response(
                error_response(
                    detail=f"Gagal membuat token: {str(e)}",
                    code=ApiCode.INTERNAL_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        needs_registration = created
        if not needs_registration:
            try:
                profile = user.applicant_profile
                if profile.nik and (profile.nik.startswith("A") or profile.nik.startswith("G")):
                    needs_registration = True
            except ApplicantProfile.DoesNotExist:
                needs_registration = True

        serializer = ApplicantUserSerializer(instance=user, context={"request": request})
        from audit.models import AuditAction, AuditResourceType
        from audit.services import emit

        emit(
            action=AuditAction.LOGIN,
            resource_type=AuditResourceType.AUTH,
            resource_id=user.pk,
            resource_label=user.email,
            summary=f"Login Apple: {user.email}",
            actor=user,
            request=request,
            metadata={"method": "apple", "created": created},
        )
        return Response(
            success_response(
                data={
                    "user": serializer.data,
                    "access": access_token,
                    "refresh": refresh_token,
                    "needs_registration": needs_registration,
                },
                detail="Login dengan Apple berhasil." if not needs_registration else "Akun baru dibuat. Silakan lengkapi profil Anda.",
            ),
            status=status.HTTP_200_OK if not created else status.HTTP_201_CREATED,
        )


# ---------------------------------------------------------------------------
# Account Linking (bind Google/Apple to existing authenticated account)
# ---------------------------------------------------------------------------

class LinkGoogleAccountView(APIView):
    """
    Authenticated. POST { "id_token": "..." }
    Link a Google account to the current user.
    """
    throttle_classes = [AuthPublicRateThrottle]

    def post(self, request):
        user = request.user
        id_token_raw = (request.data.get("id_token") or "").strip()

        if not id_token_raw:
            return Response(
                error_response(detail="Google ID token wajib diisi.", code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            from google.auth.transport import requests as google_requests
            from google.oauth2 import id_token as google_id_token

            google_client_id = getattr(django_settings, "GOOGLE_CLIENT_ID", "")
            if not google_client_id:
                return Response(
                    error_response(detail="Google OAuth tidak dikonfigurasi.", code=ApiCode.INTERNAL_ERROR),
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR,
                )

            idinfo = google_id_token.verify_oauth2_token(
                id_token_raw, google_requests.Request(), google_client_id,
            )
            google_sub = idinfo.get("sub")
        except (ValueError, ImportError):
            return Response(
                error_response(detail="Google ID token tidak valid.", code=ApiCode.PERMISSION_DENIED),
                status=status.HTTP_401_UNAUTHORIZED,
            )

        if user.google_id:
            return Response(
                error_response(detail="Akun Google sudah terhubung.", code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        if CustomUser.objects.filter(google_id=google_sub).exclude(pk=user.pk).exists():
            return Response(
                error_response(detail="Akun Google ini sudah digunakan oleh akun lain.", code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.google_id = google_sub
        user.save(update_fields=["google_id"])

        return Response(
            success_response(detail="Akun Google berhasil dihubungkan.", code=ApiCode.SUCCESS),
            status=status.HTTP_200_OK,
        )


class LinkAppleAccountView(APIView):
    """
    Authenticated. POST { "identity_token": "..." }
    Link an Apple account to the current user.
    """
    throttle_classes = [AuthPublicRateThrottle]

    def post(self, request):
        user = request.user
        identity_token = (request.data.get("identity_token") or "").strip()

        if not identity_token:
            return Response(
                error_response(detail="Apple identity token wajib diisi.", code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        apple_client_id = getattr(django_settings, "APPLE_CLIENT_ID", "")
        if not apple_client_id:
            return Response(
                error_response(detail="Apple Sign-In tidak dikonfigurasi.", code=ApiCode.INTERNAL_ERROR),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        payload = _verify_apple_identity_token(identity_token)
        if payload is None:
            return Response(
                error_response(detail="Apple identity token tidak valid.", code=ApiCode.PERMISSION_DENIED),
                status=status.HTTP_401_UNAUTHORIZED,
            )

        apple_sub = payload.get("sub", "")

        if user.apple_id:
            return Response(
                error_response(detail="Akun Apple sudah terhubung.", code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        if CustomUser.objects.filter(apple_id=apple_sub).exclude(pk=user.pk).exists():
            return Response(
                error_response(detail="Akun Apple ini sudah digunakan oleh akun lain.", code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.apple_id = apple_sub
        user.save(update_fields=["apple_id"])

        return Response(
            success_response(detail="Akun Apple berhasil dihubungkan.", code=ApiCode.SUCCESS),
            status=status.HTTP_200_OK,
        )
