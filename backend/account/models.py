"""
Account models for the TKI recruitment platform.

- CustomUser: email-based auth with role (Admin, Staff, Company, Applicant).
- StaffProfile: extended profile for Staff users.
- ApplicantProfile: extended profile for Applicants (pelamar / TKI).
- CompanyProfile: extended profile for Company users (pihak perusahaan).
"""

import os

from django.db import models
from django.contrib.auth.models import AbstractUser
from django.core.exceptions import ValidationError
from django.utils.translation import gettext_lazy as _
from django.utils.text import get_valid_filename, slugify

from .managers import CustomUserManager
from .document_specs import validate_document_file


# ---------------------------------------------------------------------------
# Choices (single source of truth; max length must fit longest value)
# ---------------------------------------------------------------------------

class UserRole(models.TextChoices):
    """Peran pengguna untuk akses dan tipe profil."""

    ADMIN = "ADMIN", _("Admin")
    STAFF = "STAFF", _("Staf")
    COMPANY = "COMPANY", _("Perusahaan")
    APPLICANT = "APPLICANT", _("Pelamar")

# Longest choice value length for CharField max_length
USER_ROLE_MAX_LENGTH = 9


class Gender(models.TextChoices):
    """Jenis kelamin untuk profil pelamar."""

    MALE = "M", _("Laki-laki")
    FEMALE = "F", _("Perempuan")
    OTHER = "O", _("Lainnya")


class ApplicantVerificationStatus(models.TextChoices):
    """
    Status seleksi/verifikasi setelah pelamar mengirim data.
    Admin memverifikasi biodata dan dokumen; status ditampilkan ke pelamar.
    """

    DRAFT = "DRAFT", _("Draf")
    SUBMITTED = "SUBMITTED", _("Dikirim")
    ACCEPTED = "ACCEPTED", _("Diterima")
    REJECTED = "REJECTED", _("Ditolak")

APPLICANT_STATUS_MAX_LENGTH = 9


class DocumentReviewStatus(models.TextChoices):
    """Status review dokumen oleh admin/staff."""

    PENDING = "PENDING", _("Menunggu Review")
    APPROVED = "APPROVED", _("Diterima")
    REJECTED = "REJECTED", _("Ditolak")


DOCUMENT_REVIEW_STATUS_MAX_LENGTH = 8


# ---------------------------------------------------------------------------
# User
# ---------------------------------------------------------------------------

class CustomUser(AbstractUser):
    """
    Email-based user with a single role: Admin, Staff, Company, or Applicant.
    Username/first_name/last_name are unused; email is the sole identifier.
    """

    email = models.EmailField(
        _("alamat email"),
        unique=True,
        db_index=True,
        help_text=_("Digunakan untuk login dan notifikasi."),
    )
    full_name = models.CharField(
        _("nama lengkap"),
        max_length=255,
        blank=True,
        help_text=_("Nama lengkap pengguna (untuk Admin; peran lain dapat memakai profil)."),
    )
    role = models.CharField(
        _("peran"),
        max_length=USER_ROLE_MAX_LENGTH,
        choices=UserRole.choices,
        default=UserRole.APPLICANT,
        db_index=True,
        help_text=_("Menentukan akses dan profil (staf/pelamar/perusahaan) yang berlaku."),
    )
    email_verified = models.BooleanField(
        _("email terverifikasi"),
        default=False,
        db_index=True,
        help_text=_("Apakah alamat email sudah diverifikasi."),
    )
    email_verified_at = models.DateTimeField(
        _("email terverifikasi pada"),
        null=True,
        blank=True,
        help_text=_("Waktu email diverifikasi."),
    )
    google_id = models.CharField(
        _("Google ID"),
        max_length=255,
        null=True,
        blank=True,
        unique=True,
        db_index=True,
        help_text=_("ID subjek Google OAuth untuk login sosial."),
    )
    updated_at = models.DateTimeField(_("diperbarui pada"), auto_now=True)

    username = None
    first_name = None
    last_name = None

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []  # email already in USERNAME_FIELD

    objects = CustomUserManager()

    class Meta:
        ordering = ["-is_active", "email"]
        verbose_name = _("pengguna")
        verbose_name_plural = _("daftar pengguna")
        indexes = [
            models.Index(fields=["role", "is_active"]),
        ]

    def __str__(self) -> str:
        return f"{self.email} ({self.get_role_display()})"

    # ---- Role helpers (single role per user) ----

    @property
    def is_admin(self) -> bool:
        return self.role == UserRole.ADMIN

    @property
    def is_staff_role(self) -> bool:
        """True if user is Staff (not Django is_staff which is for admin site)."""
        return self.role == UserRole.STAFF

    @property
    def is_company(self) -> bool:
        return self.role == UserRole.COMPANY

    @property
    def is_applicant(self) -> bool:
        return self.role == UserRole.APPLICANT

    @property
    def is_backoffice(self) -> bool:
        """True for Admin or Staff (dashboard / internal use)."""
        return self.role in (UserRole.ADMIN, UserRole.STAFF)

    def has_applicant_profile(self) -> bool:
        return hasattr(self, "applicant_profile")

    def has_staff_profile(self) -> bool:
        return hasattr(self, "staff_profile")

    def has_company_profile(self) -> bool:
        return hasattr(self, "company_profile")


