from django.db import models
from django.utils.translation import gettext_lazy as _
from django.core.files.base import ContentFile

from account.models import CompanyProfile, CustomUser, UserRole

from PIL import Image
from io import BytesIO


# ---------------------------------------------------------------------------
# Main site content: Berita (News) dan Lowongan Kerja
# ---------------------------------------------------------------------------


class NewsStatus(models.TextChoices):
    """Status publikasi berita di halaman utama."""

    DRAFT = "DRAFT", _("Draf")
    PUBLISHED = "PUBLISHED", _("Dipublikasikan")
    ARCHIVED = "ARCHIVED", _("Diarsipkan")


class EmploymentType(models.TextChoices):
    """Jenis hubungan kerja untuk lowongan."""

    FULL_TIME = "FULL_TIME", _("Penuh waktu")
    PART_TIME = "PART_TIME", _("Paruh waktu")
    CONTRACT = "CONTRACT", _("Kontrak")
    INTERNSHIP = "INTERNSHIP", _("Magang")


class JobStatus(models.TextChoices):
    """Status siklus hidup lowongan kerja."""

    DRAFT = "DRAFT", _("Draf")
    OPEN = "OPEN", _("Dibuka")
    CLOSED = "CLOSED", _("Ditutup")
    ARCHIVED = "ARCHIVED", _("Diarsipkan")


class News(models.Model):
    """
    Berita/informasi umum untuk halaman utama aplikasi.

    Digunakan untuk menampilkan pengumuman, berita perusahaan, atau informasi
    terkait program penempatan TKI.
    """

    title = models.CharField(
        _("judul"),
        max_length=255,
        help_text=_("Judul singkat berita."),
    )
    slug = models.SlugField(
        _("slug"),
        max_length=255,
        unique=True,
        help_text=_("Slug unik untuk URL berita."),
    )
    summary = models.CharField(
        _("ringkasan"),
        max_length=500,
        blank=True,
        help_text=_("Ringkasan singkat yang tampil di daftar berita."),
    )
    content = models.TextField(
        _("isi berita"),
        help_text=_("Konten lengkap berita (teks HTML/markdown yang sudah diformat)."),
    )
    hero_image = models.ImageField(
        _("gambar utama"),
        upload_to="main/news/%Y/%m/",
        blank=True,
        null=True,
        help_text=_("Gambar utama opsional untuk ditampilkan di halaman detail berita."),
    )
    status = models.CharField(
        _("status"),
        max_length=10,
        choices=NewsStatus.choices,
        default=NewsStatus.DRAFT,
        db_index=True,
    )
    is_pinned = models.BooleanField(
        _("sematkan di atas"),
        default=False,
        help_text=_("Jika dicentang, berita akan muncul di bagian atas daftar."),
    )
    published_at = models.DateTimeField(
        _("dipublikasikan pada"),
        null=True,
        blank=True,
        help_text=_("Waktu ketika berita dipublikasikan."),
    )
    created_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="news_created",
        limit_choices_to={"role__in": [UserRole.ADMIN, UserRole.STAFF]},
        verbose_name=_("dibuat oleh"),
        help_text=_("Admin/Staf yang membuat berita ini."),
    )
    created_at = models.DateTimeField(_("dibuat pada"), auto_now_add=True)
    updated_at = models.DateTimeField(_("diperbarui pada"), auto_now=True)

    def _optimize_hero_image(self) -> None:
        """
        Optimize hero_image to a reasonable size and quality to keep
        frontend loading fast. Runs only when hero_image is present.
        """
        if not self.hero_image:
            return

        try:
            img = Image.open(self.hero_image)
        except Exception:
            # If the file is not a valid image, skip optimization.
            return

        # Convert to RGB (handles PNG with alpha, etc.)
        if img.mode not in ("RGB", "L"):
            img = img.convert("RGB")

        # Resize while keeping aspect ratio; max width/height
        max_size = (1600, 900)
        img.thumbnail(max_size, Image.LANCZOS)

        buffer = BytesIO()
        # Use JPEG for good compression; keep original extension in name
        img.save(buffer, format="JPEG", quality=80, optimize=True)
        buffer.seek(0)

        # Replace the file content without changing the storage path
        file_name = self.hero_image.name.rsplit("/", 1)[-1]
        optimized_name = f"optimized-{file_name}"
        self.hero_image.save(optimized_name, ContentFile(buffer.read()), save=False)

    def save(self, *args, **kwargs):
        # Run base save first to ensure we have a file on disk/storage
        super().save(*args, **kwargs)
        # Then optimize the image if present
        if self.hero_image:
            self._optimize_hero_image()
            # Save again to persist optimized image; avoid recursion by not re-optimizing
            super().save(update_fields=["hero_image"])

    class Meta:
        verbose_name = _("berita")
        verbose_name_plural = _("daftar berita")
        ordering = ["-is_pinned", "-published_at", "-created_at"]
        indexes = [
            models.Index(fields=["status", "published_at"]),
            models.Index(fields=["is_pinned", "status"]),
        ]

    def __str__(self) -> str:
        return self.title


