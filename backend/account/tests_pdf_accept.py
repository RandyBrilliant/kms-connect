"""Mobile Dio sends Accept: application/pdf; DRF must not 406 those downloads."""

from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient

from account.models import ApplicantProfile, CustomUser, UserRole


class BiodataPdfAcceptHeaderTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = CustomUser.objects.create_user(
            email="pdf.pelamar@example.com",
            password="testpass123",
            role=UserRole.APPLICANT,
            full_name="Budi Santoso",
            is_active=True,
            email_verified=True,
        )
        ApplicantProfile.objects.create(
            user=self.user,
            contact_phone="081234567890",
            nik="1234567890123456",
        )
        self.client.force_authenticate(user=self.user)

    @patch(
        "account.applicant_self_service_views.cached_pdf_bytes",
        return_value=b"%PDF-1.4 mock-biodata",
    )
    def test_accept_pdf_returns_the_file_instead_of_406(self, _mock):
        url = reverse("account:applicant-me-biodata-pdf")
        response = self.client.get(url, HTTP_ACCEPT="application/pdf")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Content-Type"], "application/pdf")
        self.assertTrue(response.content.startswith(b"%PDF"))

    @patch(
        "account.applicant_self_service_views.cached_pdf_bytes",
        return_value=b"%PDF-1.4 mock-biodata",
    )
    def test_mobile_fallback_accept_returns_the_file(self, _mock):
        url = reverse("account:applicant-me-biodata-pdf")
        response = self.client.get(
            url,
            HTTP_ACCEPT="application/pdf, application/json;q=0.9",
        )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.content.startswith(b"%PDF"))

    @patch(
        "account.applicant_self_service_views.cached_pdf_bytes",
        return_value=b"%PDF-1.4 mock-cv",
    )
    def test_cv_pdf_accept_pdf_returns_the_file_instead_of_406(self, _mock):
        url = reverse("account:applicant-me-cv-pdf")
        response = self.client.get(url, HTTP_ACCEPT="application/pdf")
        self.assertEqual(response.status_code, 200)
        self.assertIn("application/pdf", response["Content-Type"])
        self.assertTrue(response.content.startswith(b"%PDF"))

    def test_referral_pdf_forbidden_with_accept_pdf_is_not_406(self):
        url = reverse("account:applicant-me-psychology-referral-pdf")
        response = self.client.get(url, HTTP_ACCEPT="application/pdf")
        self.assertEqual(response.status_code, 403)
        self.assertNotEqual(response.status_code, 406)
