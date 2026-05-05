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
        limit_choices_to={
            "role__in": [UserRole.MASTER_ADMIN, UserRole.ADMIN, UserRole.STAFF]
        },
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
        null=True,
        blank=True,
        verbose_name=_("perusahaan"),
        help_text=_("Perusahaan yang membuka lowongan (opsional)."),
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
        limit_choices_to={
            "role__in": [
                UserRole.MASTER_ADMIN,
                UserRole.ADMIN,
                UserRole.STAFF,
                UserRole.COMPANY,
            ]
        },
        verbose_name=_("dibuat oleh"),
        help_text=_("Admin/Staf/Perusahaan yang membuat lowongan ini."),
    )
    start_date = models.DateField(
        _("tanggal mulai kerja"),
        null=True,
        blank=True,
        help_text=_(
            "Target tanggal pelamar mulai bekerja. "
            "Digunakan sebagai informasi bagi pelamar dan admin."
        ),
    )
    quota = models.PositiveSmallIntegerField(
        _("kuota pelamar"),
        null=True,
        blank=True,
        help_text=_(
            "Jumlah maksimum pelamar yang diterima untuk lowongan ini. "
            "Kosongkan jika tidak ada batasan."
        ),
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
            models.Index(fields=["start_date"]),
        ]

    def clean(self):
        from django.core.exceptions import ValidationError
        if self.start_date and self.deadline:
            if self.start_date < self.deadline.date():
                raise ValidationError(
                    {"start_date": _("Tanggal mulai kerja tidak boleh sebelum batas akhir lamaran.")}
                )

    def __str__(self) -> str:
        company_name = self.company.company_name if self.company else "-"
        return f"{self.title} – {company_name}"


# ---------------------------------------------------------------------------
# Lamaran (Application) — Stage-based FSM
# ---------------------------------------------------------------------------


class ApplicationStatus(models.TextChoices):
    """
    Status lamaran kerja — 7-tahap Finite State Machine (FSM).

    Semua lamaran dibuat oleh admin melalui batch assignment.
    Tidak ada self-apply — admin memilih pelamar ke dalam LamaranBatch.

    Flow:
      PRA_SELEKSI → INTERVIEW → DITERIMA → BERANGKAT → SELESAI
      INTERVIEW → CADANGAN → DITERIMA | DITOLAK  (jalur cadangan)
      PRA_SELEKSI | INTERVIEW | CADANGAN | DITERIMA → DITOLAK  (terminal negatif)

    CADANGAN: Pelamar lulus interview namun ditempatkan sebagai cadangan.
    Dapat dipromosikan ke DITERIMA jika slot utama mundur.

    Pelamar mengkonfirmasi kehadiran di tahap PRA_SELEKSI dan INTERVIEW.
    Transitions ditegakkan di main.services.ApplicationService.
    """

    PRA_SELEKSI = "PRA_SELEKSI", _("Tahap Pra-Seleksi")
    INTERVIEW   = "INTERVIEW",   _("Tahap Interview")
    CADANGAN    = "CADANGAN",    _("Tahap Cadangan")   # reserve: menunggu slot
    DITERIMA    = "DITERIMA",    _("Tahap Diterima")
    DITOLAK     = "DITOLAK",     _("Tahap Ditolak")    # terminal: negatif
    BERANGKAT   = "BERANGKAT",   _("Tahap Berangkat")
    SELESAI     = "SELESAI",     _("Tahap Selesai")    # terminal: positif — cooldown 2 thn


# ---------------------------------------------------------------------------
# LamaranBatch — Group container for batch assignment
# ---------------------------------------------------------------------------


