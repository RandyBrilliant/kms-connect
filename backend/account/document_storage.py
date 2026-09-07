"""
Storage for the file behind an ApplicantDocument.

Bound to ApplicantDocument.file so new uploads land private and are reachable
only through the expiring signed URLs issued by the document file endpoints.

This is deliberately scoped to one field rather than done with AWS_DEFAULT_ACL:
the same bucket serves public website images under main/news/, and it is shared
with an unrelated project, so a global flip would break things outside this app.

Existing objects are untouched. They keep the ACL they were written with until
they are backfilled separately; this only governs what happens from now on.

Named document_storage rather than storages to avoid confusion with the
django-storages package, which is imported as `storages`.
"""

from django.conf import settings
from django.core.files.storage import default_storage

from account.services.signed_media import signed_url_ttl

_storage = None


def remote_storage_configured() -> bool:
    """
    True when Spaces is active.

    AWS_STORAGE_BUCKET_NAME is only defined when DO_SPACES_BUCKET_NAME is set
    and DEBUG is off, so its presence is the signal for "not on local disk".
    """
    return bool(getattr(settings, "AWS_STORAGE_BUCKET_NAME", None))


def private_document_storage():
    """
    Storage instance for ApplicantDocument.file.

    FileField calls this once, when the model class is defined.

    On local disk this returns `default_storage` itself rather than resolving
    it, so it stays a lazy proxy and override_settings(STORAGES=...) keeps
    working in tests. Development and the test suite are unaffected by any of
    the S3 behaviour below.
    """
    global _storage
    if not remote_storage_configured():
        return default_storage

    if _storage is None:
        from storages.backends.s3boto3 import S3Boto3Storage

        _storage = S3Boto3Storage(
            # New objects are private. Nothing reads them by object URL any
            # more; every consumer goes through the file/ endpoint.
            default_acl="private",
            # Sign against the origin, not the CDN. A signature is computed
            # over the request host, and the CDN would otherwise keep serving
            # a cached copy of an object that has since become private.
            custom_domain=None,
            querystring_auth=True,
            querystring_expire=signed_url_ttl(),
            # Overrides the global max-age=86400. Caching a private document
            # at a shared edge for a day is what forced a CDN purge after the
            # legacy keys were rewritten.
            object_parameters={"CacheControl": "private, max-age=0, no-store"},
        )
    return _storage


def reset_storage_cache() -> None:
    """Drop the memoised storage. For tests that swap storage settings."""
    global _storage
    _storage = None