# ---------------------------------------------------------------------------
# Staff profile (Admin/Staff are often treated alike; profile for Staff)
# ---------------------------------------------------------------------------

class StaffProfile(models.Model):
    """Profil tambahan untuk pengguna Staf (peran operasional)."""

    user = models.OneToOneField(
        CustomUser,
        on_delete=models.CASCADE,
        related_name="staff_profile",
        limit_choices_to={"role": UserRole.STAFF},
        verbose_name=_("pengguna"),
    )
    full_name = models.CharField(
        _("nama lengkap"),
        max_length=255,
        help_text=_("Nama lengkap staf."),
    )
    contact_phone = models.CharField(
        _("telepon kontak"),
        max_length=50,
        blank=True,
        help_text=_("Nomor telepon kontak."),
    )
    photo = models.ImageField(
        _("foto profil"),
        upload_to="account/staff/%Y/%m/",
        blank=True,
        null=True,
        help_text=_("Foto profil staf."),
    )
    created_at = models.DateTimeField(_("dibuat pada"), auto_now_add=True)
    updated_at = models.DateTimeField(_("diperbarui pada"), auto_now=True)

    class Meta:
        verbose_name = _("profil staf")
        verbose_name_plural = _("daftar profil staf")
        indexes = [
            models.Index(fields=["user"]),
        ]

    def __str__(self) -> str:
        return f"{self.full_name} ({self.user.email})"


# ---------------------------------------------------------------------------
# Applicant profile (Pelamar / CPMI) – aligned with FORM BIODATA PMI
# ---------------------------------------------------------------------------