class LamaranBatch(models.Model):
    """
    Satu **tahapan pra-seleksi** untuk sebuah lowongan kerja.

    Sebuah lowongan dapat memiliki banyak `LamaranBatch` (mis. tahap 1: CV
    screening, tahap 2: psikotes, tahap 3: FGD). Setiap batch hanya berisi
    pelamar yang sedang berada di tahap pra-seleksi tersebut.

    Begitu pelamar lulus tahapan pra-seleksi, admin memindahkan mereka ke
    `InterviewCohort` (jadwal interview yang dapat berbeda per kelompok).
    Sejak status `INTERVIEW` ke atas, "wadah" operasional pelamar adalah
    `InterviewCohort`, bukan lagi `LamaranBatch`.

    Catatan kompatibilitas:
    - Kolom `interview_date / interview_location / interview_notes` tetap ada
      sementara untuk menjaga kompatibilitas data lama dan response API mobile.
      Kolom-kolom tersebut **deprecated** dan akan dihapus pada rilis berikutnya
      setelah seluruh klien (admin web + mobile) memakai `InterviewCohort`.
    """

    job = models.ForeignKey(
        LowonganKerja,
        on_delete=models.CASCADE,
        related_name="batches",
        verbose_name=_("lowongan"),
        help_text=_("Lowongan kerja yang menjadi target batch ini."),
    )
    name = models.CharField(
        _("nama batch"),
        max_length=100,
        help_text=_("Nama identifikasi batch, misal: 'Batch Maret 2026'."),
    )
    notes = models.TextField(
        _("catatan"),
        blank=True,
        help_text=_("Catatan internal admin mengenai batch ini."),
    )

    # --- Tahapan pra-seleksi (urutan dalam lowongan) ---
    tahap_order = models.PositiveSmallIntegerField(
        _("urutan tahapan"),
        default=1,
        db_index=True,
        help_text=_(
            "Urutan tahapan pra-seleksi dalam lowongan ini (1 = tahap pertama). "
            "Lowongan dapat memiliki banyak tahapan pra-seleksi (mis. CV → "
            "Psikotes → FGD). Tidak harus unik — admin bisa membuat sub-batch "
            "paralel pada tahap yang sama."
        ),
    )
    tahap_label = models.CharField(
        _("label tahapan"),
        max_length=120,
        blank=True,
        help_text=_(
            "Label deskriptif untuk tahapan, mis. 'Pra-Seleksi 1: CV Screening'. "
            "Opsional; jika kosong, frontend menampilkan 'Pra-Seleksi {tahap_order}'."
        ),
    )

    # --- Jadwal Pra-Seleksi ---
    pra_seleksi_date = models.DateTimeField(
        _("tanggal & jam pra-seleksi"),
        null=True,
        blank=True,
        db_index=True,
        help_text=_("Tanggal dan jam pelaksanaan tahap pra-seleksi."),
    )
    pra_seleksi_location = models.CharField(
        _("lokasi pra-seleksi"),
        max_length=255,
        blank=True,
        help_text=_("Lokasi atau link (online/offline) pelaksanaan pra-seleksi."),
    )
    pra_seleksi_notes = models.TextField(
        _("info pra-seleksi"),
        blank=True,
        help_text=_("Instruksi atau informasi tambahan untuk pelamar mengenai pra-seleksi."),
    )

    # --- DEPRECATED: jadwal interview pindah ke InterviewCohort ---
    # Kolom dipertahankan agar response API & data historis tetap kompatibel.
    interview_date = models.DateTimeField(
        _("tanggal & jam interview (deprecated)"),
        null=True,
        blank=True,
        db_index=True,
        help_text=_(
            "DEPRECATED. Jadwal interview kini disimpan di InterviewCohort. "
            "Kolom ini hanya dipakai sebagai fallback untuk data lama."
        ),
    )
    interview_location = models.CharField(
        _("lokasi interview (deprecated)"),
        max_length=255,
        blank=True,
        help_text=_("DEPRECATED. Lihat InterviewCohort.interview_location."),
    )
    interview_notes = models.TextField(
        _("info interview (deprecated)"),
        blank=True,
        help_text=_("DEPRECATED. Lihat InterviewCohort.interview_notes."),
    )

    # --- Actors ---
    created_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="batches_created",
        limit_choices_to={
            "role__in": [UserRole.MASTER_ADMIN, UserRole.ADMIN, UserRole.STAFF]
        },
        verbose_name=_("dibuat oleh"),
        help_text=_("Admin/Staf yang membuat batch ini."),
    )
    created_at = models.DateTimeField(_("dibuat pada"), auto_now_add=True)
    updated_at = models.DateTimeField(_("diperbarui pada"), auto_now=True)

    class Meta:
        verbose_name = _("batch lamaran (tahap pra-seleksi)")
        verbose_name_plural = _("daftar batch lamaran (tahap pra-seleksi)")
        ordering = ["job", "tahap_order", "-created_at"]
        indexes = [
            models.Index(fields=["job", "tahap_order"]),
            models.Index(fields=["job", "created_at"]),
            models.Index(fields=["pra_seleksi_date"]),
        ]

    def __str__(self) -> str:
        suffix = f" — {self.job.title}" if self.job_id else ""
        return f"{self.name}{suffix}"

    @property
    def display_tahap_label(self) -> str:
        """Human-friendly label untuk tahapan ini ("Pra-Seleksi 2: Psikotes")."""
        if self.tahap_label:
            return self.tahap_label
        return f"Pra-Seleksi {self.tahap_order}"

    @property
    def applicant_count(self) -> int:
        return self.applications.count()

    @property
    def confirmed_pra_seleksi_count(self) -> int:
        return self.applications.filter(pra_seleksi_confirmed_at__isnull=False).count()

    @property
    def confirmed_interview_count(self) -> int:
        return self.applications.filter(interview_confirmed_at__isnull=False).count()


