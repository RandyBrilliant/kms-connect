"""
Auth views that set JWT in HTTP-only cookies (web) and return user data.
Login and refresh set cookies; logout clears them.
CSRF exempt so SPA can POST without CSRF token (auth is JWT, not session).
"""
from datetime import timedelta

from django.conf import settings as django_settings
from django.utils import timezone
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from django.utils.module_loading import import_string
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.settings import api_settings as jwt_api_settings
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from .api_responses import ApiCode, ApiMessage, error_response, success_response
from .throttles import AuthRateThrottle, AuthPublicRateThrottle


def _cookie_settings():
    s = getattr(django_settings, "SIMPLE_JWT", {}) or {}
    return {
        "access_key": s.get("AUTH_COOKIE_ACCESS_KEY") or "kms_access",
        "refresh_key": s.get("AUTH_COOKIE_REFRESH_KEY") or "kms_refresh",
        "secure": s.get("AUTH_COOKIE_SECURE", False),
        "httponly": s.get("AUTH_COOKIE_HTTP_ONLY", True),
        "samesite": s.get("AUTH_COOKIE_SAMESITE") or "Lax",
        "path": s.get("AUTH_COOKIE_PATH") or "/",
    }


def _access_max_age_seconds():
    lifetime = getattr(jwt_api_settings, "ACCESS_TOKEN_LIFETIME", None)
    if lifetime is None:
        return 60 * 5  # 5 min default
    return int(lifetime.total_seconds())


def _refresh_max_age_seconds():
    lifetime = getattr(jwt_api_settings, "REFRESH_TOKEN_LIFETIME", None)
    if lifetime is None:
        return 60 * 60 * 24  # 1 day default
    return int(lifetime.total_seconds())


def _user_summary(user):
    """Minimal user data for frontend (no password, no sensitive)."""
    return {
        "id": user.id,
        "email": user.email,
        "full_name": getattr(user, "full_name", "") or "",
        "role": user.role,
        "is_active": user.is_active,
        "email_verified": user.email_verified,
        "google_id": getattr(user, "google_id", None) or None,
        "apple_id": getattr(user, "apple_id", None) or None,
    }


def _set_cookie(response, key, value, max_age, cookie_settings):
    response.set_cookie(
        key=key,
        value=value,
        max_age=max_age,
        path=cookie_settings["path"],
        secure=cookie_settings["secure"],
        httponly=cookie_settings["httponly"],
        samesite=cookie_settings["samesite"],
    )


def _delete_cookie(response, key, cookie_settings):
    response.delete_cookie(
        key=key,
        path=cookie_settings["path"],
        samesite=cookie_settings["samesite"],
    )


def _is_mobile_client(request):
    """Detect mobile app via X-Client-Type header sent by the Flutter client."""
    return request.META.get("HTTP_X_CLIENT_TYPE", "").lower() == "mobile"


def _mobile_refresh_lifetime():
    return timedelta(days=getattr(django_settings, "JWT_MOBILE_REFRESH_DAYS", 365))


def _mobile_refresh_token_for_user(user):
    """Create a long-lived refresh token for persistent mobile sessions."""
    token = RefreshToken.for_user(user)
    token.set_exp(lifetime=_mobile_refresh_lifetime())
    return token


def _extend_refresh_token(token_str):
    """Re-sign an existing refresh token with the mobile-length lifetime."""
    token = RefreshToken(token_str)
    token.set_exp(lifetime=_mobile_refresh_lifetime())
    return str(token)