class LowonganKerja(models.Model):
    """
    Lowongan kerja (job posting) yang dapat dilamar oleh pelamar TKI.

    Fokus pada informasi inti: posisi, perusahaan, lokasi, gaji, dan status.
    """

    title = models.CharField(
        _("judul lowongan"),
        max_length=255,
        help_text=_("Nama posisi atau judul lowongan."),
    )
    slug = models.SlugField(
        _("slug"),
        max_length=255,
        unique=True,
        help_text=_("Slug unik untuk URL lowongan."),
    )
    company = models.ForeignKey(
        CompanyProfile,
        on_delete=models.PROTECT,
        related_name="job_listings",
        verbose_name=_("perusahaan"),
        help_text=_("Perusahaan yang membuka lowongan."),
    )
    location_country = models.CharField(
        _("negara penempatan"),
        max_length=100,
        blank=True,
        help_text=_("Negara tempat kerja (mis. Taiwan, Hong Kong)."),
    )
    location_city = models.CharField(
        _("kota / area"),
        max_length=100,
        blank=True,
        help_text=_("Kota atau area penempatan (opsional)."),
    )
    description = models.TextField(
        _("deskripsi pekerjaan"),
        help_text=_("Deskripsi tugas utama dan tanggung jawab."),
    )
    requirements = models.TextField(
        _("persyaratan"),
        blank=True,
        help_text=_("Syarat kualifikasi, pengalaman, dan dokumen khusus."),
    )
    employment_type = models.CharField(
        _("jenis kerja"),
        max_length=20,
        choices=EmploymentType.choices,
        default=EmploymentType.FULL_TIME,
        db_index=True,
    )
    salary_min = models.PositiveIntegerField(
        _("gaji minimum"),
        null=True,
        blank=True,
        help_text=_("Perkiraan gaji minimum (dalam satuan mata uang yang sama)."),
    )
    salary_max = models.PositiveIntegerField(
        _("gaji maksimum"),
        null=True,
        blank=True,
        help_text=_("Perkiraan gaji maksimum (opsional)."),
    )
    currency = models.CharField(
        _("mata uang"),
        max_length=10,
        default="IDR",
        help_text=_("Kode mata uang (mis. IDR, TWD, HKD)."),
    )
    status = models.CharField(
        _("status"),
        max_length=10,
        choices=JobStatus.choices,
        default=JobStatus.DRAFT,
        db_index=True,
    )
    posted_at = models.DateTimeField(
        _("diposting pada"),
        null=True,
        blank=True,
        help_text=_("Waktu lowongan mulai ditayangkan ke publik."),
    )
    deadline = models.DateTimeField(
        _("batas akhir lamaran"),
        null=True,
        blank=True,
        help_text=_("Tanggal/waktu terakhir penerimaan lamaran (opsional)."),
    )
    created_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="job_listings_created",
        limit_choices_to={"role__in": [UserRole.ADMIN, UserRole.STAFF, UserRole.COMPANY]},
        verbose_name=_("dibuat oleh"),
        help_text=_("Admin/Staf/Perusahaan yang membuat lowongan ini."),
    )
    created_at = models.DateTimeField(_("dibuat pada"), auto_now_add=True)
    updated_at = models.DateTimeField(_("diperbarui pada"), auto_now=True)

    class Meta:
        verbose_name = _("lowongan kerja")
        verbose_name_plural = _("daftar lowongan kerja")
        ordering = ["-posted_at", "-created_at"]
        indexes = [
            models.Index(fields=["status", "employment_type"]),
            models.Index(fields=["company", "status"]),
            models.Index(fields=["deadline"]),
        ]

    def __str__(self) -> str:
        return f"{self.title} – {self.company.company_name}"


