"""
Short-lived signed URLs for applicant document objects.

Why a separate storage instance instead of default_storage.url():
django-storages only presigns when no custom domain is configured. With
AWS_S3_CUSTOM_DOMAIN set (the Spaces CDN), its url() takes the custom-domain
branch and returns a bare, permanent URL that carries no signature. Signing
also has to target the origin rather than the CDN, because a presigned
signature is computed over the request host and because the CDN would keep
serving a cached copy after the object turns private.

The TTL comes from settings.MEDIA_SIGNED_URL_TTL (seconds) and is passed on
every call, so overriding the setting in tests takes effect immediately.
"""

from django.conf import settings
from django.core.files.storage import default_storage

# Short by default: these URLs point at national ID cards, passports, and
# medical records, and they are re-issued on demand by an authenticated view.
DEFAULT_SIGNED_URL_TTL = 900

_signer = None


def signed_url_ttl() -> int:
    """Signed URL lifetime in seconds."""
    try:
        ttl = int(getattr(settings, "MEDIA_SIGNED_URL_TTL", DEFAULT_SIGNED_URL_TTL))
    except (TypeError, ValueError):
        return DEFAULT_SIGNED_URL_TTL
    return ttl if ttl > 0 else DEFAULT_SIGNED_URL_TTL


def uses_remote_storage() -> bool:
    """True when media lives in Spaces/S3 rather than on local disk."""
    return bool(getattr(default_storage, "bucket_name", None))


def _get_signer():
    """S3 storage configured for presigning against the origin."""
    global _signer
    if _signer is None:
        from storages.backends.s3boto3 import S3Boto3Storage

        _signer = S3Boto3Storage(
            custom_domain=None,
            querystring_auth=True,
            querystring_expire=signed_url_ttl(),
        )
    return _signer


def reset_signer_cache() -> None:
    """Drop the memoised signer. For tests that swap storage settings."""
    global _signer
    _signer = None


def signed_media_url(name: str, expires_in: int | None = None) -> str | None:
    """
    A URL for `name` that expires.

    On local disk storage there is nothing to sign, so the plain media URL is
    returned and callers behave the same in development.
    """
    if not name:
        return None
    if not uses_remote_storage():
        return default_storage.url(name)
    return _get_signer().url(name, expire=expires_in or signed_url_ttl())