# ---------------------------------------------------------------------------
# InterviewCohort — wadah operasional pelamar dari INTERVIEW sampai SELESAI
# ---------------------------------------------------------------------------


class InterviewCohort(models.Model):
    """
    Satu sesi interview untuk sebuah lowongan + kelompok pelamar yang
    melanjutkan dari interview sampai selesai/diterima/berangkat/selesai.

    Beberapa `LamaranBatch` (tahapan pra-seleksi) dapat mengirimkan
    survivor-nya ke satu cohort yang sama, atau ke cohort yang berbeda —
    routing ditentukan admin pada saat transisi PRA_SELEKSI → INTERVIEW.

    Tidak ada kendala unik per lowongan: admin bebas membuat banyak cohort
    (mis. "Sesi Pagi" dan "Sesi Sore" pada hari yang sama).
    """

    job = models.ForeignKey(
        LowonganKerja,
        on_delete=models.CASCADE,
        related_name="interview_cohorts",
        verbose_name=_("lowongan"),
        help_text=_("Lowongan tempat sesi interview ini diadakan."),
    )
    name = models.CharField(
        _("nama sesi interview"),
        max_length=120,
        help_text=_("Identitas singkat sesi interview, mis. 'Interview 5 Mei 2026 — Sesi Pagi'."),
    )
    notes = models.TextField(
        _("catatan"),
        blank=True,
        help_text=_("Catatan internal admin untuk sesi ini."),
    )

    interview_date = models.DateTimeField(
        _("tanggal & jam interview"),
        null=True,
        blank=True,
        db_index=True,
        help_text=_("Tanggal dan jam pelaksanaan interview untuk cohort ini."),
    )
    interview_location = models.CharField(
        _("lokasi interview"),
        max_length=255,
        blank=True,
        help_text=_("Lokasi atau link (online/offline) pelaksanaan interview."),
    )
    interview_notes = models.TextField(
        _("info interview"),
        blank=True,
        help_text=_("Informasi tambahan untuk pelamar (dress code, dokumen, link, dll.)."),
    )

    is_active = models.BooleanField(
        _("aktif"),
        default=True,
        db_index=True,
        help_text=_(
            "Tandai non-aktif jika sesi sudah selesai dan tidak boleh menerima "
            "pelamar baru. Cohort tetap menyimpan riwayat pelamar yang sudah "
            "berada di dalamnya."
        ),
    )

    created_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="interview_cohorts_created",
        limit_choices_to={
            "role__in": [UserRole.MASTER_ADMIN, UserRole.ADMIN, UserRole.STAFF]
        },
        verbose_name=_("dibuat oleh"),
        help_text=_("Admin/Staf yang membuat sesi interview ini."),
    )
    created_at = models.DateTimeField(_("dibuat pada"), auto_now_add=True)
    updated_at = models.DateTimeField(_("diperbarui pada"), auto_now=True)

    class Meta:
        verbose_name = _("sesi interview")
        verbose_name_plural = _("daftar sesi interview")
        ordering = ["job", "-interview_date", "-created_at"]
        indexes = [
            models.Index(fields=["job", "is_active"]),
            models.Index(fields=["interview_date"]),
        ]

    def __str__(self) -> str:
        suffix = f" — {self.job.title}" if self.job_id else ""
        return f"{self.name}{suffix}"

    @property
    def applicant_count(self) -> int:
        return self.applications.count()

    @property
    def confirmed_interview_count(self) -> int:
        return self.applications.filter(interview_confirmed_at__isnull=False).count()


# ---------------------------------------------------------------------------
# JobApplication — Individual application inside a batch
# ---------------------------------------------------------------------------


