"""Authenticated, expiring access to applicant document files."""

import tempfile
from io import BytesIO

from django.core.files.base import ContentFile
from django.test import TestCase, override_settings
from django.urls import reverse
from PIL import Image
from rest_framework.test import APIClient

from account.models import (
    ApplicantDocument,
    ApplicantProfile,
    CustomUser,
    DocumentType,
    UserRole,
)
from account.services.signed_media import (
    DEFAULT_SIGNED_URL_TTL,
    signed_media_url,
    signed_url_ttl,
)


def _tiny_jpeg(name="ktp.jpg") -> ContentFile:
    buf = BytesIO()
    Image.new("RGB", (40, 30), color=(120, 120, 120)).save(buf, format="JPEG")
    return ContentFile(buf.getvalue(), name=name)


# Keep the suite off object storage. Without this, running with production
# settings would upload test fixtures into the live Spaces bucket.
local_media = override_settings(
    STORAGES={
        "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
        "staticfiles": {
            "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"
        },
    },
    MEDIA_ROOT=tempfile.mkdtemp(prefix="kms-test-media-"),
    MEDIA_URL="/media/",
)


@local_media
class SignedUrlTtlTests(TestCase):
    def test_defaults_to_fifteen_minutes(self):
        self.assertEqual(DEFAULT_SIGNED_URL_TTL, 900)

    @override_settings(MEDIA_SIGNED_URL_TTL=300)
    def test_reads_setting(self):
        self.assertEqual(signed_url_ttl(), 300)

    @override_settings(MEDIA_SIGNED_URL_TTL="not-a-number")
    def test_falls_back_when_setting_is_junk(self):
        self.assertEqual(signed_url_ttl(), DEFAULT_SIGNED_URL_TTL)

    @override_settings(MEDIA_SIGNED_URL_TTL=0)
    def test_rejects_non_positive_ttl(self):
        self.assertEqual(signed_url_ttl(), DEFAULT_SIGNED_URL_TTL)

    def test_blank_name_has_no_url(self):
        self.assertIsNone(signed_media_url(""))
        self.assertIsNone(signed_media_url(None))

    def test_local_storage_returns_plain_media_url(self):
        """Development runs on local disk, where there is nothing to sign."""
        self.assertEqual(signed_media_url("account/documents/1/ktp/x.jpg"),
                         "/media/account/documents/1/ktp/x.jpg")