@method_decorator(csrf_exempt, name="dispatch")
class CookieTokenObtainPairView(APIView):
    """
    POST email + password → validate, issue access + refresh, set HTTP-only cookies,
    return user summary (id, email, role, is_active, email_verified).
    For mobile: can still send Authorization: Bearer later; cookies are for web.
    Throttled per IP to limit brute force (auth scope).
    """
    permission_classes = ()
    authentication_classes = ()
    throttle_classes = [AuthRateThrottle]

    def post(self, request):
        serializer_class = import_string(jwt_api_settings.TOKEN_OBTAIN_SERIALIZER)
        serializer = serializer_class(data=request.data, context={"request": request})
        try:
            serializer.is_valid(raise_exception=True)
        except AuthenticationFailed as e:
            detail = e.detail
            if isinstance(detail, list) and detail:
                detail = str(detail[0])
            elif not isinstance(detail, str):
                detail = "Email atau password salah."
            return Response(
                error_response(
                    detail=detail,
                    code=ApiCode.PERMISSION_DENIED,
                    status_code=status.HTTP_401_UNAUTHORIZED,
                ),
                status=status.HTTP_401_UNAUTHORIZED,
            )
        except (InvalidToken, TokenError) as e:
            return Response(
                error_response(
                    detail=str(e) or ApiMessage.PERMISSION_DENIED,
                    code=ApiCode.PERMISSION_DENIED,
                    status_code=status.HTTP_401_UNAUTHORIZED,
                ),
                status=status.HTTP_401_UNAUTHORIZED,
            )

        data = serializer.validated_data
        user = serializer.user

        # Allow login before email verification so applicants can resume
        # profile completion; mobile gates home until profile + OTP are done.

        access = data["access"]
        refresh = data["refresh"]

        # Mobile clients get a longer-lived refresh token so the session
        # persists indefinitely (like Instagram, WhatsApp, etc.).
        if _is_mobile_client(request):
            mobile_token = _mobile_refresh_token_for_user(user)
            access = str(mobile_token.access_token)
            refresh = str(mobile_token)

        cookie_settings = _cookie_settings()

        response = Response(
            success_response(
                data={
                    "user": _user_summary(user),
                    # Include tokens in the response body so mobile clients can
                    # store them directly (web uses the HTTP-only cookies below).
                    "access": access,
                    "refresh": refresh,
                },
                detail="Login berhasil.",
                code=ApiCode.SUCCESS,
            ),
            status=status.HTTP_200_OK,
        )
        _set_cookie(
            response,
            cookie_settings["access_key"],
            access,
            _access_max_age_seconds(),
            cookie_settings,
        )
        _set_cookie(
            response,
            cookie_settings["refresh_key"],
            refresh,
            _refresh_max_age_seconds(),
            cookie_settings,
        )
        return response


@method_decorator(csrf_exempt, name="dispatch")
class CookieTokenRefreshView(APIView):
    """
    POST (optional body) → read refresh from cookie or body, issue new access,
    set new access cookie, return user summary.
    Throttled per IP when unauthenticated (auth scope).
    """
    permission_classes = ()
    authentication_classes = ()
    throttle_classes = [AuthRateThrottle]

    def post(self, request):
        cookie_settings = _cookie_settings()
        refresh_raw = request.COOKIES.get(cookie_settings["refresh_key"]) or request.data.get("refresh")
        if not refresh_raw:
            return Response(
                error_response(
                    detail="Refresh token tidak ditemukan. Kirim dalam cookie atau body.",
                    code=ApiCode.PERMISSION_DENIED,
                    status_code=status.HTTP_401_UNAUTHORIZED,
                ),
                status=status.HTTP_401_UNAUTHORIZED,
            )

        serializer_class = import_string(jwt_api_settings.TOKEN_REFRESH_SERIALIZER)
        serializer = serializer_class(data={"refresh": refresh_raw}, context={"request": request})
        try:
            serializer.is_valid(raise_exception=True)
        except Exception as e:
            if isinstance(e, (InvalidToken, TokenError)):
                return Response(
                    error_response(
                        detail=str(e) or "Token tidak valid atau kedaluwarsa.",
                        code=ApiCode.PERMISSION_DENIED,
                        status_code=status.HTTP_401_UNAUTHORIZED,
                    ),
                    status=status.HTTP_401_UNAUTHORIZED,
                )
            raise

        data = serializer.validated_data
        access = data["access"]
        # When ROTATE_REFRESH_TOKENS=True, SimpleJWT puts the new refresh token
        # in validated_data["refresh"].  Include it in the response body so mobile
        # clients can persist the rotated token and extend their session.
        new_refresh = data.get("refresh")

        # Mobile clients: extend the rotated refresh token to the mobile
        # lifetime so the session clock resets on every refresh.
        if new_refresh and _is_mobile_client(request):
            new_refresh = _extend_refresh_token(new_refresh)

        # Get user from the (original) refresh token payload for user summary.
        from django.contrib.auth import get_user_model
        try:
            refresh_token = RefreshToken(refresh_raw)
            user_id = refresh_token.get(jwt_api_settings.USER_ID_CLAIM)
            user = get_user_model().objects.get(pk=user_id)
            user_data = _user_summary(user)
        except Exception:
            user_data = None

        response_data: dict = {"access": access}
        if new_refresh:
            # Include rotated refresh token so mobile clients can update storage.
            response_data["refresh"] = new_refresh
        if user_data:
            response_data["user"] = user_data

        response = Response(
            success_response(
                data=response_data,
                detail="Token diperbarui.",
                code=ApiCode.SUCCESS,
            ),
            status=status.HTTP_200_OK,
        )
        _set_cookie(
            response,
            cookie_settings["access_key"],
            access,
            _access_max_age_seconds(),
            cookie_settings,
        )
        # Also update the refresh cookie when token rotation is active.
        if new_refresh:
            _set_cookie(
                response,
                cookie_settings["refresh_key"],
                new_refresh,
                _refresh_max_age_seconds(),
                cookie_settings,
            )
        return response


