"""
Auth views that set JWT in HTTP-only cookies (web) and return user data.
Login and refresh set cookies; logout clears them.
CSRF exempt so SPA can POST without CSRF token (auth is JWT, not session).
"""
from django.conf import settings as django_settings
from django.utils import timezone
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from django.utils.module_loading import import_string
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.settings import api_settings as jwt_api_settings
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError

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
        "role": user.role,
        "is_active": user.is_active,
        "email_verified": user.email_verified,
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
        access = data["access"]
        refresh = data["refresh"]
        cookie_settings = _cookie_settings()

        response = Response(
            success_response(
                data={"user": _user_summary(user)},
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
        # Get user from refresh token payload for summary
        from rest_framework_simplejwt.tokens import RefreshToken
        from django.contrib.auth import get_user_model
        try:
            refresh_token = RefreshToken(refresh_raw)
            user_id = refresh_token.get(jwt_api_settings.USER_ID_CLAIM)
            user = get_user_model().objects.get(pk=user_id)
            user_data = _user_summary(user)
        except Exception:
            user_data = None

        response = Response(
            success_response(
                data={"user": user_data} if user_data else {},
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
# Public: verifikasi email (GET ?token=) & konfirmasi reset password (POST)
# ---------------------------------------------------------------------------

@method_decorator(csrf_exempt, name="dispatch")
class VerifyEmailView(APIView):
    """
    GET /api/auth/verify-email/?token=xxx → validasi token, set email_verified=True.
    Tidak perlu auth. Untuk link di email verifikasi.
    Throttled per IP (auth_public scope).
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
