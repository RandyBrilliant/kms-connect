"""Merge leftover pas-photo DocumentType into canonical pas-foto without deleting files."""

from io import BytesIO

from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.test import TestCase
from PIL import Image

from account.models import (
    ApplicantDocument,
    ApplicantProfile,
    CustomUser,
    DocumentReviewStatus,
    DocumentType,
    UserRole,
)
from account.services.merge_pas_photo import merge_pas_photo_into_pas_foto


def _jpeg(name="photo.jpg") -> ContentFile:
    buf = BytesIO()
    Image.new("RGB", (20, 20), color=(90, 90, 90)).save(buf, format="JPEG")
    return ContentFile(buf.getvalue(), name=name)


def _profile(email: str, nik: str) -> ApplicantProfile:
    user = CustomUser.objects.create_user(
        email=email,
        password="testpass123",
        role=UserRole.APPLICANT,
        full_name="Tes Pelamar",
    )
    return ApplicantProfile.objects.create(user=user, nik=nik, contact_phone="081234567890")


def _attach(profile, doc_type, name, status=DocumentReviewStatus.PENDING) -> ApplicantDocument:
    doc = ApplicantDocument(
        applicant_profile=profile,
        document_type=doc_type,
        review_status=status,
    )
    doc.file.save(name, _jpeg(name), save=True)
    return doc


class MergePasPhotoTests(TestCase):
    def setUp(self):
        self.pas_foto, _ = DocumentType.objects.get_or_create(
            code="pas-foto",
            defaults={
                "name": "Pas Foto",
                "is_required": True,
                "sort_order": 6,
                "description": "",
            },
        )
        self.pas_foto.name = "Pas Foto"
        self.pas_foto.description = ""
        self.pas_foto.is_required = True
        self.pas_foto.sort_order = 6
        self.pas_foto.save()
        self.pas_photo, _ = DocumentType.objects.get_or_create(
            code="pas-photo",
            defaults={
                "name": "Pas Photo",
                "is_required": True,
                "sort_order": 6,
                "description": "JPG/PNG, maks. 500 KB.",
            },
        )

    def test_dry_run_does_not_write(self):
        profile = _profile("only-photo@example.com", "1111111111111111")
        _attach(profile, self.pas_photo, "legacy.jpg")

        result = merge_pas_photo_into_pas_foto(dry_run=True)

        self.assertEqual(result.retargeted, 1)
        self.assertTrue(DocumentType.objects.filter(code="pas-photo").exists())
        self.assertEqual(
            ApplicantDocument.objects.get(applicant_profile=profile).document_type_id,
            self.pas_photo.id,
        )

    def test_retargets_legacy_only_uploads(self):
        profile = _profile("legacy@example.com", "2222222222222222")
        doc = _attach(profile, self.pas_photo, "legacy.jpg")
        stored_name = doc.file.name

        result = merge_pas_photo_into_pas_foto(dry_run=False)

        self.assertEqual(result.retargeted, 1)
        self.assertFalse(DocumentType.objects.filter(code="pas-photo").exists())
        doc.refresh_from_db()
        self.assertEqual(doc.document_type.code, "pas-foto")
        self.assertEqual(doc.file.name, stored_name)
        self.assertTrue(default_storage.exists(stored_name))
        self.pas_foto.refresh_from_db()
        self.assertEqual(self.pas_foto.description, "JPG/PNG, maks. 500 KB.")

    def test_duplicate_keeps_approved_legacy_file_and_storage(self):
        profile = _profile("both@example.com", "3333333333333333")
        foto = _attach(profile, self.pas_foto, "new.jpg", DocumentReviewStatus.PENDING)
        photo = _attach(profile, self.pas_photo, "old.jpg", DocumentReviewStatus.APPROVED)
        foto_name = foto.file.name
        photo_name = photo.file.name

        result = merge_pas_photo_into_pas_foto(dry_run=False)

        self.assertEqual(result.duplicates_resolved, 1)
        self.assertEqual(result.legacy_kept_on_duplicate, 1)
        self.assertFalse(ApplicantDocument.objects.filter(pk=photo.pk).exists())
        foto.refresh_from_db()
        self.assertEqual(foto.document_type.code, "pas-foto")
        self.assertEqual(foto.file.name, photo_name)
        self.assertEqual(foto.review_status, DocumentReviewStatus.APPROVED)
        self.assertTrue(default_storage.exists(photo_name))
        self.assertTrue(default_storage.exists(foto_name))

    def test_idempotent_when_legacy_type_already_gone(self):
        self.pas_photo.delete()
        result = merge_pas_photo_into_pas_foto(dry_run=False)
        self.assertIn("nothing to merge", result.notes[0])
        self.assertTrue(DocumentType.objects.filter(code="pas-foto").exists())