@local_media
class DocumentFileAccessTests(TestCase):
    def setUp(self):
        # DRF is configured with JWT authentication only, so session login does
        # not apply; force_authenticate bypasses the auth class while still
        # exercising the permission classes.
        self.client = APIClient()
        self.doc_type = DocumentType.objects.create(code="ktp", name="KTP")

        self.applicant = CustomUser.objects.create_user(
            email="pelamar.doc@example.com",
            password="testpass123",
            role=UserRole.APPLICANT,
            full_name="Budi Santoso",
            is_active=True,
            email_verified=True,
        )
        self.profile = ApplicantProfile.objects.create(
            user=self.applicant,
            contact_phone="081234567890",
            nik="1234567890123456",
        )
        self.document = ApplicantDocument.objects.create(
            applicant_profile=self.profile,
            document_type=self.doc_type,
            file=_tiny_jpeg(),
        )

        self.other_applicant = CustomUser.objects.create_user(
            email="pelamar.lain@example.com",
            password="testpass123",
            role=UserRole.APPLICANT,
            full_name="Siti Aminah",
            is_active=True,
            email_verified=True,
        )
        self.other_profile = ApplicantProfile.objects.create(
            user=self.other_applicant,
            contact_phone="081200000000",
            nik="1234567890123457",
        )

        self.admin = CustomUser.objects.create_user(
            email="admin.doc@example.com",
            password="testpass123",
            role=UserRole.ADMIN,
            full_name="Admin Satu",
            is_active=True,
            email_verified=True,
        )

    def _admin_file_url_path(self, document=None):
        return reverse(
            "account:applicant-document-file-url",
            kwargs={
                "applicant_pk": (document or self.document).applicant_profile.user_id,
                "pk": (document or self.document).pk,
            },
        )

    def _admin_file_path(self):
        return reverse(
            "account:applicant-document-file",
            kwargs={
                "applicant_pk": self.document.applicant_profile.user_id,
                "pk": self.document.pk,
            },
        )

    # -- authentication ---------------------------------------------------

    def test_file_url_requires_authentication(self):
        response = self.client.get(self._admin_file_url_path())
        self.assertIn(response.status_code, (401, 403))

    def test_redirect_requires_authentication(self):
        response = self.client.get(self._admin_file_path())
        self.assertIn(response.status_code, (401, 403))

    def test_applicant_cannot_use_admin_route(self):
        self.client.force_authenticate(user=self.applicant)
        response = self.client.get(self._admin_file_url_path())
        self.assertIn(response.status_code, (401, 403))

    # -- admin access -----------------------------------------------------

    def test_admin_gets_url_and_ttl(self):
        self.client.force_authenticate(user=self.admin)
        response = self.client.get(self._admin_file_url_path())
        self.assertEqual(response.status_code, 200)
        self.assertIn("url", response.json())
        self.assertEqual(response.json()["expires_in"], signed_url_ttl())

    def test_admin_url_response_is_not_cacheable(self):
        self.client.force_authenticate(user=self.admin)
        response = self.client.get(self._admin_file_url_path())
        self.assertEqual(response["Cache-Control"], "private, no-store")

    def test_redirect_points_at_the_file_and_is_not_cacheable(self):
        self.client.force_authenticate(user=self.admin)
        response = self.client.get(self._admin_file_path())
        self.assertEqual(response.status_code, 302)
        self.assertIn("ktp", response["Location"])
        self.assertEqual(response["Cache-Control"], "private, no-store")

    def test_missing_file_is_reported_as_not_found(self):
        empty = ApplicantDocument.objects.create(
            applicant_profile=self.other_profile,
            document_type=DocumentType.objects.create(code="ijasah", name="Ijasah"),
            file="",
        )
        self.client.force_authenticate(user=self.admin)
        response = self.client.get(self._admin_file_url_path(empty))
        self.assertEqual(response.status_code, 404)

    # -- applicant self-service -------------------------------------------

    def test_applicant_can_reach_own_document(self):
        self.client.force_authenticate(user=self.applicant)
        path = reverse(
            "account:applicant-me-documents-file-url",
            kwargs={"pk": self.document.pk},
        )
        response = self.client.get(path)
        self.assertEqual(response.status_code, 200)
        self.assertIn("url", response.json())

    def test_applicant_cannot_reach_another_applicants_document(self):
        other_document = ApplicantDocument.objects.create(
            applicant_profile=self.other_profile,
            document_type=self.doc_type,
            file=_tiny_jpeg("ktp-lain.jpg"),
        )
        self.client.force_authenticate(user=self.applicant)
        path = reverse(
            "account:applicant-me-documents-file-url",
            kwargs={"pk": other_document.pk},
        )
        response = self.client.get(path)
        self.assertEqual(response.status_code, 404)

    # -- serializer -------------------------------------------------------

    def test_serializer_exposes_a_stable_access_url(self):
        self.client.force_authenticate(user=self.admin)
        list_path = reverse(
            "account:applicant-documents",
            kwargs={"applicant_pk": self.applicant.pk},
        )
        response = self.client.get(list_path)
        self.assertEqual(response.status_code, 200)

        payload = response.json()
        rows = payload if isinstance(payload, list) else payload.get("results", [])
        row = next(r for r in rows if r["id"] == self.document.pk)

        self.assertIn("file_access_url", row)
        self.assertTrue(row["file_access_url"].endswith(self._admin_file_url_path()))