class JobApplication(models.Model):
    """
    Lamaran kerja individual pelamar dalam sebuah LamaranBatch.

    Setiap pelamar punya record sendiri sehingga tracking status,
    konfirmasi, dan riwayat tetap granular per-individu.

    Cooldown rule: setelah status = SELESAI dan placement_end_date diisi,
    pelamar harus menunggu 2 tahun sebelum dapat dimasukkan ke batch baru.
    Aturan ditegakkan di main.services.ApplicationService.

    Pelamar hanya bisa aktif di SATU lamaran pada satu waktu.
    ACTIVE_STATUSES digunakan untuk mencegah duplikat lintas lowongan.
    """

    # Statuses that block an applicant from being assigned to a new batch/job.
    ACTIVE_STATUSES = [
        ApplicationStatus.PRA_SELEKSI,
        ApplicationStatus.INTERVIEW,
        ApplicationStatus.CADANGAN,
        ApplicationStatus.DITERIMA,
        ApplicationStatus.BERANGKAT,
    ]

    # Terminal statuses — no further transitions possible.
    TERMINAL_STATUSES = [
        ApplicationStatus.DITOLAK,
        ApplicationStatus.SELESAI,
    ]

    REAPPLY_COOLDOWN_YEARS = 2
    ATTENDANCE_TRACKED_STATUSES = [
        ApplicationStatus.PRA_SELEKSI,
        ApplicationStatus.INTERVIEW,
        ApplicationStatus.CADANGAN,
        ApplicationStatus.DITERIMA,
        ApplicationStatus.BERANGKAT,
        ApplicationStatus.SELESAI,
        ApplicationStatus.DITOLAK,
    ]

    # --- Core relations ---
    applicant = models.ForeignKey(
        "account.ApplicantProfile",
        on_delete=models.CASCADE,
        related_name="job_applications",
        verbose_name=_("pelamar"),
        help_text=_("Pelamar yang terdaftar dalam batch lamaran ini."),
    )
    job = models.ForeignKey(
        LowonganKerja,
        on_delete=models.CASCADE,
        related_name="applications",
        verbose_name=_("lowongan"),
        help_text=_("Lowongan kerja yang dilamar (denormalized dari batch untuk query efisien)."),
    )
    batch = models.ForeignKey(
        LamaranBatch,
        on_delete=models.CASCADE,
        related_name="applications",
        null=True,
        blank=True,
        verbose_name=_("batch pra-seleksi"),
        help_text=_(
            "Batch (tahap pra-seleksi) tempat pelamar ini sedang berada. "
            "Dapat dipindahkan antar batch saat masih di status PRA_SELEKSI."
        ),
    )
    interview_cohort = models.ForeignKey(
        "InterviewCohort",
        on_delete=models.PROTECT,
        related_name="applications",
        null=True,
        blank=True,
        db_index=True,
        verbose_name=_("sesi interview"),
        help_text=_(
            "Cohort interview tempat pelamar ini ditempatkan saat dipindahkan "
            "ke status INTERVIEW. Sejak status INTERVIEW ke atas, semua aksi "
            "bulk (transition, announcement, export) dilakukan pada cohort, "
            "bukan lagi pada batch."
        ),
    )

    # --- Status ---
    status = models.CharField(
        _("status"),
        max_length=15,
        choices=ApplicationStatus.choices,
        default=ApplicationStatus.PRA_SELEKSI,
        db_index=True,
        help_text=_("Status tahap lamaran saat ini."),
    )

    # --- Konfirmasi kehadiran oleh pelamar ---
    pra_seleksi_confirmed_at = models.DateTimeField(
        _("konfirmasi pra-seleksi pada"),
        null=True,
        blank=True,
        help_text=_(
            "Waktu pelamar mengkonfirmasi kehadiran di tahap pra-seleksi. "
            "Null berarti belum dikonfirmasi."
        ),
    )
    interview_confirmed_at = models.DateTimeField(
        _("konfirmasi interview pada"),
        null=True,
        blank=True,
        help_text=_(
            "Waktu pelamar mengkonfirmasi kehadiran di tahap interview. "
            "Null berarti belum dikonfirmasi."
        ),
    )
    attendance_by_stage = models.JSONField(
        _("kehadiran per tahap"),
        default=dict,
        blank=True,
        help_text=_(
            "Peta waktu kehadiran per tahap. Format: "
            '{"PRA_SELEKSI":"2026-01-01T10:00:00+07:00","INTERVIEW":"..."}'
        ),
    )

    # --- Timestamps ---
    applied_at = models.DateTimeField(
        _("ditugaskan pada"),
        auto_now_add=True,
        db_index=True,
        help_text=_("Waktu admin memasukkan pelamar ke batch ini."),
    )
    reviewed_at = models.DateTimeField(
        _("direview pada"),
        null=True,
        blank=True,
        help_text=_("Waktu terakhir status diubah oleh admin/staff."),
    )
    placement_end_date = models.DateField(
        _("tanggal selesai kerja"),
        null=True,
        blank=True,
        db_index=True,
        help_text=_(
            "Tanggal pelamar selesai bekerja. "
            "Diisi saat status berubah ke SELESAI. "
            "Cooldown 2 tahun dihitung dari tanggal ini."
        ),
    )

    # --- Actors ---
    reviewed_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reviewed_applications",
        limit_choices_to={
            "role__in": [UserRole.MASTER_ADMIN, UserRole.ADMIN, UserRole.STAFF]
        },
        verbose_name=_("direview oleh"),
        help_text=_("Admin atau Staff yang terakhir mengubah status lamaran ini."),
    )
    assigned_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assigned_applications",
        limit_choices_to={
            "role__in": [UserRole.MASTER_ADMIN, UserRole.ADMIN, UserRole.STAFF]
        },
        verbose_name=_("ditugaskan oleh"),
        help_text=_("Admin atau Staff yang memasukkan pelamar ke batch ini."),
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
        indexes = [
            # Primary lookup patterns
            models.Index(fields=["applicant", "status"]),
            models.Index(fields=["job", "status"]),
            models.Index(fields=["batch", "status"]),
            models.Index(fields=["interview_cohort", "status"]),
            models.Index(fields=["status", "applied_at"]),
            # Eligibility check: applicant active across any job
            models.Index(fields=["applicant", "status", "job"]),
            # Cooldown query: applicant + SELESAI + placement_end_date
            models.Index(fields=["applicant", "status", "placement_end_date"]),
        ]
        constraints = [
            # One active application per applicant per job at a time.
            # Enforced at service layer too, but DB constraint as final safety net.
            models.UniqueConstraint(
                fields=["applicant", "job"],
                condition=models.Q(
                    status__in=["PRA_SELEKSI", "INTERVIEW", "DITERIMA", "BERANGKAT"]
                ),
                name="unique_active_application_per_applicant_job",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.applicant.user.full_name} – {self.job.title} ({self.get_status_display()})"

    @property
    def cooldown_eligible_date(self):
        """Date from which this applicant may be re-assigned (placement_end_date + 2yr).
        Returns None if the application has not yet reached SELESAI."""
        if not self.placement_end_date:
            return None
        from dateutil.relativedelta import relativedelta
        return self.placement_end_date + relativedelta(years=self.REAPPLY_COOLDOWN_YEARS)


# ---------------------------------------------------------------------------
# Application Status History (append-only audit log)
# ---------------------------------------------------------------------------


class ApplicationStatusHistory(models.Model):
    """
    Immutable audit trail for every status change on a JobApplication.
    Rows are never updated or deleted — append only.
    Written atomically alongside every status change in ApplicationService.
    """

    application = models.ForeignKey(
        JobApplication,
        on_delete=models.CASCADE,
        related_name="status_history",
        verbose_name=_("lamaran"),
    )
    from_status = models.CharField(
        _("dari status"),
        max_length=15,
        blank=True,
        help_text=_("Status sebelum perubahan. Kosong jika ini entri awal pembuatan."),
    )
    to_status = models.CharField(
        _("ke status"),
        max_length=15,
        choices=ApplicationStatus.choices,
        help_text=_("Status setelah perubahan."),
    )
    changed_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="application_status_changes",
        verbose_name=_("diubah oleh"),
    )
    changed_at = models.DateTimeField(_("diubah pada"), auto_now_add=True, db_index=True)
    note = models.TextField(_("catatan"), blank=True)

    class Meta:
        verbose_name = _("riwayat status lamaran")
        verbose_name_plural = _("riwayat status lamaran")
        ordering = ["changed_at"]
        indexes = [
            models.Index(fields=["application", "changed_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.application} | {self.from_status or '(baru)'} → {self.to_status}"


# ---------------------------------------------------------------------------
# BatchAnnouncement — broadcast pesan admin ke semua pelamar dalam satu batch
# ---------------------------------------------------------------------------


def default_batch_announcement_recipient_config():
    """Default JSON for BatchAnnouncement.recipient_config (callable for JSONField)."""
    return {"selection_type": "all_active"}


class BatchAnnouncement(models.Model):
    """
    Pengumuman/broadcast dari admin untuk semua pelamar dalam satu batch.

    Digunakan pada tahap PRA_SELEKSI dan INTERVIEW sebagai pengganti
    chat individual — satu pesan dari admin menjangkau semua pelamar dalam batch,
    lebih efisien daripada ChatThread per-pelamar.

    Pelamar membaca pengumuman ini via endpoint lamaran mereka.
    """

    batch = models.ForeignKey(
        LamaranBatch,
        on_delete=models.CASCADE,
        related_name="announcements",
        verbose_name=_("batch"),
        help_text=_("Batch penerima pengumuman ini."),
    )
    title = models.CharField(
        _("judul"),
        max_length=200,
        help_text=_("Judul singkat pengumuman, misal: 'Jadwal Pra-Seleksi Diperbarui'."),
    )
    body = models.TextField(
        _("isi pesan"),
        help_text=_("Isi lengkap pengumuman yang akan dibaca oleh pelamar."),
    )
    recipient_config = models.JSONField(
        _("konfigurasi penerima"),
        default=default_batch_announcement_recipient_config,
        help_text=_(
            'Siapa yang menerima notifikasi & melihat pengumuman, mis. '
            '{"selection_type": "all_active"} atau '
            '{"selection_type": "statuses", "statuses": ["PRA_SELEKSI"]}.'
        ),
    )
    created_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="batch_announcements_created",
        limit_choices_to={
            "role__in": [UserRole.MASTER_ADMIN, UserRole.ADMIN, UserRole.STAFF]
        },
        verbose_name=_("dibuat oleh"),
    )
    created_at = models.DateTimeField(_("dibuat pada"), auto_now_add=True, db_index=True)

    class Meta:
        verbose_name = _("pengumuman batch")
        verbose_name_plural = _("daftar pengumuman batch")
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["batch", "created_at"]),
        ]

    def __str__(self) -> str:
        return f"[{self.batch.name}] {self.title}"


