"""
Serializers untuk konten main app:
- News: berita / pengumuman di halaman utama.
- LowonganKerja: lowongan kerja yang dikelola dari backoffice.
- LamaranBatch: grup penugasan pelamar oleh admin.
- JobApplication: lamaran individual dalam sebuah batch.
"""

from rest_framework import serializers
from django.utils import timezone

from account.serializers import _staff_rujukan_display_name

from .models import (
    ApplicationStatus,
    ApplicationStatusHistory,
    BatchAnnouncement,
    JobApplication,
    JobStatus,
    LamaranBatch,
    LowonganKerja,
    News,
    NewsStatus,
)


# ---------------------------------------------------------------------------
# News
# ---------------------------------------------------------------------------


class NewsSerializer(serializers.ModelSerializer):
    """CRUD berita untuk admin/backoffice."""

    created_by_name = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = News
        fields = [
            "id",
            "title",
            "slug",
            "summary",
            "content",
            "hero_image",
            "status",
            "is_pinned",
            "published_at",
            "created_by",
            "created_by_name",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_by", "created_by_name", "created_at", "updated_at"]

    def get_created_by_name(self, obj) -> str | None:
        """
        Nama pembuat berita (Admin/Staff). Menggunakan full_name bila ada,
        jika tidak fallback ke email. Digunakan untuk tampilan metadata di frontend.
        """
        user = getattr(obj, "created_by", None)
        if not user:
            return None
        return user.full_name or user.email

    def create(self, validated_data):
        request = self.context.get("request")
        user = getattr(request, "user", None)

        # Auto-set created_by from request user when available
        if user and getattr(user, "is_authenticated", False):
            validated_data.setdefault("created_by", user)

        # Auto-set published_at when status is PUBLISHED and not provided
        status_value = validated_data.get("status")
        if status_value == NewsStatus.PUBLISHED and not validated_data.get("published_at"):
            validated_data["published_at"] = timezone.now()

        return super().create(validated_data)

    def update(self, instance, validated_data):
        old_status = instance.status
        new_status = validated_data.get("status", old_status)

        # When moving from non-published to PUBLISHED and published_at is empty, auto-fill timestamp
        if (
            old_status != NewsStatus.PUBLISHED
            and new_status == NewsStatus.PUBLISHED
            and not instance.published_at
            and not validated_data.get("published_at")
        ):
            validated_data["published_at"] = timezone.now()

        return super().update(instance, validated_data)


# ---------------------------------------------------------------------------
# LowonganKerja
# ---------------------------------------------------------------------------


class LowonganKerjaSerializer(serializers.ModelSerializer):
    """CRUD lowongan kerja untuk admin/backoffice."""

    company_name = serializers.SerializerMethodField(read_only=True)
    created_by_name = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = LowonganKerja
        fields = [
            "id",
            "title",
            "slug",
            "company",
            "company_name",
            "location_country",
            "location_city",
            "description",
            "requirements",
            "employment_type",
            "salary_min",
            "salary_max",
            "currency",
            "status",
            "posted_at",
            "deadline",
            "start_date",
            "quota",
            "created_by",
            "created_by_name",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "company_name", "created_by", "created_by_name", "created_at", "updated_at"]

    def get_company_name(self, obj) -> str | None:
        company = getattr(obj, "company", None)
        if not company:
            return None
        return company.company_name

    def get_created_by_name(self, obj) -> str | None:
        user = getattr(obj, "created_by", None)
        if not user:
            return None
        return user.full_name or user.email

    def create(self, validated_data):
        request = self.context.get("request")
        user = getattr(request, "user", None)

        # Auto-set created_by from request user when available
        if user and getattr(user, "is_authenticated", False):
            validated_data.setdefault("created_by", user)

        # Auto-set posted_at when status is OPEN and not provided
        status_value = validated_data.get("status")
        if status_value == JobStatus.OPEN and not validated_data.get("posted_at"):
            validated_data["posted_at"] = timezone.now()

        instance = LowonganKerja(**validated_data)
        self._validate_dates(instance)
        instance.save()
        return instance

    def update(self, instance, validated_data):
        old_status = instance.status
        new_status = validated_data.get("status", old_status)

        # When moving from DRAFT to OPEN and posted_at is empty, auto-fill timestamp
        if (
            old_status != JobStatus.OPEN
            and new_status == JobStatus.OPEN
            and not instance.posted_at
            and not validated_data.get("posted_at")
        ):
            validated_data["posted_at"] = timezone.now()

        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        self._validate_dates(instance)
        instance.save()
        return instance

    def _validate_dates(self, instance: LowonganKerja) -> None:
        """
        Ensure deadline is not before posted_at when both are provided.
        """
        posted_at = instance.posted_at
        deadline = instance.deadline
        if posted_at and deadline and deadline < posted_at:
            raise serializers.ValidationError(
                {
                    "deadline": [
                        "Batas akhir lamaran tidak boleh lebih awal dari tanggal mulai diposting."
                    ]
                }
            )


# ---------------------------------------------------------------------------
# JobApplication
# ---------------------------------------------------------------------------


class ApplicationStatusHistorySerializer(serializers.ModelSerializer):
    """Read-only audit trail entry for a single status change."""

    changed_by_name = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = ApplicationStatusHistory
        fields = [
            "id",
            "from_status",
            "to_status",
            "changed_by",
            "changed_by_name",
            "changed_at",
            "note",
        ]
        read_only_fields = fields

    def get_changed_by_name(self, obj) -> str | None:
        if not obj.changed_by:
            return None
        return obj.changed_by.full_name or obj.changed_by.email


class JobApplicationSerializer(serializers.ModelSerializer):
    """
    Full read serializer for JobApplication.
    Used for all GET responses — includes status_history inline so the
    frontend gets the complete audit trail in a single call.
    """

    applicant_name = serializers.SerializerMethodField(read_only=True)
    applicant_email = serializers.SerializerMethodField(read_only=True)
    job_title = serializers.SerializerMethodField(read_only=True)
    company_name = serializers.SerializerMethodField(read_only=True)
    assigned_by_name = serializers.SerializerMethodField(read_only=True)
    batch_name = serializers.SerializerMethodField(read_only=True)
    pra_seleksi_date = serializers.DateTimeField(
        source="batch.pra_seleksi_date", read_only=True
    )
    pra_seleksi_location = serializers.CharField(
        source="batch.pra_seleksi_location", read_only=True
    )
    interview_date = serializers.DateTimeField(
        source="batch.interview_date", read_only=True
    )
    interview_location = serializers.CharField(
        source="batch.interview_location", read_only=True
    )
    cooldown_eligible_date = serializers.SerializerMethodField(read_only=True)
    status_history = ApplicationStatusHistorySerializer(many=True, read_only=True)
    applicant_nik = serializers.SerializerMethodField(read_only=True)
    referrer_display_name = serializers.SerializerMethodField(read_only=True)
    referrer_code = serializers.SerializerMethodField(read_only=True)
    applicant_user = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = JobApplication
        fields = [
            "id",
            "applicant",
            "applicant_user",
            "applicant_name",
            "applicant_email",
            "applicant_nik",
            "referrer_display_name",
            "referrer_code",
            "job",
            "job_title",
            "company_name",
            "batch",
            "batch_name",
            "status",
            "pra_seleksi_date",
            "pra_seleksi_location",
            "interview_date",
            "interview_location",
            "pra_seleksi_confirmed_at",
            "interview_confirmed_at",
            "applied_at",
            "placement_end_date",
            "cooldown_eligible_date",
            "assigned_by",
            "assigned_by_name",
            "notes",
            "status_history",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "applicant_user",
            "applicant_name",
            "applicant_email",
            "applicant_nik",
            "referrer_display_name",
            "referrer_code",
            "job_title",
            "company_name",
            "batch_name",
            "cooldown_eligible_date",
            "pra_seleksi_confirmed_at",
            "interview_confirmed_at",
            "status_history",
            "applied_at",
            "created_at",
            "updated_at",
        ]

    def get_applicant_user(self, obj) -> int | None:
        applicant = getattr(obj, "applicant", None)
        if not applicant:
            return None
        uid = getattr(applicant, "user_id", None)
        return int(uid) if uid is not None else None

    def get_applicant_name(self, obj) -> str:
        applicant = getattr(obj, "applicant", None)
        if not applicant:
            return ""
        try:
            user = applicant.user
        except Exception:
            return ""
        if not user:
            return ""
        return user.full_name or ""

    def get_applicant_email(self, obj) -> str:
        applicant = getattr(obj, "applicant", None)
        if not applicant:
            return ""
        try:
            user = applicant.user
        except Exception:
            return ""
        if not user:
            return ""
        return user.email or ""

    def get_applicant_nik(self, obj) -> str:
        applicant = getattr(obj, "applicant", None)
        if not applicant:
            return ""
        return (getattr(applicant, "nik", None) or "").strip()

    def get_referrer_display_name(self, obj) -> str:
        applicant = getattr(obj, "applicant", None)
        if not applicant or not getattr(applicant, "referrer_id", None):
            return ""
        ref = applicant.referrer
        if not ref:
            return ""
        raw_name = (getattr(ref, "full_name", None) or "").strip()
        email = getattr(ref, "email", None) or ""
        return _staff_rujukan_display_name(full_name=raw_name, email=email)

    def get_referrer_code(self, obj) -> str:
        applicant = getattr(obj, "applicant", None)
        if not applicant or not getattr(applicant, "referrer_id", None):
            return ""
        ref = applicant.referrer
        if not ref:
            return ""
        return (getattr(ref, "referral_code", None) or "").strip()

    def get_job_title(self, obj) -> str:
        job = getattr(obj, "job", None)
        if not job:
            return ""
        return getattr(job, "title", "") or ""

    def get_company_name(self, obj) -> str:
        job = getattr(obj, "job", None)
        if not job:
            return ""
        company = getattr(job, "company", None)
        if not company:
            return ""
        return getattr(company, "company_name", "") or ""

    def get_assigned_by_name(self, obj) -> str | None:
        if not obj.assigned_by:
            return None
        return obj.assigned_by.full_name or obj.assigned_by.email

    def get_batch_name(self, obj) -> str | None:
        batch = getattr(obj, "batch", None)
        if not batch:
            return None
        return getattr(batch, "name", None)

    def get_cooldown_eligible_date(self, obj):
        """Serializable version of the model property."""
        return obj.cooldown_eligible_date


class ApplicationTransitionSerializer(serializers.Serializer):
    """
    Input serializer for PATCH /api/applications/{id}/transition/.
    Admin provides the desired next status and an optional note.
    Valid transitions (admin only):
      PRA_SELEKSI → INTERVIEW | DITOLAK
      INTERVIEW   → DITERIMA  | DITOLAK
      DITERIMA    → BERANGKAT | DITOLAK
      BERANGKAT   → SELESAI
    """

    status = serializers.ChoiceField(
        choices=ApplicationStatus.choices,
        help_text="Status tujuan transisi.",
    )
    note = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=500,
        help_text="Catatan opsional untuk perubahan status ini.",
    )
    placement_end_date = serializers.DateField(
        required=False,
        allow_null=True,
        help_text="Wajib diisi saat transisi ke SELESAI. Default: hari ini.",
    )


