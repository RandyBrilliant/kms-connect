"""
Custom managers for email-based authentication, applicant profiles, and documents.
Uses role string literals to avoid circular import with models.
"""

from datetime import timedelta

from django.contrib.auth.models import BaseUserManager
from django.db import models
from django.db.models import Prefetch
from django.utils import timezone
from django.utils.translation import gettext_lazy as _


class CustomUserManager(BaseUserManager):
    """
    Manager where email is the unique identifier for authentication.
    Normalizes email (lowercase, strip) and enforces role for superuser.
    """

    def _normalize_email(self, email: str) -> str:
        return self.normalize_email(email).strip().lower() if email else ""

    def create_user(self, email: str, password: str | None = None, **extra_fields):
        """
        Create and save a user with the given email and password.
        Role should be provided; default to APPLICANT for registration flows.
        If password is None (e.g. OAuth), an unusable password is set.
        """
        if not email:
            raise ValueError(_("Alamat email wajib diisi."))
        email = self._normalize_email(email)
        extra_fields.setdefault("role", "APPLICANT")
        user = self.model(email=email, **extra_fields)
        if password is not None:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, email: str, password: str | None = None, **extra_fields):
        """
        Create and save a superuser with the given email and password.
        Forces role=ADMIN, is_staff=True, is_superuser=True.
        """
        extra_fields.setdefault("role", "ADMIN")
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)

        if extra_fields.get("is_staff") is not True:
            raise ValueError(_("Superuser harus is_staff=True."))
        if extra_fields.get("is_superuser") is not True:
            raise ValueError(_("Superuser harus is_superuser=True."))
        if extra_fields.get("role") != "ADMIN":
            raise ValueError(_("Superuser harus role=ADMIN."))
        return self.create_user(email, password, **extra_fields)


class ApplicantProfileQuerySet(models.QuerySet):
    """Optimized queryset for ApplicantProfile with common query patterns."""

    def with_user(self):
        """Select user to avoid N+1 queries."""
        return self.select_related("user")

    def with_related(self):
        """Optimize all common foreign key lookups."""
        return self.select_related(
            "user",
            "referrer",
            "verified_by",
            "province",
            "district",
            "district__province",
            "village",
            "village__district",
            "village__district__regency",
            "village__district__regency__province",
            "family_province",
            "family_district",
            "family_district__province",
            "family_village",
            "family_village__district",
            "family_village__district__regency",
            "family_village__district__regency__province",
        )

    def with_documents(self):
        """Prefetch all documents with their types."""
        from .models import ApplicantDocument

        return self.prefetch_related(
            Prefetch(
                "documents",
                queryset=ApplicantDocument.objects.select_related(
                    "document_type", "reviewed_by"
                ).order_by("document_type__sort_order"),
            )
        )

    def with_work_experiences(self):
        """Prefetch work experiences."""
        return self.prefetch_related("work_experiences")

    def with_full_details(self):
        """Load everything for detail views (use sparingly)."""
        return self.with_related().with_documents().with_work_experiences()

    # Status filters
    def draft(self):
        """Applicants in draft status."""
        from .models import ApplicantVerificationStatus

        return self.filter(verification_status=ApplicantVerificationStatus.DRAFT)

    def submitted(self):
        """Applicants submitted and waiting for review."""
        from .models import ApplicantVerificationStatus

        return self.filter(verification_status=ApplicantVerificationStatus.SUBMITTED)

    def accepted(self):
        """Accepted/verified applicants."""
        from .models import ApplicantVerificationStatus

        return self.filter(verification_status=ApplicantVerificationStatus.ACCEPTED)

    def rejected(self):
        """Rejected applicants."""
        from .models import ApplicantVerificationStatus

        return self.filter(verification_status=ApplicantVerificationStatus.REJECTED)

    def pending_review(self):
        """Alias for submitted() - clearer for admin dashboards."""
        return self.submitted()

    # Regional filters
    def by_province(self, province):
        """Filter by province."""
        return self.filter(province=province)

    def by_district(self, district):
        """Filter by district."""
        return self.filter(district=district)

    def by_region(self, province=None, district=None):
        """Filter by province and/or district."""
        qs = self
        if province:
            qs = qs.filter(province=province)
        if district:
            qs = qs.filter(district=district)
        return qs

    # Time-based filters
    def recent(self, days=30):
        """Applicants created in last N days."""
        cutoff = timezone.now() - timedelta(days=days)
        return self.filter(created_at__gte=cutoff)

    def submitted_recently(self, days=7):
        """Applicants submitted in last N days."""
        cutoff = timezone.now() - timedelta(days=days)
        return self.filter(submitted_at__gte=cutoff, submitted_at__isnull=False)

    # Referrer filters
    def by_referrer(self, referrer):
        """Filter by specific referrer (Staff/Admin)."""
        return self.filter(referrer=referrer)

    def referred_by_staff(self):
        """Applicants referred by staff (not admin)."""
        from .models import UserRole

        return self.filter(referrer__role=UserRole.STAFF)


