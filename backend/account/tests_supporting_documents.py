"""Dokumen pendukung: admin-only, multi-file, labelled PDFs per pelamar."""

import io
import tempfile
import zipfile

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.urls import reverse
from rest_framework.test import APIClient

from account.document_specs import MAX_SUPPORTING_PDF_BYTES
from account.models import (
    ApplicantProfile,
    ApplicantSupportingDocument,
    CustomUser,
    UserRole,
)

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

PDF_BYTES = b"%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n"


def _pdf(name="surat.pdf", content=PDF_BYTES):
    return SimpleUploadedFile(name, content, content_type="application/pdf")


def _user(email, role, **extra):
    return CustomUser.objects.create_user(
        email=email,
        password="testpass123",
        role=role,
        is_active=True,
        email_verified=True,
        **extra,
    )


@local_media
class SupportingDocumentTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.applicant = _user("pelamar.sd@example.com", UserRole.APPLICANT, full_name="Budi Santoso")
        self.profile = ApplicantProfile.objects.create(
            user=self.applicant, contact_phone="081234567890", nik="1234567890123456"
        )
        self.other = _user("pelamar.lain.sd@example.com", UserRole.APPLICANT, full_name="Siti Aminah")
        self.other_profile = ApplicantProfile.objects.create(
            user=self.other, contact_phone="081200000000", nik="1234567890123457"
        )
        self.admin = _user("admin.sd@example.com", UserRole.ADMIN, full_name="Admin Satu")
        self.master = _user("master.sd@example.com", UserRole.MASTER_ADMIN, full_name="Master")

    # -- helpers ---------------------------------------------------------
    def _list_url(self, user_id=None):
        return reverse(
            "account:applicant-supporting-documents",
            kwargs={"applicant_pk": user_id or self.applicant.id},
        )

    def _detail_url(self, doc, user_id=None):
        return reverse(
            "account:applicant-supporting-document-detail",
            kwargs={"applicant_pk": user_id or self.applicant.id, "pk": doc.pk},
        )

    def _zip_url(self, user_id=None):
        return reverse(
            "account:applicant-supporting-documents-download-all",
            kwargs={"applicant_pk": user_id or self.applicant.id},
        )

    def _upload(self, label="Surat Sponsor", file=None, user=None):
        self.client.force_authenticate(user or self.admin)
        return self.client.post(
            self._list_url(),
            {"label": label, "file": file or _pdf()},
            format="multipart",
        )

    # -- CRUD ------------------------------------------------------------
    def test_admin_can_upload_and_list(self):
        res = self._upload("Surat Sponsor PT A")
        self.assertEqual(res.status_code, 201, res.content)
        self.assertEqual(res.data["label"], "Surat Sponsor PT A")
        self.assertEqual(res.data["original_filename"], "surat.pdf")
        self.assertEqual(res.data["file_size"], len(PDF_BYTES))
        self.assertEqual(res.data["uploaded_by_name"], "Admin Satu")
        self.assertIn("/supporting-documents/", res.data["file_view_url"])
        self.assertNotIn("file", res.data)

        doc = ApplicantSupportingDocument.objects.get()
        self.assertIn(f"account/documents/{self.profile.id}/pendukung/", doc.file.name)
        self.assertNotIn("Budi", doc.file.name)

        res = self.client.get(self._list_url())
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.data), 1)

    def test_master_admin_can_upload(self):
        res = self._upload(user=self.master)
        self.assertEqual(res.status_code, 201, res.content)

    def test_multiple_files_may_share_a_label(self):
        self.assertEqual(self._upload("Kontrak").status_code, 201)
        self.assertEqual(self._upload("Kontrak").status_code, 201)
        self.assertEqual(self.profile.supporting_documents.count(), 2)

    def test_patch_updates_label_only(self):
        self._upload("Lama")
        doc = ApplicantSupportingDocument.objects.get()
        original_name = doc.file.name
        res = self.client.patch(
            self._detail_url(doc),
            {"label": "  Baru  ", "file": _pdf("lain.pdf")},
            format="multipart",
        )
        self.assertEqual(res.status_code, 200, res.content)
        doc.refresh_from_db()
        self.assertEqual(doc.label, "Baru")
        self.assertEqual(doc.file.name, original_name)

    def test_put_not_allowed(self):
        self._upload()
        doc = ApplicantSupportingDocument.objects.get()
        res = self.client.put(self._detail_url(doc), {"label": "x"}, format="json")
        self.assertEqual(res.status_code, 405)

    def test_delete_removes_file_from_storage(self):
        self._upload()
        doc = ApplicantSupportingDocument.objects.get()
        storage, name = doc.file.storage, doc.file.name
        self.assertTrue(storage.exists(name))
        res = self.client.delete(self._detail_url(doc))
        self.assertEqual(res.status_code, 204)
        self.assertFalse(storage.exists(name))
        self.assertFalse(ApplicantSupportingDocument.objects.exists())

    # -- validation ------------------------------------------------------
    def test_rejects_non_pdf_content(self):
        res = self._upload(file=_pdf("palsu.pdf", b"<html>nope</html>"))
        self.assertEqual(res.status_code, 400)
        self.assertFalse(ApplicantSupportingDocument.objects.exists())

    def test_rejects_non_pdf_extension(self):
        res = self._upload(file=SimpleUploadedFile("foto.jpg", PDF_BYTES))
        self.assertEqual(res.status_code, 400)

    def test_rejects_oversized_pdf(self):
        big = PDF_BYTES + b"0" * MAX_SUPPORTING_PDF_BYTES
        res = self._upload(file=_pdf("besar.pdf", big))
        self.assertEqual(res.status_code, 400)

    def test_rejects_blank_label(self):
        res = self._upload(label="   ")
        self.assertEqual(res.status_code, 400)

    def test_requires_file(self):
        self.client.force_authenticate(self.admin)
        res = self.client.post(self._list_url(), {"label": "x"}, format="multipart")
        self.assertEqual(res.status_code, 400)

    # -- access ----------------------------------------------------------
    def test_non_admin_roles_are_denied(self):
        self._upload()
        doc = ApplicantSupportingDocument.objects.get()
        staff = _user("staff.sd@example.com", UserRole.STAFF)
        company = _user("company.sd@example.com", UserRole.COMPANY)
        for user in (staff, company, self.applicant):
            self.client.force_authenticate(user)
            for url in (self._list_url(), self._detail_url(doc), self._zip_url()):
                res = self.client.get(url)
                self.assertIn(res.status_code, (401, 403), f"{user.role} {url}")
            res = self.client.post(
                self._list_url(), {"label": "x", "file": _pdf()}, format="multipart"
            )
            self.assertIn(res.status_code, (401, 403))

    def test_anonymous_is_denied(self):
        self.client.force_authenticate(None)
        res = self.client.get(self._list_url())
        self.assertIn(res.status_code, (401, 403))

    def test_document_scoped_to_its_pelamar(self):
        self._upload()
        doc = ApplicantSupportingDocument.objects.get()
        res = self.client.get(self._detail_url(doc, user_id=self.other.id))
        self.assertEqual(res.status_code, 404)
        res = self.client.get(self._list_url(self.other.id))
        self.assertEqual(res.data, [])

    def test_file_url_endpoint(self):
        self._upload()
        doc = ApplicantSupportingDocument.objects.get()
        url = reverse(
            "account:applicant-supporting-document-file-url",
            kwargs={"applicant_pk": self.applicant.id, "pk": doc.pk},
        )
        res = self.client.get(url)
        self.assertEqual(res.status_code, 200)
        self.assertIn("/pendukung/", res.data["url"])
        self.assertEqual(res["Cache-Control"], "private, no-store")

    def test_not_exposed_to_applicant_self_service(self):
        self._upload()
        self.client.force_authenticate(self.applicant)
        res = self.client.get("/api/applicants/me/documents/")
        self.assertNotIn(b"pendukung", res.content)

    # -- zip -------------------------------------------------------------
    def test_download_all_zip(self):
        self._upload("Surat Sponsor PT A", _pdf("a.pdf", PDF_BYTES + b"A"))
        self._upload("Kontrak / Kerja", _pdf("b.pdf", PDF_BYTES + b"B"))
        self._upload("Kontrak / Kerja", _pdf("c.pdf", PDF_BYTES + b"C"))

        res = self.client.get(self._zip_url(), HTTP_ACCEPT="application/zip")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res["Content-Type"], "application/zip")
        self.assertIn(
            'filename="Dokumen_Pendukung_Budi_Santoso_1234567890123456.zip"',
            res["Content-Disposition"],
        )
        with zipfile.ZipFile(io.BytesIO(res.content)) as zf:
            folder = "Budi_Santoso_1234567890123456_Dokumen_Pendukung"
            self.assertEqual(
                zf.namelist(),
                [
                    f"{folder}/01_Surat_Sponsor_PT_A.pdf",
                    f"{folder}/02_Kontrak_Kerja.pdf",
                    f"{folder}/03_Kontrak_Kerja.pdf",
                ],
            )
            self.assertEqual(zf.read(f"{folder}/02_Kontrak_Kerja.pdf"), PDF_BYTES + b"B")

    def test_download_all_label_cannot_escape_folder(self):
        self._upload("../../etc/passwd")
        res = self.client.get(self._zip_url())
        with zipfile.ZipFile(io.BytesIO(res.content)) as zf:
            for name in zf.namelist():
                self.assertNotIn("..", name)
                self.assertEqual(name.count("/"), 1)

    def test_download_all_any_accept_header(self):
        self._upload()
        res = self.client.get(self._zip_url(), HTTP_ACCEPT="application/pdf")
        self.assertEqual(res.status_code, 200)

    def test_download_all_empty_is_404(self):
        self.client.force_authenticate(self.admin)
        res = self.client.get(self._zip_url())
        self.assertEqual(res.status_code, 404)

    # -- permanent delete --------------------------------------------------
    def test_permanent_delete_removes_supporting_files(self):
        self._upload()
        doc = ApplicantSupportingDocument.objects.get()
        storage, name = doc.file.storage, doc.file.name
        self.client.force_authenticate(self.master)
        res = self.client.post(f"/api/applicants/{self.applicant.id}/permanent-delete/")
        self.assertEqual(res.status_code, 200, res.content)
        self.assertFalse(storage.exists(name))