# ---------------------------------------------------------------------------
# InterviewCohortAnnouncement — broadcast pesan admin ke seluruh cohort
# ---------------------------------------------------------------------------


def default_interview_cohort_announcement_recipient_config():
    """Default JSON for InterviewCohortAnnouncement.recipient_config."""
    return {"selection_type": "all_active"}


class InterviewCohortAnnouncement(models.Model):
    """
    Pengumuman/broadcast dari admin untuk semua pelamar di sebuah
    `InterviewCohort`. Pasangan dari `BatchAnnouncement` untuk tahap
    INTERVIEW ke atas.
    """

    cohort = models.ForeignKey(
        InterviewCohort,
        on_delete=models.CASCADE,
        related_name="announcements",
        verbose_name=_("sesi interview"),
        help_text=_("Cohort interview penerima pengumuman ini."),
    )
    title = models.CharField(
        _("judul"),
        max_length=200,
        help_text=_("Judul singkat pengumuman, misal: 'Jadwal Interview Diperbarui'."),
    )
    body = models.TextField(
        _("isi pesan"),
        help_text=_("Isi lengkap pengumuman yang akan dibaca oleh pelamar."),
    )
    recipient_config = models.JSONField(
        _("konfigurasi penerima"),
        default=default_interview_cohort_announcement_recipient_config,
        help_text=_(
            'Siapa yang menerima notifikasi & melihat pengumuman, mis. '
            '{"selection_type": "all_active"} atau '
            '{"selection_type": "statuses", "statuses": ["INTERVIEW","DITERIMA"]}.'
        ),
    )
    created_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="cohort_announcements_created",
        limit_choices_to={
            "role__in": [UserRole.MASTER_ADMIN, UserRole.ADMIN, UserRole.STAFF]
        },
        verbose_name=_("dibuat oleh"),
    )
    created_at = models.DateTimeField(_("dibuat pada"), auto_now_add=True, db_index=True)

    class Meta:
        verbose_name = _("pengumuman sesi interview")
        verbose_name_plural = _("daftar pengumuman sesi interview")
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["cohort", "created_at"]),
        ]

    def __str__(self) -> str:
        return f"[{self.cohort.name}] {self.title}"

