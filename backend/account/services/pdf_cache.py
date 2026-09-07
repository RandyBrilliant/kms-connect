"""
Cache rendered applicant PDFs so repeat downloads do not pin a gunicorn worker.

A cold GET still renders in-request: mobile and admin expect a PDF body, not
202 + a job id. The cache makes the common case (re-download, staff opening
the same CV twice) cheap.
"""

from django.core.cache import cache

PDF_CACHE_TTL = 600


def _fingerprint(profile) -> str:
    parts = [str(getattr(profile, "pk", "")), str(getattr(profile, "updated_at", "") or "")]
    user = getattr(profile, "user", None)
    if user is not None:
        parts.append(str(getattr(user, "updated_at", "") or ""))

    docs = getattr(profile, "_prefetched_objects_cache", {}).get("documents")
    if docs is None:
        try:
            docs = list(profile.documents.all())
        except Exception:
            docs = []
    if docs:
        parts.append(str(len(docs)))
        latest = max((getattr(d, "uploaded_at", None) for d in docs), default=None)
        parts.append(str(latest or ""))

    works = getattr(profile, "_prefetched_objects_cache", {}).get("work_experiences")
    if works is None:
        try:
            works = list(profile.work_experiences.all())
        except Exception:
            works = []
    if works:
        parts.append(str(len(works)))
    return ":".join(parts)


def cached_pdf_bytes(kind: str, profile, renderer) -> bytes:
    key = f"pdf:{kind}:{_fingerprint(profile)}"
    hit = cache.get(key)
    if isinstance(hit, (bytes, bytearray)) and hit:
        return bytes(hit)
    pdf = renderer(profile)
    if pdf:
        cache.set(key, pdf, PDF_CACHE_TTL)
    return pdf
