"""
Public registration and Google OAuth views for mobile app.
Separate file to keep account/views.py focused on admin CRUD.
"""
from django.conf import settings as django_settings
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
from .throttles import AuthPublicRateThrottle
from .document_specs import validate_document_file
from .tasks import process_document_ocr, optimize_document_image


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

        # Cek NIK sudah terdaftar
        if ApplicantProfile.objects.filter(nik=nik).exists():
            return Response(
                error_response(
                    detail="NIK ini sudah terdaftar untuk pelamar lain.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validasi referral code (REQUIRED)
        if not referral_code:
            return Response(
                error_response(
                    detail="Kode rujukan wajib diisi. Hubungi staff atau admin untuk mendapatkan kode rujukan.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Verifikasi referral code exists and belongs to staff/admin
        try:
            referrer_user = CustomUser.objects.get(
                referral_code=referral_code,
                role__in=[UserRole.STAFF, UserRole.ADMIN],
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

        # Cek apakah email sudah terdaftar
        if CustomUser.objects.filter(email=email).exists():
            return Response(
                error_response(
                    detail="Email sudah terdaftar. Gunakan email lain atau lakukan login.",
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
                verification_status=ApplicantVerificationStatus.DRAFT,
                referrer=referrer_user,
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

            ktp_document = ApplicantDocument.objects.create(
                applicant_profile=applicant_profile,
                document_type=ktp_doc_type,
                file=ktp_file,
            )

            # Trigger OCR processing (async)
            process_document_ocr.delay(ktp_document.id)

            # Trigger image optimization (async)
            optimize_document_image.delay(ktp_document.id)

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

        # Generate JWT tokens
        try:
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
                detail="Registrasi berhasil. KTP sedang diproses dengan OCR.",
            ),
            status=status.HTTP_201_CREATED,
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

        id_token = request.data.get("id_token", "").strip()

        if not id_token:
            return Response(
                error_response(
                    detail="Google ID token wajib diisi.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Verifikasi Google ID token
        try:
            from google.auth.transport import requests
            from google.oauth2 import id_token

            google_client_id = getattr(django_settings, "GOOGLE_CLIENT_ID", "")
            if not google_client_id:
                return Response(
                    error_response(
                        detail="Google OAuth tidak dikonfigurasi di server.",
                        code=ApiCode.INTERNAL_ERROR,
                    ),
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR,
                )

            # Verifikasi token
            try:
                idinfo = id_token.verify_oauth2_token(id_token, requests.Request(), google_client_id)
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

        # Cari atau buat user
        user = None
        created = False

        # Cek berdasarkan google_id dulu
        if google_id:
            try:
                user = CustomUser.objects.get(google_id=google_id)
            except CustomUser.DoesNotExist:
                pass

        # Jika tidak ditemukan, cek berdasarkan email
        if not user:
            try:
                user = CustomUser.objects.get(email=email)
                # Update google_id jika belum ada
                if not user.google_id and google_id:
                    user.google_id = google_id
                    user.save(update_fields=["google_id"])
            except CustomUser.DoesNotExist:
                # Buat user baru
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
                    verification_status=ApplicantVerificationStatus.DRAFT,
                )

        # Generate JWT tokens
        try:
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
                detail="Login dengan Google berhasil." if not created else "Registrasi dengan Google berhasil.",
            ),
            status=status.HTTP_200_OK if not created else status.HTTP_201_CREATED,
        )


class KTPOcrPreviewView(APIView):
    """
    Public endpoint untuk OCR preview KTP sebelum registrasi.
    Menerima file KTP, menjalankan OCR, mengembalikan data parsed.
    Tidak membuat user/profile, hanya untuk preview data.
    """

    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = [AuthPublicRateThrottle]

    def post(self, request):
        import tempfile
        import os
        from .ocr import extract_text_from_image, parse_ktp_text

        ktp_file = request.FILES.get("ktp")

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

        # Save file to temporary location
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp_file:
                for chunk in ktp_file.chunks():
                    tmp_file.write(chunk)
                tmp_file_path = tmp_file.name

            # Extract text using Google Cloud Vision
            ocr_text = extract_text_from_image(tmp_file_path)

            # Clean up temp file
            os.unlink(tmp_file_path)

            if not ocr_text:
                return Response(
                    error_response(
                        detail="Tidak dapat mengekstrak teks dari KTP. Pastikan foto jelas dan tidak blur.",
                        code=ApiCode.VALIDATION_ERROR,
                    ),
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Parse KTP text
            parsed_data = parse_ktp_text(ocr_text)

            if not parsed_data or not parsed_data.get("nik"):
                return Response(
                    error_response(
                        detail="Tidak dapat mengidentifikasi data KTP. Pastikan foto KTP jelas dan semua informasi terlihat.",
                        code=ApiCode.VALIDATION_ERROR,
                    ),
                    status=status.HTTP_400_BAD_REQUEST,
                )

            return Response(
                success_response(
                    data=parsed_data,
                    detail="Data KTP berhasil diekstrak. Silakan periksa dan lengkapi data yang kosong.",
                ),
                status=status.HTTP_200_OK,
            )

        except Exception as e:
            # Clean up temp file if it exists
            if 'tmp_file_path' in locals():
                try:
                    os.unlink(tmp_file_path)
                except:
                    pass

            return Response(
                error_response(
                    detail=f"Gagal memproses OCR: {str(e)}",
                    code=ApiCode.INTERNAL_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
