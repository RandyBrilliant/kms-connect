"""
JWT authentication with HTTP-only cookie support for web.
Tries Authorization: Bearer first (mobile), then access token from cookie (web).
Cookie names and options come from settings.SIMPLE_JWT (AUTH_COOKIE_*).
"""
from django.conf import settings as django_settings
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.settings import api_settings as jwt_api_settings


def _cookie_settings():
    """Read cookie-related keys from SIMPLE_JWT (custom, not in SimpleJWT defaults)."""
    s = getattr(django_settings, "SIMPLE_JWT", {}) or {}
    return {
        "access_key": s.get("AUTH_COOKIE_ACCESS_KEY") or "kms_access",
        "refresh_key": s.get("AUTH_COOKIE_REFRESH_KEY") or "kms_refresh",
        "secure": s.get("AUTH_COOKIE_SECURE", False),
        "httponly": s.get("AUTH_COOKIE_HTTP_ONLY", True),
        "samesite": s.get("AUTH_COOKIE_SAMESITE") or "Lax",
        "path": s.get("AUTH_COOKIE_PATH") or "/",
    }


class JWTCookieAuthentication(JWTAuthentication):
    """
    Authenticate via JWT from Authorization header (Bearer) or from HTTP-only cookie.
    Header takes precedence (for mobile); cookie is used when no header is sent (web).
    """

    def authenticate(self, request):
        # 1) Try Authorization header (mobile / API clients)
        auth = super().authenticate(request)
        if auth is not None:
            return auth

        # 2) Try access token from cookie (web)
        cookie_settings = _cookie_settings()
        access_key = cookie_settings["access_key"]
        raw = request.COOKIES.get(access_key)
        if not raw:
            return None

        try:
            raw_token = raw.encode("utf-8") if isinstance(raw, str) else raw
            validated_token = self.get_validated_token(raw_token)
        except Exception:
            return None

        user = self.get_user(validated_token)
        return (user, validated_token)
