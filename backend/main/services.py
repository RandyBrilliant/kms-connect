"""
Service layer untuk LamaranBatch dan JobApplication.

Mengandung seluruh business logic lamaran kerja:
  - Eligibility checks: verification_status == ACCEPTED + no active lamaran.
  - Group assignment: admin menambah banyak pelamar ke satu batch sekaligus.
  - FSM transitions: siapa boleh pindah ke status apa.
  - Applicant confirmation: pelamar mengkonfirmasi kehadiran pra-seleksi/interview.
  - Batch scheduling: admin menetapkan tanggal/lokasi pra-seleksi atau interview.
  - 2-year re-assign cooldown enforcement.

Semua fungsi yang mengubah status harus melalui ApplicationService,
bukan langsung update model di views/serializers.
Setiap perubahan status ditulis atomically bersama baris ApplicationStatusHistory.
"""
from __future__ import annotations

from datetime import date
from typing import TYPE_CHECKING, NamedTuple

from dateutil.relativedelta import relativedelta
from django.db import transaction
from django.utils import timezone

from account.models import ApplicantVerificationStatus, UserRole

from .models import (
    ApplicationStatus,
    ApplicationStatusHistory,
    JobApplication,
    LamaranBatch,
    LowonganKerja,
)

if TYPE_CHECKING:
    from account.models import ApplicantProfile, CustomUser


# ---------------------------------------------------------------------------
# FSM Transition table
# Key: (current_status, actor_role) → list[allowed_next_status]
# ---------------------------------------------------------------------------

_ADMIN_ROLES = frozenset(
    {UserRole.MASTER_ADMIN, UserRole.ADMIN, UserRole.STAFF}
)

TRANSITIONS: dict[tuple[str, str], list[str]] = {
    ("PRA_SELEKSI", "admin"): ["INTERVIEW", "DITOLAK"],
    ("INTERVIEW",   "admin"): ["DITERIMA",  "DITOLAK"],
    ("DITERIMA",    "admin"): ["BERANGKAT", "DITOLAK"],
    ("BERANGKAT",   "admin"): ["SELESAI"],
    # DITOLAK and SELESAI are terminal — no transitions out
}

_ACTIVE_STATUSES = frozenset(JobApplication.ACTIVE_STATUSES)


# ---------------------------------------------------------------------------
# Result types
# ---------------------------------------------------------------------------


class EligibilityResult(NamedTuple):
    """Result of a single applicant eligibility check."""
    applicant_id: int
    eligible: bool
    reason: str | None  # None when eligible


class BatchAssignResult(NamedTuple):
    """Summary returned from group_assign."""
    assigned: list[JobApplication]
    skipped: list[EligibilityResult]  # ineligible applicants not assigned


# ---------------------------------------------------------------------------
# Custom exceptions
# ---------------------------------------------------------------------------


class CooldownError(Exception):
    """Raised when applicant is within the 2-year re-assign cooldown."""

    def __init__(self, eligible_date: date) -> None:
        self.eligible_date = eligible_date
        super().__init__(
            f"Pelamar dalam masa cooldown. Dapat diikutsertakan kembali mulai {eligible_date}."
        )


class TransitionError(Exception):
    """Raised when a status transition is not permitted for the actor's role."""
    pass


class EligibilityError(Exception):
    """Raised when an applicant is not eligible for assignment."""
    pass


# ---------------------------------------------------------------------------
# ApplicationService
# ---------------------------------------------------------------------------


