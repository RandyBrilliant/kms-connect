"""DRF renderers for endpoints that return binary files (PDF, ZIP, XLSX).

Django REST Framework content-negotiates *before* the view runs. The default
renderers only advertise JSON/HTML, so a client that sends a file Accept
header (the shipped mobile app sends ``Accept: application/pdf``) gets HTTP
406 and the file is never generated.

These renderers exist so negotiation succeeds. Successful downloads still
return a Django ``HttpResponse`` (the renderer is skipped). Error payloads
stay JSON. ``IgnoreAcceptContentNegotiation`` is extra insurance: even an
unknown Accept header will not 406.
"""

from rest_framework.negotiation import BaseContentNegotiation
from rest_framework.renderers import BaseRenderer, JSONRenderer


class IgnoreAcceptContentNegotiation(BaseContentNegotiation):
    def select_parser(self, request, parsers):
        return parsers[0]

    def select_renderer(self, request, renderers, format_suffix):
        return (renderers[0], renderers[0].media_type)


class _PassthroughBinaryRenderer(BaseRenderer):
    charset = None
    render_style = "binary"

    def render(self, data, accepted_media_type=None, renderer_context=None):
        if data is None:
            return b""
        if isinstance(data, (bytes, bytearray, memoryview)):
            return bytes(data)
        return JSONRenderer().render(data, accepted_media_type, renderer_context)


class PDFRenderer(_PassthroughBinaryRenderer):
    media_type = "application/pdf"
    format = "pdf"


class ZipRenderer(_PassthroughBinaryRenderer):
    media_type = "application/zip"
    format = "zip"


class XlsxRenderer(_PassthroughBinaryRenderer):
    media_type = (
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    format = "xlsx"


BINARY_DOWNLOAD_RENDERERS = [JSONRenderer, PDFRenderer, ZipRenderer, XlsxRenderer]

BINARY_DOWNLOAD_ACTION = {
    "renderer_classes": BINARY_DOWNLOAD_RENDERERS,
    "content_negotiation_class": IgnoreAcceptContentNegotiation,
}


class PdfBinaryViewMixin:
    renderer_classes = BINARY_DOWNLOAD_RENDERERS
    content_negotiation_class = IgnoreAcceptContentNegotiation
