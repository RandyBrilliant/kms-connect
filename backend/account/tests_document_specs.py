"""B6/B7: document upload validation (magic bytes + fail-closed unknown types)."""

from io import BytesIO

from django.core.exceptions import ValidationError
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from PIL import Image

from account.document_specs import sniff_file_kind, validate_document_file


def _jpeg(name="ktp.jpg") -> SimpleUploadedFile:
    buf = BytesIO()
    Image.new("RGB", (40, 30), color=(80, 80, 80)).save(buf, format="JPEG")
    return SimpleUploadedFile(name, buf.getvalue(), content_type="image/jpeg")


def _png(name="ktp.png") -> SimpleUploadedFile:
    buf = BytesIO()
    Image.new("RGB", (40, 30), color=(80, 80, 80)).save(buf, format="PNG")
    return SimpleUploadedFile(name, buf.getvalue(), content_type="image/png")


def _pdf(name="cv.pdf") -> SimpleUploadedFile:
    return SimpleUploadedFile(
        name, b"%PDF-1.4\n1 0 obj\n<<>>\nendobj\n%%EOF\n", content_type="application/pdf"
    )


class SniffFileKindTests(TestCase):
    def test_jpeg_png_pdf(self):
        self.assertEqual(sniff_file_kind(_jpeg()), "jpeg")
        self.assertEqual(sniff_file_kind(_png()), "png")
        self.assertEqual(sniff_file_kind(_pdf()), "pdf")

    def test_html_is_not_an_image(self):
        html = SimpleUploadedFile(
            "ktp.jpg", b"<html><script>alert(1)</script></html>", content_type="image/jpeg"
        )
        self.assertIsNone(sniff_file_kind(html))


class ValidateDocumentFileTests(TestCase):
    def test_unknown_type_is_rejected(self):
        with self.assertRaises(ValidationError) as caught:
            validate_document_file(_jpeg(), "bukan-tipe")
        self.assertEqual(caught.exception.code, "unknown_document_type")

    def test_blank_type_is_rejected(self):
        with self.assertRaises(ValidationError) as caught:
            validate_document_file(_jpeg(), "")
        self.assertEqual(caught.exception.code, "unknown_document_type")

    def test_html_named_as_jpg_is_rejected(self):
        html = SimpleUploadedFile(
            "ktp.jpg", b"<html><body>nope</body></html>", content_type="image/jpeg"
        )
        with self.assertRaises(ValidationError) as caught:
            validate_document_file(html, "ktp")
        self.assertEqual(caught.exception.code, "invalid_content")

    def test_jpeg_named_as_pdf_is_rejected(self):
        with self.assertRaises(ValidationError) as caught:
            validate_document_file(_jpeg("cv.pdf"), "cv")
        self.assertEqual(caught.exception.code, "invalid_content")

    def test_pdf_extension_rejected_for_image_type(self):
        with self.assertRaises(ValidationError) as caught:
            validate_document_file(_jpeg("ktp.pdf"), "ktp")
        self.assertEqual(caught.exception.code, "invalid_format")

    def test_real_ktp_jpeg_is_accepted(self):
        validate_document_file(_jpeg(), "ktp")

    def test_real_cv_pdf_is_accepted(self):
        validate_document_file(_pdf(), "cv")
