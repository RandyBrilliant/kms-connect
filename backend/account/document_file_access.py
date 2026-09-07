"""
Authenticated access to the file behind an ApplicantDocument.

Mixed into the document viewsets so each one keeps its own permissions and
queryset scoping: get_object() only ever resolves documents the caller is
already allowed to see.

Two shapes are exposed because the clients differ:

  file/       302 to a signed URL. For browsers, which cannot attach an
              Authorization header to an <img> or a clicked link, and so
              authenticate with the HTTP-only cookie.

  file-url/   JSON {url, expires_in}. For clients that authenticate with a
              bearer token. They must not follow a redirect into Spaces with
              that header still attached — S3 rejects a request that carries
              both a presigned signature and an Authorization header — so they
              fetch the URL from here and request it with a clean client.
"""

from django.http import HttpResponseRedirect
from django.urls import NoReverseMatch, reverse
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound
from rest_framework.response import Response

from account.services.signed_media import signed_media_url, signed_url_ttl


def document_view_endpoint(applicant_user_id, document_pk, request=None) -> str | None:
    """
    Absolute URL of the file/ endpoint for one document.

    Returns the endpoint rather than a signed URL because the callers are places
    a URL has to keep working: a link in a rendered page and a cell in a
    downloaded spreadsheet both outlive a 15-minute signature. The endpoint
    re-signs on every request and only answers a caller allowed to see the
    document, so it is safe to persist.

    `applicant_user_id` is the CustomUser id, which is what the nested route
    matches on — not the ApplicantProfile pk.
    """
    if not applicant_user_id or not document_pk:
        return None
    try:
        path = reverse(
            "account:applicant-document-file",
            kwargs={"applicant_pk": applicant_user_id, "pk": document_pk},
        )
    except NoReverseMatch:
        return None
    return request.build_absolute_uri(path) if request is not None else path


class DocumentFileAccessMixin:
    """Adds file/ and file-url/ to a viewset over ApplicantDocument."""

    def _signed_file_url(self, expires_in: int | None = None) -> str:
        document = self.get_object()
        name = getattr(document.file, "name", "") or ""
        if not name:
            raise NotFound("Dokumen ini belum memiliki berkas.")
        url = signed_media_url(name, expires_in=expires_in)
        if not url:
            raise NotFound("Berkas dokumen tidak tersedia.")
        return url

    @action(detail=True, methods=["get"], url_path="file", url_name="file")
    def file_redirect(self, request, *args, **kwargs):
        response = HttpResponseRedirect(self._signed_file_url())
        # The redirect target is short-lived and per-user; never let a shared
        # cache or the browser hold on to it.
        response["Cache-Control"] = "private, no-store"
        return response

    @action(detail=True, methods=["get"], url_path="file-url", url_name="file-url")
    def file_url(self, request, *args, **kwargs):
        ttl = signed_url_ttl()
        response = Response({"url": self._signed_file_url(ttl), "expires_in": ttl})
        response["Cache-Control"] = "private, no-store"
        return response