@method_decorator(csrf_exempt, name="dispatch")
class CookieLogoutView(APIView):
    """
    POST (no body required) → clear access and refresh cookies.
    """
    permission_classes = ()
    authentication_classes = ()

    def post(self, request):
        cookie_settings = _cookie_settings()
        response = Response(
            success_response(detail="Logout berhasil.", code=ApiCode.SUCCESS),
            status=status.HTTP_200_OK,
        )
        _delete_cookie(response, cookie_settings["access_key"], cookie_settings)
        _delete_cookie(response, cookie_settings["refresh_key"], cookie_settings)
        return response


# ---------------------------------------------------------------------------
# Public: verifikasi email (POST code) & konfirmasi reset password (POST)
# ---------------------------------------------------------------------------

@method_decorator(csrf_exempt, name="dispatch")
class VerifyEmailView(APIView):
    """
    GET /api/auth/verify-email/?token=xxx → legacy link-based verification.
    Kept for backward compatibility with emails already sent.
    """
    permission_classes = ()
    authentication_classes = ()
    throttle_classes = [AuthPublicRateThrottle]

    def get(self, request):
        from .email_utils import verify_email_token

        token = request.query_params.get("token") or request.GET.get("token")
        if not token:
            return Response(
                error_response(
                    detail="Parameter token wajib diisi.",
                    code=ApiCode.VALIDATION_ERROR,
                    status_code=status.HTTP_400_BAD_REQUEST,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        user = verify_email_token(token)
        if not user:
            return Response(
                error_response(
                    detail="Token tidak valid atau kedaluwarsa.",
                    code=ApiCode.PERMISSION_DENIED,
                    status_code=status.HTTP_400_BAD_REQUEST,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        if user.email_verified:
            return Response(
                success_response(
                    data={"email": user.email},
                    detail=ApiMessage.EMAIL_ALREADY_VERIFIED,
                    code=ApiCode.EMAIL_ALREADY_VERIFIED,
                ),
                status=status.HTTP_200_OK,
            )
        user.email_verified = True
        user.email_verified_at = timezone.now()
        user.save(update_fields=["email_verified", "email_verified_at"])
        return Response(
            success_response(
                data={"email": user.email},
                detail="Email berhasil diverifikasi.",
                code=ApiCode.SUCCESS,
            ),
            status=status.HTTP_200_OK,
        )


@method_decorator(csrf_exempt, name="dispatch")
class VerifyEmailCodeView(APIView):
    """
    POST { "email": "...", "code": "123456" } → verify 6-digit code.
    Mobile-friendly email verification endpoint.
    Throttled per IP (auth_public scope).
    """
    permission_classes = ()
    authentication_classes = ()
    throttle_classes = [AuthPublicRateThrottle]

    def post(self, request):
        from .email_utils import verify_email_code
        from .models import CustomUser

        email = (request.data.get("email") or "").strip().lower()
        code = (request.data.get("code") or "").strip()

        if not email:
            return Response(
                error_response(
                    detail="Email wajib diisi.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not code or len(code) != 6 or not code.isdigit():
            return Response(
                error_response(
                    detail="Kode verifikasi harus 6 digit angka.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Check if already verified BEFORE verify_code mutates the user.
        already_verified = False
        try:
            existing = CustomUser.objects.get(email__iexact=email)
            already_verified = existing.email_verified
        except CustomUser.DoesNotExist:
            pass

        user = verify_email_code(email, code)
        if not user:
            return Response(
                error_response(
                    detail="Kode verifikasi tidak valid atau sudah kedaluwarsa. Silakan minta kode baru.",
                    code=ApiCode.PERMISSION_DENIED,
                    status_code=status.HTTP_400_BAD_REQUEST,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        if already_verified:
            return Response(
                success_response(
                    data={"email": user.email},
                    detail=ApiMessage.EMAIL_ALREADY_VERIFIED,
                    code=ApiCode.EMAIL_ALREADY_VERIFIED,
                ),
                status=status.HTTP_200_OK,
            )

        return Response(
            success_response(
                data={"email": user.email},
                detail="Email berhasil diverifikasi.",
                code=ApiCode.SUCCESS,
            ),
            status=status.HTTP_200_OK,
        )


@method_decorator(csrf_exempt, name="dispatch")
class RequestPasswordResetView(APIView):
    """
    Public. POST { "email": "user@example.com" } → send password reset email if user exists.
    Always returns success to prevent email enumeration.
    Throttled per IP.
    """
    permission_classes = ()
    authentication_classes = ()
    throttle_classes = [AuthPublicRateThrottle]

    def post(self, request):
        from django.contrib.auth import get_user_model
        from .email_utils import send_password_reset_email

        User = get_user_model()
        email = (request.data.get("email") or "").strip().lower()
        if not email:
            return Response(
                error_response(
                    detail="Email wajib diisi.",
                    code=ApiCode.VALIDATION_ERROR,
                    status_code=status.HTTP_400_BAD_REQUEST,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        user = User.objects.filter(email__iexact=email).first()
        if user:
            logo_url = getattr(django_settings, "LOGO_URL", "") or ""
            send_password_reset_email(user, logo_url=logo_url)
        return Response(
            success_response(
                detail="Jika email terdaftar, tautan reset password akan dikirim.",
                code=ApiCode.EMAIL_SENT,
            ),
            status=status.HTTP_200_OK,
        )


@method_decorator(csrf_exempt, name="dispatch")
class ConfirmResetPasswordView(APIView):
    """
    POST { "uid": "<base64>", "token": "<token>", "new_password": "..." } → set password.
    uid dan token dari link reset password di email.
    Throttled per IP (auth_public scope).
    """
    permission_classes = ()
    authentication_classes = ()
    throttle_classes = [AuthPublicRateThrottle]

    def post(self, request):
        from django.contrib.auth.password_validation import validate_password
        from .email_utils import get_user_from_reset_uid_token

        uid = request.data.get("uid")
        token = request.data.get("token")
        new_password = request.data.get("new_password")
        if not uid or not token:
            return Response(
                error_response(
                    detail="uid dan token wajib diisi.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not new_password:
            return Response(
                error_response(
                    detail="new_password wajib diisi.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        user = get_user_from_reset_uid_token(uid, token)
        if not user:
            return Response(
                error_response(
                    detail="Tautan tidak valid atau kedaluwarsa.",
                    code=ApiCode.PERMISSION_DENIED,
                    status_code=status.HTTP_400_BAD_REQUEST,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            validate_password(new_password, user)
        except Exception as e:
            msgs = getattr(e, "messages", None) or [str(e)]
            detail = msgs[0] if msgs else "Password tidak memenuhi syarat."
            return Response(
                error_response(
                    detail=detail,
                    code=ApiCode.VALIDATION_ERROR,
                    errors={"new_password": list(msgs)} if msgs else None,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        user.set_password(new_password)
        user.save(update_fields=["password"])
        return Response(
            success_response(
                detail=ApiMessage.RESET_PASSWORD_SUCCESS,
                code=ApiCode.RESET_PASSWORD_SUCCESS,
            ),
            status=status.HTTP_200_OK,
        )


class ChangePasswordView(APIView):
    """
    Authenticated endpoint for dashboard users to change their own password.
    POST { "old_password": "...", "new_password": "..." }
    """

    permission_classes = [IsAuthenticated]
    throttle_classes = [AuthRateThrottle]

    def post(self, request):
        from django.contrib.auth.password_validation import validate_password
        from django.core.exceptions import ValidationError

        user = request.user
        old_password = (request.data.get("old_password") or "").strip()
        new_password = (request.data.get("new_password") or "").strip()

        field_errors: dict[str, list[str]] = {}

        if not old_password:
            field_errors.setdefault("old_password", []).append("Password lama wajib diisi.")
        if not new_password:
            field_errors.setdefault("new_password", []).append("Password baru wajib diisi.")

        if field_errors:
            return Response(
                error_response(
                    detail=ApiMessage.VALIDATION_ERROR,
                    code=ApiCode.VALIDATION_ERROR,
                    errors=field_errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not user.check_password(old_password):
            field_errors.setdefault("old_password", []).append("Password lama tidak sesuai.")
            return Response(
                error_response(
                    detail=ApiMessage.VALIDATION_ERROR,
                    code=ApiCode.VALIDATION_ERROR,
                    errors=field_errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            validate_password(new_password, user)
        except ValidationError as e:
            msgs = list(e.messages) or ["Password tidak memenuhi syarat."]
            field_errors.setdefault("new_password", []).extend(msgs)
            return Response(
                error_response(
                    detail=msgs[0],
                    code=ApiCode.VALIDATION_ERROR,
                    errors=field_errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.set_password(new_password)
        user.save(update_fields=["password"])

        return Response(
            success_response(
                detail=ApiMessage.RESET_PASSWORD_SUCCESS,
                code=ApiCode.RESET_PASSWORD_SUCCESS,
            ),
            status=status.HTTP_200_OK,
        )


@method_decorator(csrf_exempt, name="dispatch")
class ResendVerificationEmailView(APIView):
    """
    Public. POST { "email": "..." } → resend verification code if user exists and email not yet verified.
    Always returns 200 to prevent email enumeration.
    Throttled per IP (auth_public scope).
    """
    permission_classes = ()
    authentication_classes = ()
    throttle_classes = [AuthPublicRateThrottle]

    def post(self, request):
        from django.contrib.auth import get_user_model
        from .email_utils import send_verification_email

        User = get_user_model()
        email = (request.data.get("email") or "").strip().lower()
        if not email:
            return Response(
                error_response(
                    detail="Email wajib diisi.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        user = User.objects.filter(email__iexact=email, is_active=True).first()
        if user and not user.email_verified:
            logo_url = getattr(django_settings, "LOGO_URL", "") or ""
            send_verification_email(user, logo_url=logo_url)
        # Always return 200 so callers cannot enumerate registered emails
        return Response(
            success_response(
                detail="Jika email terdaftar dan belum terverifikasi, kode verifikasi akan dikirim.",
                code=ApiCode.EMAIL_SENT,
            ),
            status=status.HTTP_200_OK,
        )


@method_decorator(csrf_exempt, name="dispatch")
class UpdateUnverifiedEmailView(APIView):
    """
    Public. POST {
      "current_email": "...",
      "new_email": "...",
      "password": "..."
    }
    Update an unverified account's email and resend verification code.
    """
    permission_classes = ()
    authentication_classes = ()
    throttle_classes = [AuthPublicRateThrottle]

    def post(self, request):
        from django.contrib.auth import get_user_model
        from .email_utils import send_verification_email

        User = get_user_model()
        current_email = (request.data.get("current_email") or "").strip().lower()
        new_email = (request.data.get("new_email") or "").strip().lower()
        password = (request.data.get("password") or "").strip()

        field_errors: dict[str, list[str]] = {}
        if not current_email:
            field_errors.setdefault("current_email", []).append("Email saat ini wajib diisi.")
        if not new_email:
            field_errors.setdefault("new_email", []).append("Email baru wajib diisi.")
        if not password:
            field_errors.setdefault("password", []).append("Password wajib diisi.")
        if field_errors:
            return Response(
                error_response(
                    detail=ApiMessage.VALIDATION_ERROR,
                    code=ApiCode.VALIDATION_ERROR,
                    errors=field_errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.filter(email__iexact=current_email, is_active=True).first()
        if not user or not user.check_password(password):
            return Response(
                error_response(
                    detail="Email saat ini atau password tidak valid.",
                    code=ApiCode.PERMISSION_DENIED,
                    status_code=status.HTTP_401_UNAUTHORIZED,
                ),
                status=status.HTTP_401_UNAUTHORIZED,
            )

        if user.email_verified:
            return Response(
                error_response(
                    detail="Email akun ini sudah terverifikasi dan tidak dapat diubah lewat menu ini.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        if current_email == new_email:
            return Response(
                error_response(
                    detail="Email baru harus berbeda dari email saat ini.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        if User.objects.filter(email__iexact=new_email).exclude(pk=user.pk).exists():
            return Response(
                error_response(
                    detail=ApiMessage.EMAIL_TAKEN,
                    code=ApiCode.EMAIL_TAKEN,
                    errors={"new_email": [ApiMessage.EMAIL_TAKEN]},
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.email = new_email
        user.email_verified = False
        user.email_verified_at = None
        user.save(update_fields=["email", "email_verified", "email_verified_at"])

        logo_url = getattr(django_settings, "LOGO_URL", "") or ""
        send_verification_email(user, logo_url=logo_url)

        return Response(
            success_response(
                data={"email": user.email},
                detail="Email berhasil diperbarui. Kode verifikasi telah dikirim ke email baru.",
                code=ApiCode.SUCCESS,
            ),
            status=status.HTTP_200_OK,
        )
