"""
Extract JWT access tokens for WebSocket handshake (no query-string tokens).

Supported (in order):
  1. Sec-WebSocket-Protocol: kms-auth, <access_jwt>  (mobile + web)
  2. Cookie: kms_access=<jwt>  (web, HTTP-only cookie on upgrade)
  3. Authorization: Bearer <jwt>  (optional, non-browser clients)
"""
from __future__ import annotations

import logging
from http.cookies import SimpleCookie

from django.conf import settings as django_settings

logger = logging.getLogger(__name__)

WS_AUTH_PROTOCOL = "kms-auth"


def _cookie_access_key() -> str:
    jwt_settings = getattr(django_settings, "SIMPLE_JWT", {}) or {}
    return jwt_settings.get("AUTH_COOKIE_ACCESS_KEY") or "kms_access"


def _header_value(scope, name: str) -> str | None:
    name_bytes = name.lower().encode("ascii")
    for key, value in scope.get("headers", []):
        if key.lower() == name_bytes:
            return value.decode("latin-1")
    return None


def _token_from_subprotocols(subprotocols: list[str]) -> str | None:
    if len(subprotocols) >= 2 and subprotocols[0] == WS_AUTH_PROTOCOL:
        token = subprotocols[1].strip()
        return token or None
    return None


def _token_from_cookie_header(cookie_header: str) -> str | None:
    jar = SimpleCookie()
    jar.load(cookie_header)
    access_key = _cookie_access_key()
    morsel = jar.get(access_key)
    if morsel is None:
        return None
    token = morsel.value.strip()
    return token or None


def _token_from_authorization(auth_header: str) -> str | None:
    parts = auth_header.split()
    if len(parts) == 2 and parts[0].lower() == "bearer":
        token = parts[1].strip()
        return token or None
    return None


def extract_ws_access_token(scope) -> str | None:
    """
    Return a raw JWT access token from the WebSocket handshake, or None.
    """
    subprotocols = scope.get("subprotocols") or []
    token = _token_from_subprotocols(subprotocols)
    if token:
        return token

    cookie_header = _header_value(scope, "cookie")
    if cookie_header:
        token = _token_from_cookie_header(cookie_header)
        if token:
            return token

    auth_header = _header_value(scope, "authorization")
    if auth_header:
        token = _token_from_authorization(auth_header)
        if token:
            return token

    # Deprecated — reject silently (do not log query values; may contain secrets)
    query_string = scope.get("query_string", b"").decode("utf-8")
    if query_string and "token=" in query_string:
        logger.warning(
            "WebSocket chat rejected legacy ?token= query auth from %s",
            scope.get("client"),
        )

    return None


def negotiated_subprotocol(scope) -> str | None:
    """Subprotocol to return from accept(), if client offered kms-auth."""
    subprotocols = scope.get("subprotocols") or []
    if subprotocols and subprotocols[0] == WS_AUTH_PROTOCOL:
        return WS_AUTH_PROTOCOL
    return None
