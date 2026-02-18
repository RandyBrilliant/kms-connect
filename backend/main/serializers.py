"""
Serializers untuk konten main app:
- News: berita / pengumuman di halaman utama.
- LowonganKerja: lowongan kerja yang dikelola dari backoffice.
"""

from rest_framework import serializers
from django.utils import timezone

from .models import News, LowonganKerja, NewsStatus, JobStatus, JobApplication, ApplicationStatus


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


class JobApplicationSerializer(serializers.ModelSerializer):
    """Serializer untuk lamaran kerja."""

    applicant_name = serializers.SerializerMethodField(read_only=True)
    applicant_email = serializers.SerializerMethodField(read_only=True)
    job_title = serializers.SerializerMethodField(read_only=True)
    company_name = serializers.SerializerMethodField(read_only=True)
    reviewed_by_name = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = JobApplication
        fields = [
            "id",
            "applicant",
            "applicant_name",
            "applicant_email",
            "job",
            "job_title",
            "company_name",
            "status",
            "applied_at",
            "reviewed_at",
            "reviewed_by",
            "reviewed_by_name",
            "notes",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "applicant_name",
            "applicant_email",
            "job_title",
            "company_name",
            "reviewed_by_name",
            "applied_at",
            "reviewed_at",
            "created_at",
            "updated_at",
        ]

    def get_applicant_name(self, obj) -> str:
        return obj.applicant.user.full_name if obj.applicant and obj.applicant.user else ""

    def get_applicant_email(self, obj) -> str:
        return obj.applicant.user.email if obj.applicant and obj.applicant.user else ""

    def get_job_title(self, obj) -> str:
        return obj.job.title if obj.job else ""

    def get_company_name(self, obj) -> str:
        return obj.job.company.company_name if obj.job and obj.job.company else ""

    def get_reviewed_by_name(self, obj) -> str | None:
        if not obj.reviewed_by:
            return None
        return obj.reviewed_by.full_name or obj.reviewed_by.email

