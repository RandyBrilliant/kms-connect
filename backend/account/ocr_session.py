"""
Short-lived, IP-bound tokens for KTP OCR preview during registration.

Prevents unauthenticated abuse of Google Cloud Vision (cost) while keeping
the mobile registration / social-complete flow workable without login.
"""
import secrets

from django.conf import settings
from django.core.cache import cache
from django.core.signing import BadSignature, SignatureExpired, TimestampSigner

_OCR_SIGNER = TimestampSigner(salt="kms-ktp-ocr-preview-v1")


def _max_age_seconds() -> int:
    return int(getattr(settings, "OCR_PREVIEW_SESSION_MAX_AGE_SECONDS", 900))


def _issue_limit_per_hour() -> int:
    return int(getattr(settings, "OCR_PREVIEW_SESSION_ISSUE_LIMIT_PER_HOUR", 10))


def get_client_ip(request) -> str:
    """Client IP for rate limits and token binding (honours X-Forwarded-For)."""
    xff = request.META.get("HTTP_X_FORWARDED_FOR")
    if xff:
        return xff.split(",")[0].strip()
    return request.META.get("REMOTE_ADDR", "") or "unknown"


def is_mobile_client(request) -> bool:
    return request.META.get("HTTP_X_CLIENT_TYPE", "").lower() == "mobile"


def issue_ocr_session_token(request) -> str | None:
    """
    Create a signed OCR session token bound to the request IP.
    Returns None if the hourly issue limit for this IP is exceeded.
    """
    ip = get_client_ip(request)
    issue_key = f"ocr_session_issue:{ip}"
    issued = cache.get(issue_key, 0)
    if issued >= _issue_limit_per_hour():
        return None

    nonce = secrets.token_urlsafe(16)
    signed = _OCR_SIGNER.sign(f"{ip}:{nonce}")
    cache.set(issue_key, issued + 1, timeout=3600)
    return signed


def validate_and_consume_ocr_session_token(request, token: str) -> bool:
    """
    Verify token signature, IP binding, expiry, and one-time use.
    """
    if not token or not token.strip():
        return False

    token = token.strip()
    ip = get_client_ip(request)

    try:
        payload = _OCR_SIGNER.unsign(token, max_age=_max_age_seconds())
    except (BadSignature, SignatureExpired):
        return False

    if not payload.startswith(f"{ip}:"):
        return False

    used_key = f"ocr_session_used:{token}"
    if cache.get(used_key):
        return False

    cache.set(used_key, 1, timeout=_max_age_seconds())
    return True