# ---------------------------------------------------------------------------
# Job Application (Lamaran Kerja)
# ---------------------------------------------------------------------------


class ApplicationStatus(models.TextChoices):
    """Status lamaran kerja."""

    APPLIED = "APPLIED", _("Dilamar")
    UNDER_REVIEW = "UNDER_REVIEW", _("Dalam Review")
    ACCEPTED = "ACCEPTED", _("Diterima")
    REJECTED = "REJECTED", _("Ditolak")


class JobApplication(models.Model):
    """
    Lamaran kerja pelamar untuk lowongan tertentu.
    Menghubungkan ApplicantProfile dengan LowonganKerja.
    """

    applicant = models.ForeignKey(
        "account.ApplicantProfile",
        on_delete=models.CASCADE,
        related_name="job_applications",
        verbose_name=_("pelamar"),
        help_text=_("Pelamar yang melamar pekerjaan ini."),
    )
    job = models.ForeignKey(
        LowonganKerja,
        on_delete=models.CASCADE,
        related_name="applications",
        verbose_name=_("lowongan"),
        help_text=_("Lowongan kerja yang dilamar."),
    )
    status = models.CharField(
        _("status"),
        max_length=20,
        choices=ApplicationStatus.choices,
        default=ApplicationStatus.APPLIED,
        db_index=True,
        help_text=_("Status lamaran kerja."),
    )
    applied_at = models.DateTimeField(
        _("dilamar pada"),
        auto_now_add=True,
        db_index=True,
        help_text=_("Waktu pelamar mengajukan lamaran."),
    )
    reviewed_at = models.DateTimeField(
        _("direview pada"),
        null=True,
        blank=True,
        help_text=_("Waktu lamaran direview oleh admin/staff."),
    )
    reviewed_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reviewed_applications",
        limit_choices_to={"role__in": [UserRole.ADMIN, UserRole.STAFF]},
        verbose_name=_("direview oleh"),
        help_text=_("Admin atau Staff yang mereview lamaran ini."),
    )
    notes = models.TextField(
        _("catatan"),
        blank=True,
        help_text=_("Catatan internal atau feedback untuk pelamar."),
    )
    created_at = models.DateTimeField(_("dibuat pada"), auto_now_add=True)
    updated_at = models.DateTimeField(_("diperbarui pada"), auto_now=True)

    class Meta:
        verbose_name = _("lamaran kerja")
        verbose_name_plural = _("daftar lamaran kerja")
        ordering = ["-applied_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["applicant", "job"],
                name="main_jobapplication_unique_applicant_job",
            ),
        ]
        indexes = [
            models.Index(fields=["applicant", "status"]),
            models.Index(fields=["job", "status"]),
            models.Index(fields=["status", "applied_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.applicant.user.full_name} – {self.job.title} ({self.get_status_display()})"

