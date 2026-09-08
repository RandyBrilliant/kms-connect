"""DRF renderers for endpoints that return PDF (or other binary) bytes.

Django REST Framework content-negotiates *before* the view runs. The default
renderers only advertise JSON/HTML, so a client that sends
``Accept: application/pdf`` (the shipped mobile app) gets HTTP 406 and the
PDF is never generated.

Register ``PDFRenderer`` on those views. Successful downloads still return a
Django ``HttpResponse`` (renderer is skipped); this class only exists so
negotiation succeeds. Error payloads stay JSON.
"""

from rest_framework.renderers import BaseRenderer, JSONRenderer


class PDFRenderer(BaseRenderer):
    media_type = "application/pdf"
    format = "pdf"
    charset = None
    render_style = "binary"

    def render(self, data, accepted_media_type=None, renderer_context=None):
        if data is None:
            return b""
        if isinstance(data, (bytes, bytearray, memoryview)):
            return bytes(data)
        # 4xx/5xx bodies are dicts; keep them JSON so Dio can still parse them.
        return JSONRenderer().render(data, accepted_media_type, renderer_context)


class PdfBinaryViewMixin:
    renderer_classes = [JSONRenderer, PDFRenderer]
