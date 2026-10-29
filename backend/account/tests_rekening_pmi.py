"""Data Rekening PMI: bank (fixed list), nama penerima, nomor rekening (angka saja)."""

from django.test import TestCase
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APIClient

from account.models import (
    ApplicantProfile,
    ApplicantVerificationStatus,
    CustomUser,
    IndonesianBank,
    UserRole,
)
from main.models import ApplicationStatus, JobApplication, LowonganKerja


class RekeningPmiTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = CustomUser.objects.create_user(
            email="pelamar.rekening@example.com",
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
        )
        self.url = reverse(
            "account:applicant-me-profile-detail", kwargs={"pk": self.profile.pk}
        )
        self.client.force_authenticate(user=self.user)
        self.job = LowonganKerja.objects.create(title="Operator", slug="operator")
        self.application = JobApplication.objects.create(
            applicant=self.profile, job=self.job, status=ApplicationStatus.DITERIMA
        )

    def _rekening(self):
        return {
            "bank": "BRI",
            "bank_account_holder": "siti aminah",
            "no_rek": "002101000123456",
        }

    def test_rekening_locked_until_lulus_interview(self):
        self.application.status = ApplicationStatus.INTERVIEW
        self.application.save()
        self.assertFalse(self.client.get(self.url).json()["data"]["has_lulus_interview"])
        response = self.client.patch(self.url, self._rekening(), format="json")
        self.assertEqual(response.status_code, 400)
        # Other biodata stays editable before the interview result.
        response = self.client.patch(self.url, {"address": "JL. MERDEKA"}, format="json")
        self.assertEqual(response.status_code, 200, response.content)

    def test_accepted_profile_can_still_save_rekening_only(self):
        self.profile.verification_status = ApplicantVerificationStatus.ACCEPTED
        self.profile.verified_at = timezone.now()
        self.profile.save()
        self.assertTrue(self.client.get(self.url).json()["data"]["has_lulus_interview"])

        response = self.client.patch(self.url, self._rekening(), format="json")
        self.assertEqual(response.status_code, 200, response.content)
        self.profile.refresh_from_db()
        self.assertEqual(self.profile.no_rek, "002101000123456")

        response = self.client.patch(
            self.url, {**self._rekening(), "address": "JL. LAIN"}, format="json"
        )
        self.assertEqual(response.status_code, 400)

    def test_applicant_can_save_rekening(self):
        response = self.client.patch(
            self.url,
            {
                "bank": "BRI",
                "bank_account_holder": "siti aminah",
                "no_rek": "002101000123456",
            },
            format="json",
        )
        self.assertEqual(response.status_code, 200, response.content)
        self.profile.refresh_from_db()
        self.assertEqual(self.profile.bank, IndonesianBank.BRI)
        self.assertEqual(self.profile.bank_account_holder, "SITI AMINAH")
        self.assertEqual(self.profile.no_rek, "002101000123456")

    def test_no_rek_must_be_digits(self):
        response = self.client.patch(
            self.url, {"no_rek": "0021-0100"}, format="json"
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("no_rek", response.content.decode())

    def test_bank_must_be_from_list(self):
        response = self.client.patch(
            self.url, {"bank": "BANK ENTAH"}, format="json"
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("bank", response.content.decode())

    def test_excel_export_has_bank_name_holder_and_number(self):
        from openpyxl import load_workbook

        from account.services.export import generate_applicants_excel

        self.profile.bank = IndonesianBank.SUMUT
        self.profile.bank_account_holder = "SITI AMINAH"
        self.profile.no_rek = "1234567890"
        self.profile.save()

        queryset = CustomUser.objects.filter(pk=self.user.pk).select_related(
            "applicant_profile__user"
        )
        sheet = load_workbook(generate_applicants_excel(queryset)).active
        header = [cell.value for cell in sheet[1]]
        row = dict(zip(header, [cell.value for cell in sheet[2]]))

        self.assertEqual(row["Bank"], "Bank Sumut")
        self.assertEqual(row["Nama Penerima Rekening"], "SITI AMINAH")
        self.assertEqual(row["No. Rekening"], "1234567890")