# ---------------------------------------------------------------------------
# LamaranBatch
# ---------------------------------------------------------------------------


class LamaranBatchSerializer(serializers.ModelSerializer):
    """
    Full read serializer for LamaranBatch.
    Returned by GET /api/batches/ and GET /api/batches/{id}/.
    """

    job_title = serializers.SerializerMethodField(read_only=True)
    created_by_name = serializers.SerializerMethodField(read_only=True)
    applicant_count = serializers.IntegerField(read_only=True)
    confirmed_pra_seleksi_count = serializers.IntegerField(read_only=True)
    confirmed_interview_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = LamaranBatch
        fields = [
            "id",
            "job",
            "job_title",
            "name",
            "notes",
            # Pra-seleksi schedule
            "pra_seleksi_date",
            "pra_seleksi_location",
            "pra_seleksi_notes",
            # Interview schedule
            "interview_date",
            "interview_location",
            "interview_notes",
            # Stats
            "applicant_count",
            "confirmed_pra_seleksi_count",
            "confirmed_interview_count",
            # Meta
            "created_by",
            "created_by_name",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "job_title",
            "created_by",
            "created_by_name",
            "applicant_count",
            "confirmed_pra_seleksi_count",
            "confirmed_interview_count",
            "created_at",
            "updated_at",
        ]

    def get_job_title(self, obj) -> str:
        return obj.job.title if obj.job else ""

    def get_created_by_name(self, obj) -> str | None:
        if not obj.created_by:
            return None
        return obj.created_by.full_name or obj.created_by.email


