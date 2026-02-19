"""
Account models for the TKI recruitment platform.

- CustomUser: email-based auth with role (Admin, Staff, Company, Applicant).
- StaffProfile: extended profile for Staff users.
- ApplicantProfile: extended profile for Applicants (pelamar / TKI).
- CompanyProfile: extended profile for Company users (pihak perusahaan).
"""

import os
from datetime import date

from django.db import models
from django.db.models import Q
from django.contrib.auth.models import AbstractUser
from django.core.exceptions import ValidationError
from django.core.cache import cache
from django.utils import timezone
from django.utils.translation import gettext_lazy as _
from django.utils.text import get_valid_filename, slugify
from django_countries.fields import CountryField

from .managers import (
    ApplicantDocumentManager,
    ApplicantProfileManager,
    CustomUserManager,
)
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


# Choices for FORM PENDATAAN CALON PMI PRA SELEKSI (aligned with Google Form)
class DestinationCountry(models.TextChoices):
    """Negara tujuan penempatan (form: negara yang dituju)."""

    MALAYSIA = "MALAYSIA", _("Malaysia")


class Religion(models.TextChoices):
    """Agama (form: data lainnya)."""

    ISLAM = "ISLAM", _("Islam")
    KRISTEN = "KRISTEN", _("Kristen")
    KATHOLIK = "KATHOLIK", _("Katholik")
    HINDU = "HINDU", _("Hindu")
    BUDHA = "BUDHA", _("Budha")
    LAINNYA = "LAINNYA", _("Lainnya")


RELIGION_MAX_LENGTH = 8  # KATHOLIK


class EducationLevel(models.TextChoices):
    """Pendidikan terakhir (form: data lainnya)."""

    SMP = "SMP", _("SMP")
    SMA = "SMA", _("SMA")
    SMK = "SMK", _("SMK")
    MA = "MA", _("MA")
    D3 = "D3", _("D3")
    S1 = "S1", _("S1")


EDUCATION_LEVEL_MAX_LENGTH = 3


class WritingHand(models.TextChoices):
    """Tangan yang digunakan untuk menulis (form: anda menulis dengan tangan?)."""

    KANAN = "KANAN", _("Kanan")
    KIRI = "KIRI", _("Kiri")


WRITING_HAND_MAX_LENGTH = 5


class MaritalStatus(models.TextChoices):
    """Status perkawinan (form: data lainnya)."""

    BELUM_MENIKAH = "BELUM MENIKAH", _("Belum Menikah")
    MENIKAH = "MENIKAH", _("Menikah")
    CERAI_HIDUP = "CERAI HIDUP", _("Cerai Hidup")
    CERAI_MATI = "CERAI MATI", _("Cerai Mati")


MARITAL_STATUS_MAX_LENGTH = 14  # BELUM MENIKAH


HAS_PASSPORT_MAX_LENGTH = 5


class IndustryType(models.TextChoices):
    """Jenis industri perusahaan (form: pengalaman kerja)."""

    SEMICONDUCTOR = "SEMICONDUCTOR", _("Semiconductor")
    ELEKTRONIK = "ELEKTRONIK", _("Elektronik")
    PABRIK_LAIN = "PABRIK LAIN", _("Pabrik Lain")
    JASA = "JASA", _("Jasa")
    LAIN_LAIN = "LAIN LAIN", _("Lain Lain")
    BELUM_PERNAH_BEKERJA = "BELUM PERNAH BEKERJA", _("Belum Pernah Bekerja")


