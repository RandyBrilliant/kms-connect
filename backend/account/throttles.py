"""
Rate limiting for account/auth endpoints.
Stricter limits for login, verify-email, and password reset to prevent abuse.
"""
from rest_framework.throttling import SimpleRateThrottle


class AuthRateThrottle(SimpleRateThrottle):
    """
    Stricter throttle for auth endpoints (login, refresh).
    Scope: auth (e.g. 10/min per IP).
    """
    scope = "auth"

    def get_cache_key(self, request, view):
        if request.user and request.user.is_authenticated:
            return None
        return self.cache_format % {
            "scope": self.scope,
            "ident": self.get_ident(request),
        }


class AuthPublicRateThrottle(SimpleRateThrottle):
    """
    Throttle for public auth endpoints (verify-email, confirm-reset-password).
    Scope: auth_public (e.g. 5/min per IP).
    """
    scope = "auth_public"

    def get_cache_key(self, request, view):
        return self.cache_format % {
            "scope": self.scope,
            "ident": self.get_ident(request),
        }