class LamaranBatchCreateSerializer(serializers.Serializer):
    """
    Input serializer for POST /api/batches/.
    Admin creates a new batch for a specific job opening.
    """

    job = serializers.PrimaryKeyRelatedField(
        queryset=LowonganKerja.objects.all(),
        help_text="ID lowongan kerja (semua status kecuali draf dapat dipakai operasional).",
    )
    name = serializers.CharField(
        max_length=100,
        help_text="Nama batch, misalnya 'Batch Maret 2026' (maks. 100 karakter).",
    )
    notes = serializers.CharField(
        required=False,
        allow_blank=True,
        help_text="Catatan umum untuk batch ini.",
    )


class GroupAssignSerializer(serializers.Serializer):
    """
    Input serializer for POST /api/batches/{id}/assign/.
    Admin picks applicants from the search/table result and submits their IDs in bulk.

    Workflow:
    1. Admin opens a batch detail page.
    2. Admin searches the applicant table by name or NIK/ID.
    3. Admin selects one or more rows (checkboxes).
    4. Admin clicks "Tambah ke Batch" → this serializer is submitted.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        from account.models import ApplicantProfile
        self.fields["applicant_ids"] = serializers.PrimaryKeyRelatedField(
            queryset=ApplicantProfile.objects.select_related("user").filter(
                user__is_active=True
            ),
            many=True,
            help_text=(
                "Daftar ID ApplicantProfile yang akan ditambahkan ke batch ini. "
                "Maksimal 200 pelamar per permintaan."
            ),
        )

    note = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=500,
        help_text="Catatan penugasan yang akan disimpan di riwayat status semua pelamar.",
    )

    def validate_applicant_ids(self, value):
        if len(value) == 0:
            raise serializers.ValidationError("Pilih minimal 1 pelamar.")
        if len(value) > 200:
            raise serializers.ValidationError("Maksimal 200 pelamar per permintaan.")
        return value


class BatchCheckEligibilitySerializer(serializers.Serializer):
    """
    Input serializer for POST /api/batches/{id}/check-eligibility/.
    Dry-run: returns eligibility status for each applicant without persisting anything.
    Used so the admin can see which selected applicants are eligible BEFORE assigning.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        from account.models import ApplicantProfile
        self.fields["applicant_ids"] = serializers.PrimaryKeyRelatedField(
            queryset=ApplicantProfile.objects.select_related("user").filter(
                user__is_active=True
            ),
            many=True,
            help_text="Daftar ID ApplicantProfile untuk dicek kelayakannya.",
        )

    def validate_applicant_ids(self, value):
        if len(value) == 0:
            raise serializers.ValidationError("Pilih minimal 1 pelamar.")
        if len(value) > 200:
            raise serializers.ValidationError("Maksimal 200 pelamar per permintaan.")
        return value