INDUSTRY_TYPE_MAX_LENGTH = 21  # BELUM PERNAH BEKERJA


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
    referral_code = models.CharField(
        _("kode rujukan"),
        max_length=16,
        null=True,
        blank=True,
        unique=True,
        db_index=True,
        help_text=_("Kode rujukan unik untuk Staff/Admin. Pelamar harus memasukkan kode ini saat registrasi."),
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
    
    def __repr__(self) -> str:
        return f"<CustomUser: {self.email} ({self.role})>"

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

    def generate_referral_code(self) -> str:
        """
        Generate a unique referral code for staff/admin users.
        Format: ROLE prefix (S for staff, A for admin) + 6 random uppercase alphanumeric chars.
        Example: S-ABC123, A-XYZ789
        """
        import random
        import string

        prefix = "A" if self.role == UserRole.ADMIN else "S"
        chars = string.ascii_uppercase + string.digits
        
        # Try up to 10 times to generate a unique code
        for _ in range(10):
            code_suffix = "".join(random.choices(chars, k=6))
            code = f"{prefix}-{code_suffix}"
            
            # Check if code is unique
            if not CustomUser.objects.filter(referral_code=code).exists():
                return code
        
        # Fallback: use timestamp-based code if random fails
        timestamp = int(timezone.now().timestamp() * 1000) % 1000000
        return f"{prefix}-{timestamp:06d}"

    def ensure_referral_code(self) -> str:
        """
        Ensure the user has a referral code. Generate one if missing.
        Only applicable for STAFF and ADMIN roles.
        Returns the referral code.
        """
        if self.role not in (UserRole.STAFF, UserRole.ADMIN):
            return ""
        
        if not self.referral_code:
            self.referral_code = self.generate_referral_code()
            self.save(update_fields=["referral_code"])
        
        return self.referral_code

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
        return f"{self.user.full_name} ({self.user.email})"


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
    registration_date = models.DateField(
        _("tanggal pendaftaran"),
        null=True,
        blank=True,
        help_text=_("Tanggal pendaftaran (hari ini saat mengisi form)."),
    )
    destination_country = models.CharField(
        _("negara yang dituju"),
        max_length=20,
        choices=DestinationCountry.choices,
        default=DestinationCountry.MALAYSIA,
        blank=True,
        help_text=_("Negara tujuan penempatan (form: RBA zero cost)."),
    )
    # ---- I. Data CPMI ----
    birth_place = models.ForeignKey(
        "regions.Regency",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="applicant_profiles_birth_place",
        verbose_name=_("tempat lahir"),
        help_text=_("Kabupaten/Kota tempat lahir."),
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
    province = models.ForeignKey(
        "regions.Province",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="applicant_profiles",
        verbose_name=_("provinsi"),
        help_text=_("Provinsi sesuai KTP."),
    )
    district = models.ForeignKey(
        "regions.Regency",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="applicant_profiles_district",
        verbose_name=_("kota / kabupaten"),
        help_text=_("Kota atau Kabupaten sesuai KTP."),
    )
    village = models.ForeignKey(
        "regions.Village",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="applicant_profiles_address",
        verbose_name=_("kelurahan / desa (alamat KTP)"),
        help_text=_("Pilih kelurahan/desa untuk alamat KTP (provinsi, kabupaten, kecamatan terisi otomatis)."),
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
    family_province = models.ForeignKey(
        "regions.Province",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="applicant_profiles_family",
        verbose_name=_("provinsi (keluarga)"),
        help_text=_("Provinsi alamat keluarga."),
    )
    family_district = models.ForeignKey(
        "regions.Regency",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="applicant_profiles_family_district",
        verbose_name=_("kota / kabupaten (keluarga)"),
        help_text=_("Kota/Kabupaten alamat keluarga."),
    )
    family_village = models.ForeignKey(
        "regions.Village",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="applicant_profiles_family_address",
        verbose_name=_("kelurahan / desa (alamat keluarga)"),
        help_text=_("Pilih kelurahan/desa untuk alamat keluarga."),
    )
    family_contact_phone = models.CharField(
        _("no. HP / WA keluarga yang aktif"),
        max_length=50,
        blank=True,
        help_text=_("Nomor HP/WA keluarga yang aktif."),
    )
    # ---- Pernyataan CPMI (form: pernyataan calon PMI) ----
    data_declaration_confirmed = models.BooleanField(
        _("pernyataan data benar"),
        default=False,
        help_text=_("Apakah data yang diisi benar dan dapat dipertanggungjawabkan (YA/TIDAK)."),
    )
    zero_cost_understood = models.BooleanField(
        _("paham zero cost"),
        default=False,
        help_text=_("Paham bahwa proses penempatan 0 (nol) biaya ditanggung perusahaan."),
    )
    # ---- Identity & profile (data lainnya - form) ----
    nik = models.CharField(
        _("NIK"),
        max_length=16,
        unique=True,
        db_index=True,
        blank=False,
        help_text=_(
            "Nomor Induk Kependudukan (NIK). 16 digit, unik per pelamar. "
            "Wajib diisi saat pendaftaran (dari KTP atau input manual)."
        ),
    )
    gender = models.CharField(
        _("jenis kelamin"),
        max_length=1,
        choices=Gender.choices,
        blank=True,
    )
    religion = models.CharField(
        _("agama"),
        max_length=RELIGION_MAX_LENGTH,
        choices=Religion.choices,
        blank=True,
    )
    education_level = models.CharField(
        _("pendidikan terakhir"),
        max_length=EDUCATION_LEVEL_MAX_LENGTH,
        choices=EducationLevel.choices,
        blank=True,
    )
    education_major = models.CharField(
        _("jurusan pendidikan"),
        max_length=255,
        blank=True,
    )
    height_cm = models.PositiveSmallIntegerField(
        _("tinggi badan (cm)"),
        null=True,
        blank=True,
        help_text=_("Tinggi badan dalam centimeter."),
    )
    weight_kg = models.PositiveSmallIntegerField(
        _("berat badan (kg)"),
        null=True,
        blank=True,
        help_text=_("Berat badan dalam kilogram."),
    )
    wears_glasses = models.BooleanField(
        _("memakai kacamata (mata minus)"),
        null=True,
        blank=True,
        help_text=_("Apakah memakai kacamata (YA/TIDAK)."),
    )
    writing_hand = models.CharField(
        _("menulis dengan tangan"),
        max_length=WRITING_HAND_MAX_LENGTH,
        choices=WritingHand.choices,
        blank=True,
    )
    marital_status = models.CharField(
        _("status perkawinan"),
        max_length=MARITAL_STATUS_MAX_LENGTH,
        choices=MaritalStatus.choices,
        blank=True,
    )
    # ---- Passport Information ----
    has_passport = models.BooleanField(
        _("memiliki paspor"),
        null=True,
        blank=True,
        help_text=_("Apakah memiliki paspor (YA/TIDAK)."),
    )
    passport_number = models.CharField(
        _("nomor paspor"),
        max_length=50,
        blank=True,
    )
    passport_issue_date = models.DateField(
        _("tanggal terbit paspor"),
        null=True,
        blank=True,
        help_text=_("Tanggal paspor diterbitkan."),
    )
    passport_expiry_date = models.DateField(
        _("tanggal berakhir masa berlaku paspor"),
        null=True,
        blank=True,
    )
    passport_issue_place = models.CharField(
        _("tempat terbit paspor"),
        max_length=100,
        blank=True,
        help_text=_("Kota/lokasi paspor diterbitkan (contoh: Jakarta)."),
    )
    family_card_number = models.CharField(
        _("nomor kartu keluarga"),
        max_length=50,
        blank=True,
        help_text=_("Nomor KK."),
    )
    diploma_number = models.CharField(
        _("nomor ijazah"),
        max_length=100,
        blank=True,
    )
    bpjs_number = models.CharField(
        _("nomor BPJS kesehatan / KIS"),
        max_length=50,
        blank=True,
    )
    shoe_size = models.CharField(
        _("ukuran sepatu"),
        max_length=20,
        blank=True,
    )
    shirt_size = models.CharField(
        _("ukuran baju"),
        max_length=20,
        blank=True,
        help_text=_("Contoh: S, M, L, XL, XXL."),
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
        db_index=True,
        help_text=_("Waktu pelamar mengirim untuk verifikasi (status → Dikirim)."),
    )
    verified_at = models.DateTimeField(
        _("diverifikasi pada"),
        null=True,
        blank=True,
        db_index=True,
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
    
    objects = ApplicantProfileManager()

    class Meta:
        verbose_name = _("profil pelamar")
        verbose_name_plural = _("daftar profil pelamar")
        indexes = [
            # FK fields (user, referrer) automatically create indexes, but keep explicit ones for clarity
            # Single field indexes (verification_status has db_index=True, but composite indexes need it)
            models.Index(fields=["created_at"]),
            # Composite indexes for common query patterns
            models.Index(fields=["verification_status", "submitted_at"]),
            models.Index(fields=["verification_status", "created_at"]),
            models.Index(fields=["referrer", "verification_status"]),
            models.Index(fields=["province", "verification_status"]),
            models.Index(fields=["district", "verification_status"]),
            # Frontend filter indexes
            models.Index(fields=["religion", "verification_status"]),
            models.Index(fields=["education_level", "verification_status"]),
            models.Index(fields=["marital_status", "verification_status"]),
            # Time-based queries
            models.Index(fields=["submitted_at", "verification_status"]),
            models.Index(fields=["verified_at", "verification_status"]),
            # Admin review queries
            models.Index(fields=["verification_status", "verified_by", "verified_at"]),
            # Referral tracking
            models.Index(fields=["referrer", "created_at"]),
        ]
        constraints = [
            # Ensure passport expiry is after issue date
            models.CheckConstraint(
                condition=Q(passport_expiry_date__isnull=True)
                | Q(passport_issue_date__isnull=True)
                | Q(passport_expiry_date__gt=models.F("passport_issue_date")),
                name="passport_expiry_after_issue",
            ),
            # Ensure submitted_at is set when status is SUBMITTED or later
            models.CheckConstraint(
                condition=Q(verification_status="DRAFT") | Q(submitted_at__isnull=False),
                name="submitted_at_required_after_draft",
            ),
            # Ensure verified_at is set when status is ACCEPTED or REJECTED
            models.CheckConstraint(
                condition=~Q(verification_status__in=["ACCEPTED", "REJECTED"])
                | Q(verified_at__isnull=False),
                name="verified_at_required_for_final_status",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.user.full_name} ({self.user.email})"
    
    def __repr__(self) -> str:
        return f"<ApplicantProfile: {self.user.full_name} (NIK: {self.nik}, Status: {self.verification_status})>"

    def clean(self) -> None:
        super().clean()
        # Referrer validation
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
        
        # Verification validation
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
        
        # Passport validation
        if self.has_passport and not self.passport_number:
            raise ValidationError(
                {"passport_number": _("Nomor paspor wajib diisi jika memiliki paspor.")}
            )
        
        if self.passport_expiry_date and self.passport_issue_date:
            if self.passport_expiry_date <= self.passport_issue_date:
                raise ValidationError(
                    {"passport_expiry_date": _("Tanggal kadaluarsa harus setelah tanggal terbit.")}
                )
        
        # Birth date validation
        if self.birth_date and self.birth_date > date.today():
            raise ValidationError(
                {"birth_date": _("Tanggal lahir tidak boleh di masa depan.")}
            )
        
        # Age validation for TKI (typically must be 18-45 years old)
        if self.birth_date:
            age = self.age
            if age and (age < 18 or age > 45):
                raise ValidationError(
                    {"birth_date": _("Usia pelamar harus antara 18-45 tahun.")}
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
    
    # ---- Helper methods for workflow ----
    
    def submit_for_verification(self):
        """
        Submit profile for admin verification.
        Changes status from DRAFT to SUBMITTED.
        
        Raises:
            ValidationError: If not in DRAFT status or missing required data
        """
        if self.verification_status != ApplicantVerificationStatus.DRAFT:
            raise ValidationError(_("Hanya profil dengan status Draf yang dapat dikirim."))
        
        # Check required fields
        required_fields = {
            'full_name': self.user.full_name,
            'nik': self.nik,
            'birth_date': self.birth_date,
            'address': self.address,
        }
        missing = [name for name, value in required_fields.items() if not value]
        if missing:
            raise ValidationError(
                _("Field wajib belum diisi: %(fields)s") % {
                    'fields': ', '.join(missing)
                }
            )
        
        self.verification_status = ApplicantVerificationStatus.SUBMITTED
        self.submitted_at = timezone.now()
        self.save(update_fields=['verification_status', 'submitted_at'])
    
    def approve(self, verified_by, notes=''):
        """
        Approve this applicant profile.
        
        Args:
            verified_by: CustomUser (admin/staff) who approved
            notes: Optional approval notes
            
        Raises:
            ValidationError: If profile is not in SUBMITTED status
        """
        if self.verification_status != ApplicantVerificationStatus.SUBMITTED:
            raise ValidationError(
                _("Hanya pelamar dengan status Dikirim yang dapat disetujui.")
            )
        self.verification_status = ApplicantVerificationStatus.ACCEPTED
        self.verified_by = verified_by
        self.verified_at = timezone.now()
        self.verification_notes = notes
        # Ensure submitted_at is set (should be, but set it if missing)
        if not self.submitted_at:
            self.submitted_at = timezone.now()
        self.save(update_fields=[
            'verification_status', 'verified_by',
            'verified_at', 'verification_notes', 'submitted_at'
        ])
    
    def reject(self, verified_by, notes):
        """
        Reject this applicant profile.
        
        Args:
            verified_by: CustomUser (admin/staff) who rejected
            notes: Required rejection reason
            
        Raises:
            ValidationError: If notes is empty or profile is not in SUBMITTED status
        """
        if not notes:
            raise ValidationError(_("Catatan penolakan harus diisi."))
        if self.verification_status != ApplicantVerificationStatus.SUBMITTED:
            raise ValidationError(
                _("Hanya pelamar dengan status Dikirim yang dapat ditolak.")
            )
        
        self.verification_status = ApplicantVerificationStatus.REJECTED
        self.verified_by = verified_by
        self.verified_at = timezone.now()
        self.verification_notes = notes
        # Ensure submitted_at is set (should be, but set it if missing)
        if not self.submitted_at:
            self.submitted_at = timezone.now()
        self.save(update_fields=[
            'verification_status', 'verified_by',
            'verified_at', 'verification_notes', 'submitted_at'
        ])
    
    # ---- Property methods for common calculations ----
    
    @property
    def age(self):
        """Calculate age from birth_date."""
        if not self.birth_date:
            return None
        today = date.today()
        return today.year - self.birth_date.year - (
            (today.month, today.day) < (self.birth_date.month, self.birth_date.day)
        )
    
    @property
    def days_since_submission(self):
        """Days since profile was submitted for review."""
        if not self.submitted_at:
            return None
        return (timezone.now() - self.submitted_at).days
    
    @property
    def is_passport_expired(self):
        """Check if passport is expired."""
        if not self.passport_expiry_date:
            return False
        return self.passport_expiry_date < date.today()
    
    @property
    def document_approval_rate(self):
        """Percentage of approved documents (cached for 5 minutes)."""
        cache_key = f"applicant_{self.id}_doc_approval_rate"
        cached_rate = cache.get(cache_key)
        if cached_rate is not None:
            return cached_rate
        
        total = self.documents.count()
        if total == 0:
            return 0.0
        approved = self.documents.filter(
            review_status=DocumentReviewStatus.APPROVED
        ).count()
        rate = (approved / total) * 100
        
        # Cache for 5 minutes
        cache.set(cache_key, rate, 300)
        return rate
    
    @property
    def has_complete_documents(self):
        """Check if all required documents are uploaded and approved (cached)."""
        cache_key = f"applicant_{self.id}_complete_docs"
        cached_result = cache.get(cache_key)
        if cached_result is not None:
            return cached_result
        
        required_docs = DocumentType.objects.filter(is_required=True)
        for doc_type in required_docs:
            if not self.documents.filter(
                document_type=doc_type,
                review_status=DocumentReviewStatus.APPROVED
            ).exists():
                cache.set(cache_key, False, 300)
                return False
        
        cache.set(cache_key, True, 300)
        return True
    
    def clear_document_cache(self):
        """Clear cached document-related data."""
        cache.delete(f"applicant_{self.id}_doc_approval_rate")
        cache.delete(f"applicant_{self.id}_complete_docs")
    
    def save(self, *args, **kwargs):
        """Override save to auto-populate province/district from village."""
        # Auto-populate province/district from village if not set
        if self.village_id and not self.province_id:
            try:
                self.province = self.village.district.regency.province
            except Exception:
                pass
        if self.village_id and not self.district_id:
            try:
                self.district = self.village.district.regency
            except Exception:
                pass
        
        # Auto-populate family_province/district from family_village if not set
        if self.family_village_id and not self.family_province_id:
            try:
                self.family_province = self.family_village.district.regency.province
            except Exception:
                pass
        if self.family_village_id and not self.family_district_id:
            try:
                self.family_district = self.family_village.district.regency
            except Exception:
                pass
        
        super().save(*args, **kwargs)

# ---------------------------------------------------------------------------
# Pengalaman kerja (per pelamar, terstruktur)
# ---------------------------------------------------------------------------

class WorkExperience(models.Model):
    """
    Satu entri pengalaman kerja per pelamar. Mendukung banyak entri,
    data terstruktur (perusahaan, jabatan, periode), dan urutan tampilan.
    Aligned with FORM PENDATAAN CALON PMI: negara, jenis industri, bagian/bidang.
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
        help_text=_("Nama perusahaan atau pemberi kerja (form: contoh PT. MAJU JAYA - MEDAN)."),
    )
    location = models.CharField(
        _("kota / lokasi perusahaan"),
        max_length=255,
        blank=True,
        help_text=_("Kota atau lokasi perusahaan (form: nama perusahaan dan kotanya)."),
    )
    country = CountryField(
        _("negara tempat bekerja"),
        blank=True,
        help_text=_("Negara tempat bekerja (ISO 3166-1 alpha-2, e.g. ID, MY)."),
    )
    industry_type = models.CharField(
        _("jenis industri perusahaan"),
        max_length=INDUSTRY_TYPE_MAX_LENGTH,
        choices=IndustryType.choices,
        blank=True,
        help_text=_("Semiconductor, Elektronik, Pabrik Lain, Jasa, Lain Lain, Belum Pernah Bekerja."),
    )
    position = models.CharField(
        _("jabatan / posisi"),
        max_length=255,
        blank=True,
        help_text=_("Jabatan (contoh: Operator, Leader, Supervisor)."),
    )
    department = models.CharField(
        _("bagian / bidang pekerjaan"),
        max_length=255,
        blank=True,
        help_text=_("Bagi pekerja kilang/pabrik: QC, SMT, Moulding, Packing, dll."),
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
            models.Index(fields=["country"]),  # For filtering by work country
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
        return f"{self.company_name} – {self.position or '-'} ({self.applicant_profile.user.full_name})"
    
    def __repr__(self) -> str:
        return f"<WorkExperience: {self.company_name} - {self.position or 'N/A'} ({self.applicant_profile.user.full_name})>"


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
    
    def __repr__(self) -> str:
        return f"<DocumentType: {self.code} - {self.name} (Required: {self.is_required})>"
    
    @classmethod
    def get_all_cached(cls, timeout=3600):
        """Get all document types from cache (1 hour default)."""
        cache_key = 'document_types_all'
        doc_types = cache.get(cache_key)
        if doc_types is None:
            doc_types = list(cls.objects.all())
            cache.set(cache_key, doc_types, timeout)
        return doc_types
    
    @classmethod
    def get_required_cached(cls, timeout=3600):
        """Get only required document types from cache."""
        cache_key = 'document_types_required'
        doc_types = cache.get(cache_key)
        if doc_types is None:
            doc_types = list(cls.objects.filter(is_required=True))
            cache.set(cache_key, doc_types, timeout)
        return doc_types
    
    def save(self, *args, **kwargs):
        """Invalidate cache when document types change."""
        super().save(*args, **kwargs)
        cache.delete('document_types_all')
        cache.delete('document_types_required')
    
    def delete(self, *args, **kwargs):
        """Invalidate cache when document types are deleted."""
        super().delete(*args, **kwargs)
        cache.delete('document_types_all')
        cache.delete('document_types_required')


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

    full_name_slug = slugify(profile.user.full_name or "") or "applicant"
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
    
    objects = ApplicantDocumentManager()

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
            models.Index(fields=["review_status", "uploaded_at"]),
            models.Index(fields=["document_type", "review_status"]),
        ]

    def __str__(self) -> str:
        return f"{self.applicant_profile.user.full_name} – {self.document_type.name}"
    
    def __repr__(self) -> str:
        doc_type = self.document_type.code if self.document_type_id else 'unknown'
        nik = self.applicant_profile.nik if self.applicant_profile_id else 'N/A'
        return f"<ApplicantDocument: {doc_type} for NIK {nik}>"

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
                # Invalidate cache if review status changed
                if old.review_status != self.review_status:
                    if self.applicant_profile_id:
                        self.applicant_profile.clear_document_cache()
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
    
    def __repr__(self) -> str:
        return f"<CompanyProfile: {self.company_name} ({self.user.email})>"