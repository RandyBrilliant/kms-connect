"""Bukti Penyerahan Dokumen PDF (3 pages, pre-filled) and its endpoints."""

import re
from datetime import date

from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient

from account.models import ApplicantProfile, CustomUser, UserRole
from account.services.bukti_penyerahan_pdf import generate_bukti_penyerahan_pdf
from account.tests_cv_pdf import _pdf_text
from main.models import ApplicationStatus, JobApplication, LowonganKerja


class BuktiPenyerahanPdfTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.staff = CustomUser.objects.create_user(
            email="staff.rekrut@example.com",
            password="testpass123",
            role=UserRole.STAFF,
            full_name="Rina Perekrut",
        )
        self.user = CustomUser.objects.create_user(
            email="pelamar.bukti@example.com",
            password="testpass123",
            role=UserRole.APPLICANT,
            full_name="Siti Aminah",
            is_active=True,
            email_verified=True,
        )
        self.profile = ApplicantProfile.objects.create(
            user=self.user,
            contact_phone="081234567890",
            nik="1271034512990001",
            birth_place_text="MEDAN",
            birth_date=date(1999, 12, 5),
            address="JL. PERJUANGAN NO. 12\nMEDAN",
            referrer=self.staff,
        )
        self.job = LowonganKerja.objects.create(title="Operator Kilang", slug="operator-kilang")
        self.admin = CustomUser.objects.create_user(
            email="admin.bukti@example.com",
            password="testpass123",
            role=UserRole.ADMIN,
            full_name="Admin Satu",
            is_active=True,
            email_verified=True,
        )

    def test_generate_has_three_pages_with_profile_fields(self):
        JobApplication.objects.create(
            applicant=self.profile, job=self.job, status=ApplicationStatus.DITERIMA
        )
        pdf = generate_bukti_penyerahan_pdf(self.profile)

        self.assertTrue(pdf.startswith(b"%PDF"))
        self.assertEqual(len(re.findall(rb"/Type /Page\b", pdf)), 3)
        text = _pdf_text(pdf)
        for expected in (
            b"Siti Aminah",
            b"1271034512990001",
            b"MEDAN, 05/12/1999",
            b"JL. PERJUANGAN NO. 12 MEDAN",
            b"Rina Perekrut",
            b"Operator Kilang",
        ):
            self.assertIn(expected, text)

    def test_applicant_endpoint_requires_lulus_interview(self):
        url = reverse("account:applicant-me-bukti-penyerahan-pdf")
        self.client.force_authenticate(user=self.user)

        JobApplication.objects.create(
            applicant=self.profile, job=self.job, status=ApplicationStatus.INTERVIEW
        )
        self.assertEqual(self.client.get(url).status_code, 403)

        JobApplication.objects.filter(applicant=self.profile).update(
            status=ApplicationStatus.DITERIMA
        )
        response = self.client.get(url, HTTP_ACCEPT="application/pdf")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Content-Type"], "application/pdf")
        self.assertIn("Bukti_Penyerahan_Dokumen_Siti_Aminah.pdf", response["Content-Disposition"])

    def test_admin_endpoint(self):
        url = reverse(
            "account:applicant-bukti-penyerahan-pdf", kwargs={"pk": self.user.pk}
        )
        self.client.force_authenticate(user=self.user)
        self.assertEqual(self.client.get(url).status_code, 403)

        self.client.force_authenticate(user=self.admin)
        response = self.client.get(url, HTTP_ACCEPT="application/pdf")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.content.startswith(b"%PDF"))
