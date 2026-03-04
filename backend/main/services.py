"""
Service layer untuk JobApplication.

Mengandung seluruh business logic lamaran kerja:
  - FSM transitions: siapa boleh pindah ke status apa.
  - Admin-initiated assignment (ADMIN_ASSIGN).
  - 2-year re-apply cooldown enforcement.

Semua fungsi yang mengubah status harus melalui ApplicationService,
bukan langsung update model di views/serializers.
Setiap perubahan status ditulis atomically bersama baris ApplicationStatusHistory.
"""
from __future__ import annotations

from datetime import date
from typing import TYPE_CHECKING

from dateutil.relativedelta import relativedelta
from django.db import transaction
from django.utils import timezone

from account.models import UserRole

from .models import (
    ApplicationSource,
    ApplicationStatus,
    ApplicationStatusHistory,
    JobApplication,
    LowonganKerja,
)

if TYPE_CHECKING:
    from account.models import ApplicantProfile, CustomUser


# ---------------------------------------------------------------------------
# FSM Transition table
# Key: (current_status, actor_role) → list[allowed_next_status]
# Any pair not present here is a forbidden transition.
# ---------------------------------------------------------------------------

_ADMIN_ROLES = frozenset({UserRole.ADMIN, UserRole.STAFF})

TRANSITIONS: dict[tuple[str, str], list[str]] = {
    # Admin / staff transitions
    ("APPLIED",        "admin"): ["UNDER_REVIEW", "SHORTLISTED", "OFFERED", "REJECTED"],
    ("UNDER_REVIEW",   "admin"): ["SHORTLISTED", "OFFERED", "REJECTED"],
    ("SHORTLISTED",    "admin"): ["OFFERED", "REJECTED"],
    ("OFFERED",        "admin"): ["OFFER_ACCEPTED", "OFFER_DECLINED", "REJECTED"],  # admin can accept/decline on behalf or rescind
    ("OFFER_ACCEPTED", "admin"): ["PLACED", "REJECTED"],
    ("OFFER_DECLINED", "admin"): ["SHORTLISTED", "REJECTED"],  # admin gives another chance
    ("PLACED",         "admin"): ["COMPLETED", "REJECTED"],    # contract ended or terminated

    # Applicant transitions
    ("APPLIED",        "applicant"): ["WITHDRAWN"],
    ("OFFERED",        "applicant"): ["OFFER_ACCEPTED", "OFFER_DECLINED"],
    ("OFFER_ACCEPTED", "applicant"): ["OFFER_DECLINED"],    # change of mind before placed
}

# Active statuses — used to detect duplicate active applications per (applicant, job)
_ACTIVE_STATUSES = frozenset(JobApplication.ACTIVE_STATUSES)


# ---------------------------------------------------------------------------
# Custom exceptions
# ---------------------------------------------------------------------------


class CooldownError(Exception):
    """Raised when applicant is within the 2-year re-apply cooldown."""

    def __init__(self, eligible_date: date) -> None:
        self.eligible_date = eligible_date
        super().__init__(
            f"Pelamar dalam masa cooldown. Dapat melamar kembali mulai {eligible_date}."
        )


class TransitionError(Exception):
    """Raised when a status transition is not permitted for the actor's role."""
    pass


# ---------------------------------------------------------------------------
# ApplicationService
# ---------------------------------------------------------------------------


