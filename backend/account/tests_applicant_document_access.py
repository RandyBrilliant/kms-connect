"""Which document types a pelamar sees in the upload checklist, per lamaran stage."""

from django.test import TestCase
from django.utils import timezone

from account.models import ApplicantProfile, CustomUser, DocumentType, UserRole
from account.services.applicant_document_access import (
    BUKTI_PENYERAHAN_CODE,
    get_applicant_document_types_queryset,
)
from main.models import ApplicationStatus, JobApplication, LowonganKerja

INITIAL = DocumentType.PHASE_INITIAL
POST = DocumentType.PHASE_POST_INTERVIEW


class ApplicantDocumentTypeVisibilityTests(TestCase):
    def setUp(self):
        # Migrations seed the real types; pin a small known set for these tests.
        DocumentType.objects.all().delete()
        for code, phase in (
            ("ktp", INITIAL),
            ("pas-foto", INITIAL),
            (BUKTI_PENYERAHAN_CODE, POST),
            ("ijin-keluarga", POST),
            ("surat-kesehatan", POST),
        ):
            DocumentType.objects.create(code=code, name=code, phase=phase)

        user = CustomUser.objects.create_user(
            email="pelamar.stage@example.com",
            password="testpass123",
            role=UserRole.APPLICANT,
        )
        self.profile = ApplicantProfile.objects.create(
            user=user,
            contact_phone="081234567890",
            nik="1234567890123457",
        )
        self.job = LowonganKerja.objects.create(title="Operator", slug="operator")

    def _apply(self, status, **extra):
        return JobApplication.objects.create(
            applicant=self.profile, job=self.job, status=status, **extra
        )

    def _codes(self):
        return set(
            get_applicant_document_types_queryset(self.profile).values_list(
                "code", flat=True
            )
        )

    def test_no_lamaran_sees_initial_only(self):
        self.assertEqual(self._codes(), {"ktp", "pas-foto"})

    def test_confirmed_pra_seleksi_does_not_unlock_post_interview(self):
        self._apply(
            ApplicationStatus.PRA_SELEKSI, pra_seleksi_confirmed_at=timezone.now()
        )
        self.assertEqual(self._codes(), {"ktp", "pas-foto"})

    def test_interview_adds_bukti_penyerahan_only(self):
        self._apply(
            ApplicationStatus.INTERVIEW, pra_seleksi_confirmed_at=timezone.now()
        )
        self.assertEqual(self._codes(), {"ktp", "pas-foto", BUKTI_PENYERAHAN_CODE})

    def test_diterima_sees_all_types(self):
        self._apply(ApplicationStatus.DITERIMA)
        self.assertEqual(
            self._codes(),
            {
                "ktp",
                "pas-foto",
                BUKTI_PENYERAHAN_CODE,
                "ijin-keluarga",
                "surat-kesehatan",
            },
        )
