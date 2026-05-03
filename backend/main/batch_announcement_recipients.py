"""
Recipient selection for batch and cohort announcements
(admin → subset of applicants in a batch / interview cohort).

Filtering is centralized for preview, notifications (signals), and
applicant-visible announcement lists.
"""

from __future__ import annotations

from typing import Any

from django.db.models import QuerySet

from .models import (
    ApplicationStatus,
    BatchAnnouncement,
    InterviewCohort,
    InterviewCohortAnnouncement,
    JobApplication,
    LamaranBatch,
)

VALID_SELECTION_TYPES = frozenset({"all_active", "statuses"})


def default_recipient_config() -> dict[str, Any]:
    return {"selection_type": "all_active"}


def validate_recipient_config(config: dict[str, Any]) -> tuple[bool, str]:
    if not isinstance(config, dict):
        return False, "recipient_config harus berupa object."
    selection = config.get("selection_type")
    if not selection:
        return False, "selection_type wajib diisi."
    if selection not in VALID_SELECTION_TYPES:
        return False, (
            "selection_type harus salah satu dari: "
            + ", ".join(sorted(VALID_SELECTION_TYPES))
        )

    if selection == "statuses":
        statuses = config.get("statuses")
        if not isinstance(statuses, list) or len(statuses) == 0:
            return False, "statuses harus berupa array berisi minimal satu tahapan."
        valid = {c[0] for c in ApplicationStatus.choices}
        invalid = [s for s in statuses if s not in valid]
        if invalid:
            return False, f"Tahapan tidak valid: {', '.join(invalid)}"

    return True, ""


# ---------------------------------------------------------------------------
# LamaranBatch (pra-seleksi) announcements
# ---------------------------------------------------------------------------


def applications_for_recipient_config(
    batch: LamaranBatch, config: dict[str, Any]
) -> QuerySet[JobApplication]:
    """
    JobApplication rows in this batch that should receive the announcement
    (active users only).
    """
    qs = JobApplication.objects.filter(
        batch=batch,
        applicant__user__is_active=True,
    ).select_related("applicant__user")

    selection = (config or {}).get("selection_type", "all_active")
    if selection == "all_active":
        return qs.exclude(status__in=JobApplication.TERMINAL_STATUSES)
    if selection == "statuses":
        statuses = (config or {}).get("statuses") or []
        return qs.filter(status__in=statuses)
    return qs.none()


def recipient_user_count(batch: LamaranBatch, config: dict[str, Any]) -> int:
    """Distinct applicant users matching the config (batch announcement)."""
    return (
        applications_for_recipient_config(batch, config)
        .values("applicant__user_id")
        .distinct()
        .count()
    )


def announcement_visible_for_application(
    announcement: BatchAnnouncement, application: JobApplication
) -> bool:
    """Whether this applicant's application should see this batch announcement."""
    if application.batch_id != announcement.batch_id:
        return False
    config = announcement.recipient_config or default_recipient_config()
    return applications_for_recipient_config(announcement.batch, config).filter(
        pk=application.pk
    ).exists()


# ---------------------------------------------------------------------------
# InterviewCohort announcements (parallel API)
# ---------------------------------------------------------------------------


def applications_for_cohort_recipient_config(
    cohort: InterviewCohort, config: dict[str, Any]
) -> QuerySet[JobApplication]:
    """
    JobApplication rows in this cohort that should receive the announcement
    (active users only).
    """
    qs = JobApplication.objects.filter(
        interview_cohort=cohort,
        applicant__user__is_active=True,
    ).select_related("applicant__user")

    selection = (config or {}).get("selection_type", "all_active")
    if selection == "all_active":
        return qs.exclude(status__in=JobApplication.TERMINAL_STATUSES)
    if selection == "statuses":
        statuses = (config or {}).get("statuses") or []
        return qs.filter(status__in=statuses)
    return qs.none()


def cohort_recipient_user_count(
    cohort: InterviewCohort, config: dict[str, Any]
) -> int:
    """Distinct applicant users matching the config (cohort announcement)."""
    return (
        applications_for_cohort_recipient_config(cohort, config)
        .values("applicant__user_id")
        .distinct()
        .count()
    )


def cohort_announcement_visible_for_application(
    announcement: InterviewCohortAnnouncement, application: JobApplication
) -> bool:
    """Whether this applicant's application should see this cohort announcement."""
    if application.interview_cohort_id != announcement.cohort_id:
        return False
    config = announcement.recipient_config or default_recipient_config()
    return applications_for_cohort_recipient_config(
        announcement.cohort, config
    ).filter(pk=application.pk).exists()