class BatchScheduleSerializer(serializers.Serializer):
    """
    Input serializer for PATCH /api/batches/{id}/schedule/.
    Admin sets the date, location, and notes for pra_seleksi or interview stage.
    Both stages share this serializer; the 'stage' field determines which fields are written.
    """

    STAGE_CHOICES = [
        ("pra_seleksi", "Pra-Seleksi"),
        ("interview", "Interview"),
    ]

    stage = serializers.ChoiceField(
        choices=STAGE_CHOICES,
        help_text="Tahap yang dijadwalkan: 'pra_seleksi' atau 'interview'.",
    )
    date = serializers.DateTimeField(
        help_text="Tanggal dan waktu pelaksanaan tahap.",
    )
    location = serializers.CharField(
        max_length=255,
        help_text="Lokasi pelaksanaan (alamat lengkap atau nama gedung).",
    )
    notes = serializers.CharField(
        required=False,
        allow_blank=True,
        help_text="Informasi tambahan untuk peserta (dress code, dokumen yang dibawa, dll.).",
    )


# ---------------------------------------------------------------------------
# Applicant search (used by admin batch assignment table)
# ---------------------------------------------------------------------------


class ApplicantSearchSerializer(serializers.Serializer):
    """
    Read serializer for a single applicant row in the batch-assignment search table.
    Returned by GET /api/batches/{id}/eligible-applicants/?q=...

    Each row shows enough info for the admin to identify the applicant and
    decide whether to include them in the batch.
    """

    id = serializers.IntegerField(source="pk")
    nik = serializers.SerializerMethodField()
    full_name = serializers.SerializerMethodField()
    email = serializers.SerializerMethodField()
    phone = serializers.SerializerMethodField()
    domicile = serializers.SerializerMethodField()
    # Whether this applicant passes all eligibility rules for the target batch/job.
    is_eligible = serializers.BooleanField(default=True)
    # Human-readable reason when is_eligible=False.
    ineligible_reason = serializers.CharField(allow_null=True, default=None)

    def get_nik(self, obj) -> str:
        return getattr(obj, "nik", "") or ""

    def get_full_name(self, obj) -> str:
        return obj.user.full_name if obj.user else ""

    def get_email(self, obj) -> str:
        return obj.user.email if obj.user else ""

    def get_phone(self, obj) -> str:
        return obj.user.phone_number if obj.user else ""

    def get_domicile(self, obj) -> str:
        """Kelurahan / Kecamatan / city concatenated for display."""
        parts = [
            getattr(obj, "domicile_kelurahan", None),
            getattr(obj, "domicile_kecamatan", None),
            getattr(obj, "domicile_city", None),
        ]
        return ", ".join(p for p in parts if p)