class ApplicationService:
    """
    Central service for all LamaranBatch and JobApplication state changes.

    All mutating methods are @transaction.atomic to guarantee the main row
    update and the ApplicationStatusHistory entry are always written together.
    Never call JobApplication.save() for status changes outside this class.
    """

    REAPPLY_COOLDOWN_YEARS = JobApplication.REAPPLY_COOLDOWN_YEARS

    # ------------------------------------------------------------------
    # Eligibility helpers
    # ------------------------------------------------------------------

    @classmethod
    def can_reapply(
        cls,
        applicant_profile: "ApplicantProfile",
    ) -> tuple[bool, date | None]:
        """
        Check whether applicant is outside the 2-year re-assign cooldown.

        Returns (True, None)           — eligible.
        Returns (False, eligible_date) — still in cooldown.

        Cooldown is measured from the most recent placement_end_date across
        ALL SELESAI applications — one indexed query.
        """
        last_completed = (
            JobApplication.objects
            .filter(
                applicant=applicant_profile,
                status=ApplicationStatus.SELESAI,
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

    @classmethod
    def check_eligibility(
        cls,
        applicant_profile: "ApplicantProfile",
    ) -> EligibilityResult:
        """
        Single applicant full eligibility check for batch assignment.

        Three conditions must all pass:
          1. verification_status == ACCEPTED
          2. No active application in any job
          3. Not in 2-year cooldown
        """
        # 1. Verification status
        if applicant_profile.verification_status != ApplicantVerificationStatus.ACCEPTED:
            return EligibilityResult(
                applicant_id=applicant_profile.pk,
                eligible=False,
                reason=(
                    f"Status verifikasi pelamar adalah "
                    f"'{applicant_profile.get_verification_status_display()}', "
                    f"harus 'Diterima' untuk bisa diikutsertakan."
                ),
            )

        # 2. No active application in any job
        active = (
            JobApplication.objects
            .filter(applicant=applicant_profile, status__in=_ACTIVE_STATUSES)
            .select_related("job")
            .first()
        )
        if active:
            return EligibilityResult(
                applicant_id=applicant_profile.pk,
                eligible=False,
                reason=(
                    f"Pelamar sudah memiliki lamaran aktif di lowongan "
                    f"'{active.job.title}' (status: {active.get_status_display()})."
                ),
            )

        # 3. Cooldown
        can_apply, eligible_date = cls.can_reapply(applicant_profile)
        if not can_apply:
            return EligibilityResult(
                applicant_id=applicant_profile.pk,
                eligible=False,
                reason=(
                    f"Pelamar dalam masa cooldown. "
                    f"Dapat diikutsertakan kembali mulai {eligible_date}."
                ),
            )

        return EligibilityResult(applicant_id=applicant_profile.pk, eligible=True, reason=None)

    @classmethod
    def bulk_check_eligibility(
        cls,
        applicant_profiles: list["ApplicantProfile"],
    ) -> list[EligibilityResult]:
        """
        Efficient eligibility check for a list of applicants.
        Uses 2 queries total regardless of list size — safe at scale.

        Returns a list of EligibilityResult in the same order as input.
        """
        if not applicant_profiles:
            return []

        profile_ids = [p.pk for p in applicant_profiles]

        # Query 1: all who have active applications (any job)
        active_qs = (
            JobApplication.objects
            .filter(applicant_id__in=profile_ids, status__in=_ACTIVE_STATUSES)
            .select_related("job")
            .values("applicant_id", "job__title", "status")
        )
        active_map: dict[int, dict] = {}
        for row in active_qs:
            if row["applicant_id"] not in active_map:
                active_map[row["applicant_id"]] = row

        # Query 2: most recent SELESAI placement_end_date per applicant (for cooldown)
        cooldown_qs = (
            JobApplication.objects
            .filter(
                applicant_id__in=profile_ids,
                status=ApplicationStatus.SELESAI,
                placement_end_date__isnull=False,
            )
            .order_by("applicant_id", "-placement_end_date")
            .values("applicant_id", "placement_end_date")
        )
        cooldown_map: dict[int, date] = {}
        for row in cooldown_qs:
            if row["applicant_id"] not in cooldown_map:
                cooldown_map[row["applicant_id"]] = row["placement_end_date"]

        today = timezone.now().date()
        results: list[EligibilityResult] = []

        for profile in applicant_profiles:
            pid = profile.pk

            # 1. Verification
            if profile.verification_status != ApplicantVerificationStatus.ACCEPTED:
                results.append(EligibilityResult(
                    applicant_id=pid,
                    eligible=False,
                    reason=(
                        f"Status verifikasi '{profile.get_verification_status_display()}', "
                        f"harus 'Diterima'."
                    ),
                ))
                continue

            # 2. Active application
            if pid in active_map:
                row = active_map[pid]
                results.append(EligibilityResult(
                    applicant_id=pid,
                    eligible=False,
                    reason=(
                        f"Sudah memiliki lamaran aktif di '{row['job__title']}' "
                        f"(status: {row['status']})."
                    ),
                ))
                continue

            # 3. Cooldown
            if pid in cooldown_map:
                eligible_date = cooldown_map[pid] + relativedelta(
                    years=cls.REAPPLY_COOLDOWN_YEARS
                )
                if today < eligible_date:
                    results.append(EligibilityResult(
                        applicant_id=pid,
                        eligible=False,
                        reason=f"Dalam masa cooldown hingga {eligible_date}.",
                    ))
                    continue

            results.append(EligibilityResult(applicant_id=pid, eligible=True, reason=None))

        return results

    # ------------------------------------------------------------------
    # Batch operations
    # ------------------------------------------------------------------

    @classmethod
    @transaction.atomic
    def create_batch(
        cls,
        job: LowonganKerja,
        name: str,
        created_by: "CustomUser",
        notes: str = "",
    ) -> LamaranBatch:
        """
        Create a new LamaranBatch for a job.
        No applicants are added yet — call group_assign() next.
        """
        return LamaranBatch.objects.create(
            job=job,
            name=name,
            notes=notes,
            created_by=created_by,
        )

    @classmethod
    @transaction.atomic
    def group_assign(
        cls,
        batch: LamaranBatch,
        applicant_profiles: list["ApplicantProfile"],
        assigned_by: "CustomUser",
        note: str = "",
        skip_ineligible: bool = True,
    ) -> BatchAssignResult:
        """
        Assign a group of applicants to a batch at PRA_SELEKSI status.

        Uses bulk_create for performance — safe for thousands of applicants.
        Runs eligibility check first; ineligible applicants are either skipped
        (skip_ineligible=True) or raise EligibilityError (skip_ineligible=False).

        Returns BatchAssignResult with assigned applications and skipped list.
        """
        if not applicant_profiles:
            return BatchAssignResult(assigned=[], skipped=[])

        now = timezone.now()
        assign_note = note or f"Ditugaskan ke batch '{batch.name}' oleh admin."

        # Run bulk eligibility check (2 queries)
        results = cls.bulk_check_eligibility(applicant_profiles)
        eligible_profiles = []
        skipped: list[EligibilityResult] = []

        for result, profile in zip(results, applicant_profiles):
            if result.eligible:
                eligible_profiles.append(profile)
            else:
                if not skip_ineligible:
                    raise EligibilityError(
                        f"Pelamar ID {result.applicant_id} tidak memenuhi syarat: {result.reason}"
                    )
                skipped.append(result)

        if not eligible_profiles:
            return BatchAssignResult(assigned=[], skipped=skipped)

        # Bulk create applications (no N+1 insertions)
        applications_to_create = [
            JobApplication(
                applicant=profile,
                job=batch.job,
                batch=batch,
                status=ApplicationStatus.PRA_SELEKSI,
                assigned_by=assigned_by,
                reviewed_by=assigned_by,
                reviewed_at=now,
            )
            for profile in eligible_profiles
        ]
        created_applications = JobApplication.objects.bulk_create(
            applications_to_create,
            ignore_conflicts=False,
        )

        # Bulk create status history (no N+1 insertions)
        ApplicationStatusHistory.objects.bulk_create([
            ApplicationStatusHistory(
                application=app,
                from_status="",
                to_status=ApplicationStatus.PRA_SELEKSI,
                changed_by=assigned_by,
                note=assign_note,
            )
            for app in created_applications
        ])

        # bulk_create does NOT fire post_save signals, so we dispatch
        # APPLICATION_ASSIGNED notifications manually for each new applicant.
        # OPTIMIZED: Use dispatch_bulk() for better performance
        try:
            from account.services.notification_dispatcher import dispatch_bulk, build_application_context
            from account.services.notification_events import NotificationEvent

            # Reload with all related objects needed for context in one query
            loaded_apps = (
                JobApplication.objects
                .filter(pk__in=[app.pk for app in created_applications])
                .select_related("job__company", "batch", "applicant__user",
                                "applicant__user__notification_preference")
            )
            
            # Collect active users and build shared context
            users = []
            for app in loaded_apps:
                user = app.applicant.user
                if user and user.is_active:
                    users.append(user)
            
            if users:
                # Use first app for shared context (same batch/job for all)
                first_app = loaded_apps[0]
                ctx = build_application_context(first_app)
                
                # Dispatch to all users at once
                dispatch_bulk(
                    event=NotificationEvent.APPLICATION_ASSIGNED,
                    users=users,
                    context=ctx,
                    action_url=f"/batch/{batch.pk}",
                    action_label="Lihat Detail",
                    deduplicate=False,
                )
        except Exception:
            # Notification failure must never break the assignment transaction
            import logging
            logging.getLogger(__name__).exception(
                "Failed to send APPLICATION_ASSIGNED notifications for batch %s", batch.pk
            )

        return BatchAssignResult(assigned=list(created_applications), skipped=skipped)

    @classmethod
    @transaction.atomic
    def schedule_stage(
        cls,
        batch: LamaranBatch,
        stage: str,
        stage_date,
        location: str = "",
        notes: str = "",
    ) -> LamaranBatch:
        """
        Set or update the pra-seleksi or interview schedule on a batch.
        Stage must be 'pra_seleksi' or 'interview'.
        """
        if stage == "pra_seleksi":
            batch.pra_seleksi_date = stage_date
            batch.pra_seleksi_location = location
            batch.pra_seleksi_notes = notes
            update_fields = [
                "pra_seleksi_date", "pra_seleksi_location", "pra_seleksi_notes", "updated_at",
            ]
        elif stage == "interview":
            batch.interview_date = stage_date
            batch.interview_location = location
            batch.interview_notes = notes
            update_fields = [
                "interview_date", "interview_location", "interview_notes", "updated_at",
            ]
        else:
            raise ValueError(
                f"Stage tidak valid: '{stage}'. Harus 'pra_seleksi' atau 'interview'."
            )

        batch.save(update_fields=update_fields)
        return batch

    # ------------------------------------------------------------------
    # Individual application operations
    # ------------------------------------------------------------------

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
        Validate and apply a single status transition (admin only).

        Raises:
          TransitionError — if the move is not allowed.
        """
        actor_role = (
            "admin"
            if (actor.role in _ADMIN_ROLES or actor.is_superuser)
            else "applicant"
        )

        if actor_role != "admin":
            raise TransitionError("Hanya admin/staff yang dapat memindahkan status lamaran.")

        key = (application.status, actor_role)
        allowed = TRANSITIONS.get(key, [])

        if new_status not in allowed:
            raise TransitionError(
                f"Transisi dari '{application.get_status_display()}' ke "
                f"'{ApplicationStatus(new_status).label}' tidak diizinkan."
            )

        # ── Quota enforcement (only when moving to DITERIMA) ──────────────
        if new_status == ApplicationStatus.DITERIMA:
            job = application.job
            if job.quota is not None:
                accepted_count = JobApplication.objects.filter(
                    job=job,
                    status__in=[ApplicationStatus.DITERIMA, ApplicationStatus.BERANGKAT],
                ).exclude(pk=application.pk).count()
                if accepted_count >= job.quota:
                    raise TransitionError(
                        f"Kuota penerimaan lowongan '{job.title}' sudah penuh "
                        f"({job.quota} pelamar diterima)."
                    )
        # ─────────────────────────────────────────────────────────────────

        old_status = application.status
        update_fields = ["status", "reviewed_by", "reviewed_at", "updated_at"]

        application.status = new_status
        application.reviewed_by = actor
        application.reviewed_at = timezone.now()

        # SELESAI requires placement_end_date for cooldown calculation
        if new_status == ApplicationStatus.SELESAI:
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

    @classmethod
    @transaction.atomic
    def bulk_transition(
        cls,
        batch: LamaranBatch,
        new_status: str,
        actor: "CustomUser",
        note: str = "",
        placement_end_date: date | None = None,
    ) -> list[JobApplication]:
        """
        Transition ALL eligible applications in a batch to a new status.
        Uses bulk UPDATE + bulk INSERT for history — efficient at scale.

        Returns list of updated applications.
        """
        actor_role = "admin" if (actor.role in _ADMIN_ROLES or actor.is_superuser) else "applicant"
        if actor_role != "admin":
            raise TransitionError("Hanya admin/staff yang dapat memindahkan status batch.")

        # Find which current statuses are valid sources for this new_status
        valid_froms = [
            current for (current, role), targets in TRANSITIONS.items()
            if role == "admin" and new_status in targets
        ]
        if not valid_froms:
            raise TransitionError(f"Status '{new_status}' tidak valid sebagai tujuan transisi.")

        now = timezone.now()
        update_kwargs: dict = {
            "status": new_status,
            "reviewed_by": actor,
            "reviewed_at": now,
        }
        if new_status == ApplicationStatus.SELESAI:
            update_kwargs["placement_end_date"] = placement_end_date or now.date()

        # Fetch apps to build history rows
        apps = list(
            batch.applications.filter(status__in=valid_froms)
            .select_related("applicant__user")
        )

        # ── Quota enforcement for bulk DITERIMA ───────────────────────────
        if new_status == ApplicationStatus.DITERIMA:
            job = batch.job
            if job.quota is not None:
                already_accepted = JobApplication.objects.filter(
                    job=job,
                    status__in=[ApplicationStatus.DITERIMA, ApplicationStatus.BERANGKAT],
                ).exclude(pk__in=[a.pk for a in apps]).count()
                remaining_slots = job.quota - already_accepted
                if remaining_slots <= 0:
                    raise TransitionError(
                        f"Kuota penerimaan lowongan '{job.title}' sudah penuh "
                        f"({job.quota} pelamar diterima)."
                    )
                # Cap: only transition apps that fit within remaining quota
                apps = apps[:remaining_slots]
        # ─────────────────────────────────────────────────────────────────
        if not apps:
            return []

        old_statuses = {app.pk: app.status for app in apps}

        # Single bulk UPDATE
        batch.applications.filter(pk__in=[a.pk for a in apps]).update(**update_kwargs)

        # Single bulk INSERT for history
        ApplicationStatusHistory.objects.bulk_create([
            ApplicationStatusHistory(
                application=app,
                from_status=old_statuses[app.pk],
                to_status=new_status,
                changed_by=actor,
                note=note,
            )
            for app in apps
        ])

        for app in apps:
            app.status = new_status

        return apps

    @classmethod
    @transaction.atomic
    def confirm_attendance(
        cls,
        application: JobApplication,
        applicant_user: "CustomUser",
    ) -> JobApplication:
        """
        Applicant confirms they will attend the current stage.

        - At PRA_SELEKSI: sets pra_seleksi_confirmed_at
        - At INTERVIEW:   sets interview_confirmed_at

        Raises:
          TransitionError — if wrong stage or unauthorized user.
          ValueError      — if already confirmed.
        """
        try:
            profile = applicant_user.applicant_profile
        except Exception:
            raise TransitionError("Hanya pelamar yang dapat mengkonfirmasi kehadiran.")

        if application.applicant_id != profile.pk:
            raise TransitionError("Anda tidak berhak mengkonfirmasi lamaran ini.")

        now = timezone.now()

        if application.status == ApplicationStatus.PRA_SELEKSI:
            if application.pra_seleksi_confirmed_at:
                raise ValueError("Kehadiran pra-seleksi sudah dikonfirmasi sebelumnya.")
            application.pra_seleksi_confirmed_at = now
            application.save(update_fields=["pra_seleksi_confirmed_at", "updated_at"])

        elif application.status == ApplicationStatus.INTERVIEW:
            if application.interview_confirmed_at:
                raise ValueError("Kehadiran interview sudah dikonfirmasi sebelumnya.")
            application.interview_confirmed_at = now
            application.save(update_fields=["interview_confirmed_at", "updated_at"])

        else:
            raise TransitionError(
                f"Konfirmasi hanya dapat dilakukan pada tahap Pra-Seleksi atau Interview. "
                f"Status saat ini: {application.get_status_display()}."
            )

        return application