class ApplicantProfileManager(models.Manager):
    """Custom manager for ApplicantProfile with optimized queries."""

    def get_queryset(self):
        return ApplicantProfileQuerySet(self.model, using=self._db)

    # Forward queryset methods
    def with_user(self):
        return self.get_queryset().with_user()

    def with_related(self):
        return self.get_queryset().with_related()

    def with_documents(self):
        return self.get_queryset().with_documents()

    def with_work_experiences(self):
        return self.get_queryset().with_work_experiences()

    def with_full_details(self):
        return self.get_queryset().with_full_details()

    def draft(self):
        return self.get_queryset().draft()

    def submitted(self):
        return self.get_queryset().submitted()

    def accepted(self):
        return self.get_queryset().accepted()

    def rejected(self):
        return self.get_queryset().rejected()

    def pending_review(self):
        return self.get_queryset().pending_review()

    def by_province(self, province):
        return self.get_queryset().by_province(province)

    def by_district(self, district):
        return self.get_queryset().by_district(district)

    def by_region(self, province=None, district=None):
        return self.get_queryset().by_region(province, district)

    def recent(self, days=30):
        return self.get_queryset().recent(days)

    def submitted_recently(self, days=7):
        return self.get_queryset().submitted_recently(days)

    def by_referrer(self, referrer):
        return self.get_queryset().by_referrer(referrer)

    def referred_by_staff(self):
        return self.get_queryset().referred_by_staff()

    # Bulk operations
    def bulk_update_status(self, profile_ids, status, verified_by, notes=""):
        """
        Bulk update verification status for multiple applicants.

        Args:
            profile_ids: List of ApplicantProfile IDs
            status: ApplicantVerificationStatus (ACCEPTED or REJECTED)
            verified_by: CustomUser who performed the action
            notes: Optional verification notes (applied to all updated profiles)

        Returns:
            Number of profiles updated
        """
        update_kwargs = {
            "verification_status": status,
            "verified_by": verified_by,
            "verified_at": timezone.now(),
        }
        if notes is not None:
            update_kwargs["verification_notes"] = notes or ""
        return self.filter(id__in=profile_ids).update(**update_kwargs)


class ApplicantDocumentQuerySet(models.QuerySet):
    """Optimized queryset for ApplicantDocument."""

    def with_related(self):
        """Select related document type and review info."""
        return self.select_related(
            "applicant_profile__user",
            "document_type",
            "reviewed_by",
        )

    def pending(self):
        """Documents pending review."""
        from .models import DocumentReviewStatus

        return self.filter(review_status=DocumentReviewStatus.PENDING)

    def approved(self):
        """Approved documents."""
        from .models import DocumentReviewStatus

        return self.filter(review_status=DocumentReviewStatus.APPROVED)

    def rejected(self):
        """Rejected documents."""
        from .models import DocumentReviewStatus

        return self.filter(review_status=DocumentReviewStatus.REJECTED)

    def by_type(self, document_type_code):
        """Filter by document type code."""
        return self.filter(document_type__code=document_type_code)

    def ktp_documents(self):
        """All KTP documents."""
        return self.by_type("ktp")

    def with_ocr_data(self):
        """Documents that have OCR data extracted."""
        return self.exclude(ocr_data={})


class ApplicantDocumentManager(models.Manager):
    """Custom manager for ApplicantDocument."""

    def get_queryset(self):
        return ApplicantDocumentQuerySet(self.model, using=self._db)

    def with_related(self):
        return self.get_queryset().with_related()

    def pending(self):
        return self.get_queryset().pending()

    def approved(self):
        return self.get_queryset().approved()

    def rejected(self):
        return self.get_queryset().rejected()

    def by_type(self, document_type_code):
        return self.get_queryset().by_type(document_type_code)

    def ktp_documents(self):
        return self.get_queryset().ktp_documents()

    def with_ocr_data(self):
        return self.get_queryset().with_ocr_data()