# ---------------------------------------------------------------------------
# BatchAnnouncement — broadcast pengumuman admin ke seluruh batch
# ---------------------------------------------------------------------------


class BatchAnnouncementSerializer(serializers.ModelSerializer):
    """
    Serializer baca untuk pengumuman batch.
    Digunakan oleh admin (list dan detail) dan pelamar (hanya baca).
    """

    created_by_name = serializers.SerializerMethodField()

    class Meta:
        model = BatchAnnouncement
        fields = [
            "id",
            "batch",
            "title",
            "body",
            "recipient_config",
            "created_by",
            "created_by_name",
            "created_at",
        ]
        read_only_fields = fields

    def get_created_by_name(self, obj) -> str | None:
        if obj.created_by:
            return obj.created_by.full_name or obj.created_by.email
        return None


class BatchAnnouncementCreateSerializer(serializers.Serializer):
    """
    Input serializer untuk admin membuat pengumuman batch baru.
    POST /api/batches/{id}/announcements/
    """

    title = serializers.CharField(
        max_length=200,
        help_text="Judul singkat pengumuman.",
    )
    body = serializers.CharField(
        help_text="Isi lengkap pengumuman yang akan dibaca pelamar.",
    )
    recipient_config = serializers.JSONField(
        required=False,
        help_text=(
            'Penerima: {"selection_type":"all_active"} atau '
            '{"selection_type":"statuses","statuses":["PRA_SELEKSI","INTERVIEW"]}.'
        ),
    )

    def validate(self, attrs):
        from .batch_announcement_recipients import (
            default_recipient_config,
            validate_recipient_config,
        )

        config = attrs.get("recipient_config")
        if config is None:
            attrs["recipient_config"] = default_recipient_config()
        else:
            ok, err = validate_recipient_config(config)
            if not ok:
                raise serializers.ValidationError({"recipient_config": err})
        return attrs