class ApplicationService:
    """
    Central service for all JobApplication state changes.

    All mutating methods are @transaction.atomic to guarantee the main row
    update and the ApplicationStatusHistory entry are always written together.
    Never call JobApplication.save() directly for status changes outside this class.
    """

    REAPPLY_COOLDOWN_YEARS = JobApplication.REAPPLY_COOLDOWN_YEARS

    # ------------------------------------------------------------------
    # Query helpers
    # ------------------------------------------------------------------

    @classmethod
    def can_reapply(
        cls,
        applicant_profile: "ApplicantProfile",
    ) -> tuple[bool, date | None]:
        """
        Check whether the applicant is outside the 2-year re-apply cooldown.

        Returns (True, None)          — eligible to apply now.
        Returns (False, eligible_date) — still in cooldown; include eligible_date in error.

        Rule: cooldown starts from the most recent placement_end_date across ALL
        completed applications (not per-job), because a placed worker cannot
        hold two concurrent placements anyway.

        Executes a single indexed DB query.
        """
        last_completed = (
            JobApplication.objects
            .filter(
                applicant=applicant_profile,
                status=ApplicationStatus.COMPLETED,
                placement_end_date__isnull=False,
            )
            .order_by("-placement_end_date")
            .values("placement_end_date")
            .first()
        )
        if not last_completed:
            return True, None

        eligible: date = last_completed["placement_end_date"] + relativedelta(
            years=cls.REAPPLY_COOLDOWN_YEARS
        )
        if timezone.now().date() >= eligible:
            return True, None
        return False, eligible

    # ------------------------------------------------------------------
    # Mutating operations
    # ------------------------------------------------------------------

    @classmethod
    @transaction.atomic
    def apply(
        cls,
        job: LowonganKerja,
        applicant_profile: "ApplicantProfile",
    ) -> JobApplication:
        """
        Applicant self-applies to a job.

        Enforces:
          1. Cooldown check (2 years since last COMPLETED placement).
          2. No existing active application for (applicant, job).

        Raises:
          CooldownError  — if applicant is in cooldown period.
          ValueError     — if an active application already exists.
        """
        # 1. Cooldown
        eligible, eligible_date = cls.can_reapply(applicant_profile)
        if not eligible:
            raise CooldownError(eligible_date)

        # 2. No active application for this specific job
        if JobApplication.objects.filter(
            applicant=applicant_profile,
            job=job,
            status__in=_ACTIVE_STATUSES,
        ).exists():
            raise ValueError("Anda sudah memiliki lamaran aktif untuk lowongan ini.")

        application = JobApplication.objects.create(
            applicant=applicant_profile,
            job=job,
            status=ApplicationStatus.APPLIED,
            source=ApplicationSource.SELF_APPLIED,
        )
        ApplicationStatusHistory.objects.create(
            application=application,
            from_status="",
            to_status=ApplicationStatus.APPLIED,
            changed_by=applicant_profile.user,
            note="Lamaran dikirim oleh pelamar.",
        )
        return application

    @classmethod
    @transaction.atomic
    def admin_assign(
        cls,
        job: LowonganKerja,
        applicant_profile: "ApplicantProfile",
        assigned_by: "CustomUser",
        note: str = "",
    ) -> JobApplication:
        """
        Admin directly assigns an applicant to a job at OFFERED status.

        Cases:
          - Active application already exists → transition it to OFFERED.
          - No active application → create a fresh ADMIN_ASSIGN row at OFFERED.

        Cooldown applies to admin-assign too; admin cannot bypass the 2-year rule.

        Raises:
          CooldownError — if applicant is in cooldown period.
        """
        eligible, eligible_date = cls.can_reapply(applicant_profile)
        if not eligible:
            raise CooldownError(eligible_date)

        assign_note = note or "Ditugaskan langsung oleh admin."

        # Check for an existing active application on this job
        existing = (
            JobApplication.objects
            .filter(applicant=applicant_profile, job=job, status__in=_ACTIVE_STATUSES)
            .first()
        )
        if existing:
            # Elevate the existing application directly to OFFERED
            return cls.transition(
                application=existing,
                new_status=ApplicationStatus.OFFERED,
                actor=assigned_by,
                note=assign_note,
            )

        # No active application — create a fresh ADMIN_ASSIGN row
        application = JobApplication.objects.create(
            applicant=applicant_profile,
            job=job,
            status=ApplicationStatus.OFFERED,
            source=ApplicationSource.ADMIN_ASSIGN,
            assigned_by=assigned_by,
            reviewed_by=assigned_by,
            reviewed_at=timezone.now(),
        )
        ApplicationStatusHistory.objects.create(
            application=application,
            from_status="",
            to_status=ApplicationStatus.OFFERED,
            changed_by=assigned_by,
            note=assign_note,
        )
        return application

    @classmethod
    @transaction.atomic
    def transition(
        cls,
        application: JobApplication,
        new_status: str,
        actor: "CustomUser",
        note: str = "",
        placement_end_date: date | None = None,
    ) -> JobApplication:
        """
        Validate and apply a single status transition.

        Validates that (current_status, actor_role) → new_status is in TRANSITIONS.
        When moving to COMPLETED, placement_end_date defaults to today if not provided.

        Raises:
          TransitionError — if the move is not allowed for the actor's role.
        """
        actor_role = (
            "admin"
            if (actor.role in _ADMIN_ROLES or actor.is_superuser)
            else "applicant"
        )
        key = (application.status, actor_role)
        allowed = TRANSITIONS.get(key, [])

        if new_status not in allowed:
            raise TransitionError(
                f"Transisi dari '{application.status}' ke '{new_status}' "
                f"tidak diizinkan untuk role '{actor_role}'."
            )

        old_status = application.status
        update_fields = ["status", "reviewed_by", "reviewed_at", "updated_at"]

        application.status = new_status
        application.reviewed_by = actor
        application.reviewed_at = timezone.now()

        # COMPLETED requires a placement_end_date
        if new_status == ApplicationStatus.COMPLETED:
            application.placement_end_date = placement_end_date or timezone.now().date()
            update_fields.append("placement_end_date")

        application.save(update_fields=update_fields)

        ApplicationStatusHistory.objects.create(
            application=application,
            from_status=old_status,
            to_status=new_status,
            changed_by=actor,
            note=note,
        )
        return application
