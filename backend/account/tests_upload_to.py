"""B18: document object keys must not contain name or NIK."""

import re

from django.test import TestCase

from account.models import (
    ApplicantDocument,
    ApplicantProfile,
    CustomUser,
    DocumentType,
    UserRole,
    applicant_document_upload_to,
)

OPAQUE_NAME = re.compile(r"^[0-9a-f]{32}\.jpg$")


class UploadToOpaqueKeyTests(TestCase):
    def setUp(self):
        self.user = CustomUser.objects.create_user(
            email="upload-key@example.com",
            password="testpass123",
            role=UserRole.APPLICANT,
            full_name="Budi Santoso",
        )
        self.profile = ApplicantProfile.objects.create(
            user=self.user,
            contact_phone="081234567890",
            nik="1234567890123456",
        )
        self.doc_type = DocumentType.objects.create(code="ktp", name="KTP")

    def test_key_is_opaque_and_keeps_only_the_extension(self):
        doc = ApplicantDocument(
            applicant_profile=self.profile,
            document_type=self.doc_type,
        )
        path = applicant_document_upload_to(doc, "scan KTP.JPG")
        self.assertEqual(
            path.rsplit("/", 1)[0],
            f"account/documents/{self.profile.id}/ktp",
        )
        filename = path.rsplit("/", 1)[-1]
        self.assertRegex(filename, OPAQUE_NAME)
        self.assertNotIn("budi", path.lower())
        self.assertNotIn("santoso", path.lower())
        self.assertNotIn("3456", path)
        self.assertNotRegex(filename, r"^[0-9a-f]{16}-")
