"""CV PDF generation using the official CPMI template."""

from datetime import date
from io import BytesIO

from django.core.files.base import ContentFile
from django.test import TestCase
from PIL import Image

from account.models import ApplicantProfile, CustomUser, UserRole, WorkExperience
from account.services.cv_pdf import cv_pdf_http_response, generate_cv_pdf


def _tiny_jpeg() -> ContentFile:
    buf = BytesIO()
    Image.new("RGB", (90, 120), color=(180, 140, 100)).save(buf, format="JPEG")
    return ContentFile(buf.getvalue(), name="pasfoto.jpg")


class CvPdfTests(TestCase):
    def test_generate_cv_pdf_includes_profile_fields_and_photo(self):
        user = CustomUser.objects.create_user(
            email="cvpelamar@example.com",
            password="testpass123",
            role=UserRole.APPLICANT,
            full_name="Budi Santoso",
            is_active=True,
            email_verified=True,
        )
        profile = ApplicantProfile.objects.create(
            user=user,
            contact_phone="081234567890",
            birth_place_text="PEMATANGSIANTAR",
            birth_date=date(1998, 5, 17),
            address="JL. MERDEKA NO. 10",
            education_level="SMK",
            education_major="TEKNIK MESIN",
            has_passport=True,
        )
        profile.photo.save("pasfoto.jpg", _tiny_jpeg(), save=True)
        WorkExperience.objects.create(
            applicant_profile=profile,
            company_name="PT MAJU JAYA",
            position="Operator",
            location="Medan",
            start_date=date(2020, 1, 1),
            end_date=date(2023, 6, 30),
        )

        pdf = generate_cv_pdf(profile)
        self.assertTrue(pdf.startswith(b"%PDF"))
        self.assertGreater(len(pdf), 20_000)
        # Raster template + photo should keep the file reasonably large.
        self.assertIn(b"/XObject", pdf)

    def test_generate_cv_pdf_uses_template_when_photo_is_unreadable(self):
        user = CustomUser.objects.create_user(
            email="cvbadphoto@example.com",
            password="testpass123",
            role=UserRole.APPLICANT,
            full_name="Siti Aminah",
            is_active=True,
            email_verified=True,
        )
        profile = ApplicantProfile.objects.create(
            user=user,
            contact_phone="081298765432",
        )
        profile.photo.save(
            "pasfoto.jpg",
            ContentFile(b"not-a-valid-image", name="pasfoto.jpg"),
            save=True,
        )

        pdf = generate_cv_pdf(profile)
        self.assertTrue(pdf.startswith(b"%PDF"))
        self.assertGreater(len(pdf), 20_000)

    def test_cv_pdf_http_response_disables_caching(self):
        response = cv_pdf_http_response(b"%PDF-1.4 test", "Budi Santoso")
        self.assertEqual(
            response["Cache-Control"],
            "no-store, no-cache, must-revalidate, max-age=0",
        )
        self.assertIn("CV_Budi_Santoso_", response["Content-Disposition"])
        self.assertIn(".pdf", response["Content-Disposition"])