class ApplicantProfile(models.Model):
    """
    Extended profile for Applicants (pelamar / CPMI) registering as TKI.
    Fields aligned with FORM BIODATA PMI; used for registration and job applications.
    """

    user = models.OneToOneField(
        CustomUser,
        on_delete=models.CASCADE,
        related_name="applicant_profile",
        limit_choices_to={"role": UserRole.APPLICANT},
        verbose_name=_("pengguna"),
    )
    referrer = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="referred_applicants",
        limit_choices_to={"role__in": [UserRole.STAFF, UserRole.ADMIN]},
        verbose_name=_("perujuk"),
        help_text=_("Staf atau Admin yang merujuk pelamar ini. Jika kosong, dianggap Admin."),
    )
    # ---- I. Data CPMI ----
    full_name = models.CharField(
        _("nama lengkap CPMI"),
        max_length=255,
        help_text=_("Nama lengkap sesuai dokumen identitas."),
    )
    birth_place = models.CharField(
        _("tempat lahir"),
        max_length=255,
        blank=True,
    )
    birth_date = models.DateField(
        _("tanggal lahir"),
        null=True,
        blank=True,
    )
    address = models.TextField(
        _("alamat sesuai KTP"),
        blank=True,
        help_text=_("Alamat sesuai KTP (lengkap sampai Kota/Kabupaten)."),
    )
    contact_phone = models.CharField(
        _("no. HP / WA yang aktif"),
        max_length=50,
        blank=True,
        help_text=_("Nomor HP/WA yang aktif."),
    )
    # Email is on User; no duplicate here.
    sibling_count = models.PositiveSmallIntegerField(
        _("jumlah saudara"),
        null=True,
        blank=True,
        help_text=_("Jumlah saudara."),
    )
    birth_order = models.PositiveSmallIntegerField(
        _("anak ke"),
        null=True,
        blank=True,
        help_text=_("Anak ke- (urutan lahir dalam keluarga)."),
    )
    # ---- II. Data orangtua / keluarga (Ayah, Ibu, Suami/Istri terpisah) ----
    father_name = models.CharField(
        _("nama ayah"),
        max_length=255,
        blank=True,
        help_text=_("Nama ayah kandung."),
    )
    father_age = models.PositiveSmallIntegerField(
        _("umur ayah"),
        null=True,
        blank=True,
    )
    father_occupation = models.CharField(
        _("pekerjaan ayah"),
        max_length=255,
        blank=True,
    )
    mother_name = models.CharField(
        _("nama ibu"),
        max_length=255,
        blank=True,
        help_text=_("Nama ibu kandung."),
    )
    mother_age = models.PositiveSmallIntegerField(
        _("umur ibu"),
        null=True,
        blank=True,
    )
    mother_occupation = models.CharField(
        _("pekerjaan ibu"),
        max_length=255,
        blank=True,
    )
    spouse_name = models.CharField(
        _("nama suami / istri"),
        max_length=255,
        blank=True,
        help_text=_("Nama suami atau istri (jika sudah menikah)."),
    )
    spouse_age = models.PositiveSmallIntegerField(
        _("umur suami / istri"),
        null=True,
        blank=True,
    )
    spouse_occupation = models.CharField(
        _("pekerjaan suami / istri"),
        max_length=255,
        blank=True,
    )
    family_address = models.TextField(
        _("alamat orangtua / keluarga"),
        blank=True,
        help_text=_("Alamat orangtua/keluarga (lengkap sampai Kota/Kabupaten)."),
    )
    family_contact_phone = models.CharField(
        _("no. HP / WA keluarga yang aktif"),
        max_length=50,
        blank=True,
        help_text=_("Nomor HP/WA keluarga yang aktif."),
    )
    # ---- Identity & profile ----
    nik = models.CharField(
        _("NIK"),
        max_length=16,
        unique=True,
        db_index=True,
        help_text=_(
            "Nomor Induk Kependudukan (NIK). 16 digit, unik per pelamar. "
            "Validasi format (16 digit) di API/serializer."
        ),
    )
    gender = models.CharField(
        _("jenis kelamin"),
        max_length=1,
        choices=Gender.choices,
        blank=True,
    )
    photo = models.ImageField(
        _("pas photo PMI"),
        upload_to="account/applicants/%Y/%m/",
        blank=True,
        null=True,
        help_text=_("Pas photo berwarna background putih ukuran 3x4."),
    )
    notes = models.TextField(
        _("keterangan"),
        blank=True,
        help_text=_("Catatan tambahan (III. Keterangan)."),
    )
    # ---- Verifikasi / seleksi (admin memverifikasi data; status ditampilkan ke pelamar) ----
    verification_status = models.CharField(
        _("status verifikasi"),
        max_length=APPLICANT_STATUS_MAX_LENGTH,
        choices=ApplicantVerificationStatus.choices,
        default=ApplicantVerificationStatus.DRAFT,
        db_index=True,
        help_text=_("Draf: mengisi data. Dikirim: menunggu admin. Diterima/Ditolak: setelah verifikasi."),
    )
    submitted_at = models.DateTimeField(
        _("dikirim pada"),
        null=True,
        blank=True,
        help_text=_("Waktu pelamar mengirim untuk verifikasi (status → Dikirim)."),
    )
    verified_at = models.DateTimeField(
        _("diverifikasi pada"),
        null=True,
        blank=True,
        help_text=_("Waktu admin menetapkan status Diterima atau Ditolak."),
    )
    verified_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="verified_applicants",
        limit_choices_to={"role__in": [UserRole.STAFF, UserRole.ADMIN]},
        verbose_name=_("diverifikasi oleh"),
        help_text=_("Admin atau Staf yang memverifikasi pelamar ini."),
    )
    verification_notes = models.TextField(
        _("catatan verifikasi"),
        blank=True,
        help_text=_("Catatan internal atau alasan penolakan yang ditampilkan ke pelamar."),
    )
    created_at = models.DateTimeField(_("dibuat pada"), auto_now_add=True)
    updated_at = models.DateTimeField(_("diperbarui pada"), auto_now=True)

    class Meta:
        verbose_name = _("profil pelamar")
        verbose_name_plural = _("daftar profil pelamar")
        indexes = [
            models.Index(fields=["user"]),
            models.Index(fields=["full_name"]),
            models.Index(fields=["referrer"]),
            models.Index(fields=["verification_status"]),
            models.Index(fields=["created_at"]),
            models.Index(fields=["verification_status", "submitted_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.full_name} ({self.user.email})"

    def clean(self) -> None:
        super().clean()
        if self.referrer_id and self.referrer_id == self.user_id:
            raise ValidationError(
                {"referrer": _("Pelamar tidak dapat menjadi perujuk diri sendiri.")}
            )
        if self.referrer_id and self.referrer.role not in (
            UserRole.STAFF,
            UserRole.ADMIN,
        ):
            raise ValidationError(
                {"referrer": _("Perujuk harus pengguna Staf atau Admin.")}
            )
        if self.verification_status in (
            ApplicantVerificationStatus.ACCEPTED,
            ApplicantVerificationStatus.REJECTED,
        ) and not self.verified_by_id:
            raise ValidationError(
                {
                    "verified_by": _(
                        "Diverifikasi oleh harus diisi ketika status Diterima atau Ditolak."
                    )
                }
            )

    def get_referrer_display(self) -> str:
        """Return referrer email, or 'Admin' when no referrer is set."""
        if self.referrer_id:
            return self.referrer.email
        return _("Admin")

    get_referrer_display.short_description = _("Perujuk")

    def get_ktp_prefill_from_ocr(self) -> dict | None:
        """
        Return biodata pre-fill from KTP OCR if applicant has uploaded KTP
        and OCR has been run. Used by mobile app to pre-fill registration form.
        Returns None if no KTP document or no ocr_data.
        """
        try:
            ktp_doc = self.documents.select_related("document_type").get(
                document_type__code="ktp"
            )
        except ApplicantDocument.DoesNotExist:
            return None
        return ktp_doc.get_biodata_prefill()

    # ---- Verification status helpers (for display and API) ----
    @property
    def is_draft(self) -> bool:
        return self.verification_status == ApplicantVerificationStatus.DRAFT

    @property
    def is_submitted(self) -> bool:
        return self.verification_status == ApplicantVerificationStatus.SUBMITTED

    @property
    def is_accepted(self) -> bool:
        return self.verification_status == ApplicantVerificationStatus.ACCEPTED

    @property
    def is_rejected(self) -> bool:
        return self.verification_status == ApplicantVerificationStatus.REJECTED

    @property
    def is_pending_verification(self) -> bool:
        """True when waiting for admin to verify (submitted)."""
        return self.verification_status == ApplicantVerificationStatus.SUBMITTED

    def get_verification_status_display_short(self) -> str:
        """Short label for mobile/API: e.g. 'Draf', 'Dikirim', 'Diterima', 'Ditolak'."""
        return self.get_verification_status_display()


# ---------------------------------------------------------------------------
# Pengalaman kerja (per pelamar, terstruktur)
# ---------------------------------------------------------------------------

class WorkExperience(models.Model):
    """
    Satu entri pengalaman kerja per pelamar. Mendukung banyak entri,
    data terstruktur (perusahaan, jabatan, periode), dan urutan tampilan.
    """

    applicant_profile = models.ForeignKey(
        ApplicantProfile,
        on_delete=models.CASCADE,
        related_name="work_experiences",
        verbose_name=_("profil pelamar"),
    )
    company_name = models.CharField(
        _("nama perusahaan / pemberi kerja"),
        max_length=255,
        help_text=_("Nama perusahaan atau pemberi kerja."),
    )
    position = models.CharField(
        _("jabatan / posisi"),
        max_length=255,
        blank=True,
        help_text=_("Jabatan atau posisi yang diemban."),
    )
    start_date = models.DateField(
        _("tanggal mulai"),
        null=True,
        blank=True,
        help_text=_("Tanggal mulai bekerja."),
    )
    end_date = models.DateField(
        _("tanggal selesai"),
        null=True,
        blank=True,
        help_text=_("Tanggal selesai. Kosongkan jika masih bekerja."),
    )
    still_employed = models.BooleanField(
        _("masih bekerja"),
        default=False,
        help_text=_("Centang jika masih bekerja di sini."),
    )
    description = models.TextField(
        _("keterangan"),
        blank=True,
        help_text=_("Deskripsi singkat tugas atau pencapaian."),
    )
    sort_order = models.PositiveSmallIntegerField(
        _("urutan"),
        default=0,
        help_text=_("Urutan tampilan (angka lebih kecil tampil lebih dulu)."),
    )
    created_at = models.DateTimeField(_("dibuat pada"), auto_now_add=True)
    updated_at = models.DateTimeField(_("diperbarui pada"), auto_now=True)

    class Meta:
        ordering = ["applicant_profile", "sort_order", "-end_date", "-start_date"]
        verbose_name = _("pengalaman kerja")
        verbose_name_plural = _("daftar pengalaman kerja")
        indexes = [
            models.Index(fields=["applicant_profile"]),
            models.Index(fields=["applicant_profile", "sort_order"]),
        ]

    def clean(self) -> None:
        """Validate that end_date >= start_date when both are provided."""
        super().clean()
        if self.start_date and self.end_date and not self.still_employed:
            if self.end_date < self.start_date:
                raise ValidationError(
                    {
                        "end_date": _(
                            "Tanggal selesai harus lebih besar atau sama dengan tanggal mulai."
                        )
                    }
                )

    def __str__(self) -> str:
        return f"{self.company_name} – {self.position or '-'} ({self.applicant_profile.full_name})"


# ---------------------------------------------------------------------------
# Document types and applicant document uploads (12 types per requirement)
# ---------------------------------------------------------------------------

class DocumentType(models.Model):
    """
    Tipe dokumen untuk persyaratan TKI (KTP, Ijasah, KK, dll.).
    Digunakan untuk unggah wajib dan validasi per pelamar.
    """

    code = models.SlugField(
        _("kode"),
        max_length=50,
        unique=True,
        help_text=_("Kode unik (mis. ktp, ijasah, kk)."),
    )
    name = models.CharField(
        _("nama"),
        max_length=255,
        help_text=_("Nama tampilan (mis. KTP, Ijasah)."),
    )
    is_required = models.BooleanField(
        _("wajib"),
        default=True,
        help_text=_("Apakah dokumen ini wajib untuk pendaftaran/penempatan."),
    )
    sort_order = models.PositiveSmallIntegerField(
        _("urutan"),
        default=0,
        help_text=_("Urutan di daftar (angka lebih kecil tampil lebih dulu)."),
    )
    description = models.CharField(
        _("deskripsi"),
        max_length=500,
        blank=True,
        help_text=_("Petunjuk opsional (mis. Paspor bagi yang sudah ada)."),
    )
    created_at = models.DateTimeField(_("dibuat pada"), auto_now_add=True)

    class Meta:
        ordering = ["sort_order", "code"]
        verbose_name = _("tipe dokumen")
        verbose_name_plural = _("daftar tipe dokumen")
        indexes = [
            models.Index(fields=["code"]),
            models.Index(fields=["is_required", "sort_order"]),
        ]

    def __str__(self) -> str:
        return f"{self.name} ({self.code})"


def applicant_document_upload_to(instance, filename: str) -> str:
    """
    Upload path convention:
    account/documents/<applicant_profile_id>/<doc_type_code>/<slug-name>-<last4nik>-<doc_type_code>.<ext>

    - Folder per applicant (stable numeric ID, no PII in path beyond that ID)
    - File name is human-readable but only uses:
      - slugified full name (no spaces/special chars)
      - last 4 digits of NIK (not full NIK, to reduce PII exposure)
      - document type code (e.g. ktp, ijasah)
    - Original filename contributes only its extension.
    """
    profile = instance.applicant_profile
    doc_type_code = instance.document_type.code

    # Ensure we always have a safe base filename and extension
    safe_original = get_valid_filename(filename) or "document"
    base, ext = os.path.splitext(safe_original)
    ext = ext or ""

    full_name_slug = slugify(profile.full_name or "") or "applicant"
    nik = (profile.nik or "").strip()
    last4_nik = nik[-4:] if len(nik) >= 4 else ""

    name_parts = [full_name_slug]
    if last4_nik:
        name_parts.append(last4_nik)
    if doc_type_code:
        name_parts.append(doc_type_code)

    final_name = "-".join(name_parts) + ext
    return f"account/documents/{profile.id}/{doc_type_code}/{final_name}"


# ---------------------------------------------------------------------------
# OCR extraction keys (for KTP) – used to pre-fill biodata on mobile registration
# ---------------------------------------------------------------------------
# Expected keys in ApplicantDocument.ocr_data when document_type.code == "ktp":
#   nik, name, birth_place, birth_date, address, gender (optional)
# Mobile app and backend OCR service should use these keys for consistency.
KTP_OCR_KEYS = ("nik", "name", "birth_place", "birth_date", "address", "gender")


class ApplicantDocument(models.Model):
    """
    One uploaded document per applicant per document type (e.g. one KTP file per applicant).
    Re-uploading replaces the file.
    OCR: ocr_text = raw full text; ocr_data = structured fields for pre-filling biodata
    (e.g. KTP: nik, name, birth_place, birth_date, address) so mobile registration can auto-fill.
    """

    applicant_profile = models.ForeignKey(
        ApplicantProfile,
        on_delete=models.CASCADE,
        related_name="documents",
        verbose_name=_("profil pelamar"),
    )
    document_type = models.ForeignKey(
        DocumentType,
        on_delete=models.PROTECT,
        related_name="applicant_documents",
        verbose_name=_("tipe dokumen"),
    )
    file = models.FileField(
        _("berkas"),
        upload_to=applicant_document_upload_to,
        help_text=_("Berkas dokumen yang diunggah."),
    )
    uploaded_at = models.DateTimeField(_("diunggah pada"), auto_now_add=True)
    ocr_text = models.TextField(
        _("teks OCR"),
        blank=True,
        help_text=_("Teks penuh dari OCR (mis. Google Vision)."),
    )
    ocr_data = models.JSONField(
        _("data hasil OCR"),
        default=dict,
        blank=True,
        help_text=_(
            "Data terstruktur dari OCR untuk mengisi biodata. "
            "Untuk KTP: nik, nama, tempat_lahir, tanggal_lahir, alamat, jenis_kelamin."
        ),
    )
    ocr_processed_at = models.DateTimeField(
        _("diproses OCR pada"),
        null=True,
        blank=True,
        help_text=_("Waktu ekstraksi OCR terakhir dijalankan untuk dokumen ini."),
    )
    # ---- Review/Verification (admin review per dokumen) ----
    review_status = models.CharField(
        _("status review"),
        max_length=DOCUMENT_REVIEW_STATUS_MAX_LENGTH,
        choices=DocumentReviewStatus.choices,
        default=DocumentReviewStatus.PENDING,
        db_index=True,
        help_text=_("Status review dokumen oleh admin/staff."),
    )
    reviewed_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reviewed_documents",
        limit_choices_to={"role__in": [UserRole.STAFF, UserRole.ADMIN]},
        verbose_name=_("direview oleh"),
        help_text=_("Admin atau Staff yang mereview dokumen ini."),
    )
    reviewed_at = models.DateTimeField(
        _("direview pada"),
        null=True,
        blank=True,
        help_text=_("Waktu dokumen direview (APPROVED atau REJECTED)."),
    )
    review_notes = models.TextField(
        _("catatan review"),
        blank=True,
        help_text=_("Catatan admin/staff terkait review dokumen (mis. alasan ditolak, catatan khusus)."),
    )

    class Meta:
        verbose_name = _("dokumen pelamar")
        verbose_name_plural = _("daftar dokumen pelamar")
        constraints = [
            models.UniqueConstraint(
                fields=["applicant_profile", "document_type"],
                name="account_applicantdocument_unique_profile_doctype",
            ),
        ]
        indexes = [
            models.Index(fields=["applicant_profile", "document_type"]),
            models.Index(fields=["uploaded_at"]),
            models.Index(fields=["review_status"]),
            models.Index(fields=["applicant_profile", "review_status"]),
        ]

    def __str__(self) -> str:
        return f"{self.applicant_profile.full_name} – {self.document_type.name}"

    def clean(self):
        super().clean()
        if self.file and self.document_type_id:
            validate_document_file(self.file, self.document_type.code)

    def save(self, *args, **kwargs):
        if self.pk:
            try:
                old = ApplicantDocument.objects.get(pk=self.pk)
                if old.file and old.file != self.file and self.file:
                    old.file.delete(save=False)
            except ApplicantDocument.DoesNotExist:
                pass
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        if self.file:
            self.file.delete(save=False)
        super().delete(*args, **kwargs)

    def get_biodata_prefill(self) -> dict | None:
        """
        Return a dict suitable for pre-filling ApplicantProfile biodata from OCR.
        Used by mobile app after KTP upload: check KTP has NIK, name, etc. and fill form.
        Returns None if this document is not KTP or ocr_data is empty.
        Keys match ApplicantProfile / FORM BIODATA PMI: full_name, nik, birth_place,
        birth_date, address, gender.
        """
        if self.document_type_id is None or self.document_type.code != "ktp":
            return None
        if not self.ocr_data:
            return None
        data = self.ocr_data
        return {
            "full_name": data.get("name") or data.get("full_name") or "",
            "nik": data.get("nik") or "",
            "birth_place": data.get("birth_place") or "",
            "birth_date": data.get("birth_date") or "",
            "address": data.get("address") or "",
            "gender": (data.get("gender") or "").upper()[:1] or "",
        }


# ---------------------------------------------------------------------------
# Company profile (Pihak perusahaan)
# ---------------------------------------------------------------------------

class CompanyProfile(models.Model):
    """
    Profil tambahan untuk pengguna Perusahaan. Menghubungkan pengguna peran COMPANY
    dengan data perusahaan. Model companies.Company dapat ditambah nanti dan dihubungkan
    lewat FK jika diperlukan untuk lowongan/lamaran.
    """

    user = models.OneToOneField(
        CustomUser,
        on_delete=models.CASCADE,
        related_name="company_profile",
        limit_choices_to={"role": UserRole.COMPANY},
        verbose_name=_("pengguna"),
    )
    company_name = models.CharField(
        _("nama perusahaan"),
        max_length=255,
        help_text=_("Nama perusahaan terdaftar."),
    )
    contact_phone = models.CharField(
        _("telepon kontak"),
        max_length=50,
        blank=True,
    )
    address = models.TextField(
        _("alamat"),
        blank=True,
    )
    created_at = models.DateTimeField(_("dibuat pada"), auto_now_add=True)
    updated_at = models.DateTimeField(_("diperbarui pada"), auto_now=True)

    class Meta:
        verbose_name = _("profil perusahaan")
        verbose_name_plural = _("daftar profil perusahaan")
        indexes = [
            models.Index(fields=["user"]),
            models.Index(fields=["company_name"]),
        ]

    def __str__(self) -> str:
        return f"{self.company_name} ({self.user.email})"
