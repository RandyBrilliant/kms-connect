"""
Service layer untuk LamaranBatch dan JobApplication.

Mengandung seluruh business logic lamaran kerja:
  - Eligibility checks: verification_status in (DRAFT/SUBMITTED/ACCEPTED) + no active lamaran.
  - Group assignment: admin menambah banyak pelamar ke satu batch sekaligus.
  - FSM transitions: siapa boleh pindah ke status apa.
  - Applicant confirmation: pelamar mengkonfirmasi kehadiran pra-seleksi/interview.
  - Batch scheduling: admin menetapkan tanggal/lokasi pra-seleksi atau interview.
  - Re-apply policy for terminal statuses.

Semua fungsi yang mengubah status harus melalui ApplicationService,
bukan langsung update model di views/serializers.
Setiap perubahan status ditulis atomically bersama baris ApplicationStatusHistory.
"""
from __future__ import annotations

from datetime import date
from functools import lru_cache
from typing import TYPE_CHECKING, NamedTuple

from django.db import transaction
from django.utils import timezone

from account.models import ApplicantVerificationStatus, UserRole

from .models import (
    ApplicationStatus,
    ApplicationStatusHistory,
    InterviewCohort,
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
_ELIGIBLE_VERIFICATION_STATUSES = frozenset({
    ApplicantVerificationStatus.DRAFT,
    ApplicantVerificationStatus.SUBMITTED,
    ApplicantVerificationStatus.ACCEPTED,
})


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
    DOCUMENT_COLLECTION_STEP_ORDER: tuple[tuple[str, str], ...] = (
        ("MASUK_BERKAS_ASLI", "Masuk Berkas Asli"),
        ("MEDICAL", "Medical"),
        ("BUAT_ID_PEKERJA", "Buat ID Pekerja"),
        ("BUAT_PASPOR", "Buat Paspor"),
        ("FWCMS", "FWCMS"),
        ("PSIKOLOGI_TEST", "Psikologi Test"),
        ("PAP_BP3MI", "PAP BP3MI"),
        ("PDO_KILANG", "PDO Kilang"),
        ("PERSIAPAN_KEBERANGKATAN", "Persiapan Keberangkatan"),
    )

    # ------------------------------------------------------------------
    # Eligibility helpers
    # ------------------------------------------------------------------

    @classmethod
    def can_reapply(
        cls,
        applicant_profile: "ApplicantProfile",
    ) -> tuple[bool, date | None]:
        """
        Re-apply policy:
        Applicants in terminal outcomes (including SELESAI / DITOLAK)
        can be re-assigned immediately.
        """
        _ = applicant_profile
        return True, None

    @classmethod
    def check_eligibility(
        cls,
        applicant_profile: "ApplicantProfile",
    ) -> EligibilityResult:
        """
        Single applicant full eligibility check for batch assignment.

        Three conditions must all pass:
          1. verification_status in (DRAFT, SUBMITTED, ACCEPTED)
          2. No active application in any job
          3. Re-apply is allowed for terminal statuses
        """
        # 1. Verification status
        if applicant_profile.verification_status not in _ELIGIBLE_VERIFICATION_STATUSES:
            return EligibilityResult(
                applicant_id=applicant_profile.pk,
                eligible=False,
                reason=(
                    f"Status verifikasi pelamar adalah "
                    f"'{applicant_profile.get_verification_status_display()}', "
                    f"harus Draf, Dikirim, atau Diterima untuk bisa diikutsertakan."
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

        # 3. Re-apply policy (terminal statuses are allowed)
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

        results: list[EligibilityResult] = []

        for profile in applicant_profiles:
            pid = profile.pk

            # 1. Verification
            if profile.verification_status not in _ELIGIBLE_VERIFICATION_STATUSES:
                results.append(EligibilityResult(
                    applicant_id=pid,
                    eligible=False,
                    reason=(
                        f"Status verifikasi '{profile.get_verification_status_display()}', "
                        f"harus Draf, Dikirim, atau Diterima."
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
            loaded_apps = list(
                JobApplication.objects
                .filter(pk__in=[app.pk for app in created_applications])
                .select_related(
                    "job__company",
                    "batch",
                    "applicant__user",
                    "applicant__user__notification_preference",
                )
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

    @staticmethod
    @lru_cache(maxsize=1)
    def _required_post_interview_document_type_ids() -> tuple[int, ...]:
        from account.models import DocumentType

        return tuple(
            DocumentType.objects.filter(
                phase=DocumentType.PHASE_POST_INTERVIEW,
                is_required=True,
            ).values_list("id", flat=True)
        )

    @classmethod
    def get_document_collection_progress(cls, application: JobApplication) -> dict:
        """
        Build checklist progress for the DITERIMA-stage document collection flow.
        """
        from account.models import ApplicantDocument

        profile = getattr(application, "applicant", None)
        if not profile:
            items = [
                {"code": code, "label": label, "done": False}
                for code, label in cls.DOCUMENT_COLLECTION_STEP_ORDER
            ]
            return {"items": items, "done_count": 0, "total_count": len(items), "is_complete": False}

        required_post_doc_ids = cls._required_post_interview_document_type_ids()
        uploaded_required_ids = set(
            ApplicantDocument.objects.filter(
                applicant_profile=profile,
                document_type_id__in=required_post_doc_ids,
            ).values_list("document_type_id", flat=True)
        )
        post_docs_complete = all(doc_id in uploaded_required_ids for doc_id in required_post_doc_ids)
        medical_result = (getattr(profile, "hasil_medical", "") or "").strip().upper()

        checks = {
            "MASUK_BERKAS_ASLI": post_docs_complete,
            "MEDICAL": medical_result == "FIT",
            "BUAT_ID_PEKERJA": bool((getattr(profile, "no_id_sisko", "") or "").strip()),
            "BUAT_PASPOR": bool((getattr(profile, "passport_number", "") or "").strip()),
            "FWCMS": bool(getattr(profile, "tgl_fwcm_psikotes", None)),
            "PSIKOLOGI_TEST": bool(getattr(profile, "tgl_fwcm_psikotes", None)),
            "PAP_BP3MI": bool((getattr(profile, "no_sip", "") or "").strip()),
            "PDO_KILANG": bool(getattr(profile, "tgl_kirim_bio_ke_mly", None)),
            "PERSIAPAN_KEBERANGKATAN": bool(getattr(profile, "tgl_calling_visa", None))
            and bool((getattr(profile, "no_calling_visa", "") or "").strip()),
        }
        items = [
            {"code": code, "label": label, "done": bool(checks.get(code))}
            for code, label in cls.DOCUMENT_COLLECTION_STEP_ORDER
        ]
        done_count = sum(1 for item in items if item["done"])
        total_count = len(items)
        return {
            "items": items,
            "done_count": done_count,
            "total_count": total_count,
            "is_complete": done_count == total_count,
        }

    @classmethod
    def _ensure_document_collection_complete(cls, application: JobApplication) -> None:
        progress = cls.get_document_collection_progress(application)
        if progress["is_complete"]:
            return
        pending = [item["label"] for item in progress["items"] if not item["done"]]
        raise TransitionError(
            "Tahap Pengumpulan Dokumen belum lengkap. "
            f"Selesaikan terlebih dahulu: {', '.join(pending)}."
        )

    @classmethod
    def _ensure_document_collection_confirmed(cls, application: JobApplication) -> None:
        attendance_map = (
            dict(application.attendance_by_stage)
            if isinstance(application.attendance_by_stage, dict)
            else {}
        )
        if attendance_map.get(ApplicationStatus.DITERIMA):
            return
        raise TransitionError(
            "Pelamar belum mengkonfirmasi pengumpulan dokumen pada tahap Diterima. "
            "Minta pelamar klik 'Dokumen Selesai' terlebih dahulu."
        )

    @classmethod
    @transaction.atomic
    def transition(
        cls,
        application: JobApplication,
        new_status: str,
        actor: "CustomUser",
        note: str = "",
        placement_end_date: date | None = None,
        interview_cohort: "InterviewCohort | None" = None,
    ) -> JobApplication:
        """
        Validate and apply a single status transition (admin only).

        When transitioning **PRA_SELEKSI → INTERVIEW**, `interview_cohort`
        is required: it routes the applicant into the cohort that owns the
        rest of the lifecycle. The cohort must belong to the same job.

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

        # ── Cohort routing rules (PRA_SELEKSI → INTERVIEW) ───────────────
        # When moving to INTERVIEW we must know which cohort owns the
        # applicant from this point on. Same job constraint is enforced.
        if new_status == ApplicationStatus.INTERVIEW:
            if interview_cohort is None:
                raise TransitionError(
                    "Pilih sesi interview (cohort) sebelum memindahkan pelamar "
                    "ke tahap INTERVIEW."
                )
            if interview_cohort.job_id != application.job_id:
                raise TransitionError(
                    "Sesi interview yang dipilih bukan untuk lowongan yang sama."
                )
            if not interview_cohort.is_active:
                raise TransitionError(
                    "Sesi interview yang dipilih sudah ditandai non-aktif."
                )
        # ─────────────────────────────────────────────────────────────────

        if application.status == ApplicationStatus.DITERIMA and new_status == ApplicationStatus.BERANGKAT:
            cls._ensure_document_collection_complete(application)
            cls._ensure_document_collection_confirmed(application)

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

        if new_status == ApplicationStatus.INTERVIEW and interview_cohort is not None:
            application.interview_cohort = interview_cohort
            update_fields.append("interview_cohort")

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
        interview_cohort: "InterviewCohort | None" = None,
    ) -> list[JobApplication]:
        """
        Bulk transition for the **PRA_SELEKSI** scope of a batch.

        Allowed `new_status` values from a pra-seleksi batch:
          - INTERVIEW (requires `interview_cohort` of the same job)
          - DITOLAK
          - PRA_SELEKSI (no-op via this method — re-batching is done by
            `move_applications_to_batch`)

        Other downstream transitions (DITERIMA / BERANGKAT / SELESAI) are
        scoped to a cohort, see `cohort_bulk_transition`.

        Uses bulk UPDATE + bulk INSERT for history.
        """
        actor_role = "admin" if (actor.role in _ADMIN_ROLES or actor.is_superuser) else "applicant"
        if actor_role != "admin":
            raise TransitionError("Hanya admin/staff yang dapat memindahkan status batch.")

        if new_status not in (ApplicationStatus.INTERVIEW, ApplicationStatus.DITOLAK):
            raise TransitionError(
                "Aksi batch hanya mendukung transisi ke INTERVIEW atau DITOLAK. "
                "Untuk DITERIMA/BERANGKAT/SELESAI, gunakan aksi pada sesi interview (cohort)."
            )

        if new_status == ApplicationStatus.INTERVIEW:
            if interview_cohort is None:
                raise TransitionError(
                    "Pilih sesi interview (cohort) sebelum memindahkan batch "
                    "ke tahap INTERVIEW."
                )
            if interview_cohort.job_id != batch.job_id:
                raise TransitionError(
                    "Sesi interview yang dipilih bukan untuk lowongan yang sama "
                    "dengan batch ini."
                )
            if not interview_cohort.is_active:
                raise TransitionError(
                    "Sesi interview yang dipilih sudah ditandai non-aktif."
                )

        # Apps still in PRA_SELEKSI are the only valid source from a batch.
        apps = list(
            batch.applications.filter(status=ApplicationStatus.PRA_SELEKSI)
            .select_related("applicant__user")
        )

        if not apps:
            return []

        now = timezone.now()
        update_kwargs: dict = {
            "status": new_status,
            "reviewed_by": actor,
            "reviewed_at": now,
        }
        if new_status == ApplicationStatus.INTERVIEW and interview_cohort is not None:
            update_kwargs["interview_cohort"] = interview_cohort

        old_statuses = {app.pk: app.status for app in apps}

        batch.applications.filter(pk__in=[a.pk for a in apps]).update(**update_kwargs)

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

        # Reflect new state on in-memory objects so callers see updated rows.
        for app in apps:
            app.status = new_status
            if new_status == ApplicationStatus.INTERVIEW:
                app.interview_cohort = interview_cohort

        return apps

    # ------------------------------------------------------------------
    # Interview Cohort operations
    # ------------------------------------------------------------------

    @classmethod
    @transaction.atomic
    def create_cohort(
        cls,
        job: LowonganKerja,
        name: str,
        created_by: "CustomUser",
        notes: str = "",
        interview_date=None,
        interview_location: str = "",
        interview_notes: str = "",
    ) -> InterviewCohort:
        """Create an interview cohort for a job. No applicants yet."""
        return InterviewCohort.objects.create(
            job=job,
            name=name,
            notes=notes,
            interview_date=interview_date,
            interview_location=interview_location,
            interview_notes=interview_notes,
            created_by=created_by,
            is_active=True,
        )

    @classmethod
    @transaction.atomic
    def schedule_cohort(
        cls,
        cohort: InterviewCohort,
        interview_date=None,
        interview_location: str = "",
        interview_notes: str = "",
    ) -> InterviewCohort:
        """Set or update the interview schedule on a cohort."""
        cohort.interview_date = interview_date
        cohort.interview_location = interview_location
        cohort.interview_notes = interview_notes
        cohort.save(update_fields=[
            "interview_date",
            "interview_location",
            "interview_notes",
            "updated_at",
        ])
        return cohort

    @classmethod
    @transaction.atomic
    def cohort_bulk_transition(
        cls,
        cohort: InterviewCohort,
        new_status: str,
        actor: "CustomUser",
        note: str = "",
        placement_end_date: date | None = None,
    ) -> list[JobApplication]:
        """
        Bulk transition all eligible applications **in a cohort** at once.

        Valid targets from cohort scope:
          - DITERIMA  (from INTERVIEW; quota-checked at job level)
          - BERANGKAT (from DITERIMA; doc-collection checks)
          - SELESAI   (from BERANGKAT)
          - DITOLAK   (from INTERVIEW or DITERIMA)

        Used by the new admin UX: from interview onwards, every status
        change is scoped to the cohort (the operational unit), not to the
        original pra-seleksi batch.
        """
        actor_role = "admin" if (actor.role in _ADMIN_ROLES or actor.is_superuser) else "applicant"
        if actor_role != "admin":
            raise TransitionError("Hanya admin/staff yang dapat memindahkan status sesi interview.")

        # Valid source statuses for this target, restricted to non-PRA_SELEKSI
        # because cohorts only own INTERVIEW+ lifecycle.
        valid_froms = [
            current for (current, role), targets in TRANSITIONS.items()
            if role == "admin"
            and current != ApplicationStatus.PRA_SELEKSI
            and new_status in targets
        ]
        if not valid_froms:
            raise TransitionError(
                f"Status '{new_status}' tidak valid sebagai tujuan transisi dari sesi interview."
            )

        now = timezone.now()
        update_kwargs: dict = {
            "status": new_status,
            "reviewed_by": actor,
            "reviewed_at": now,
        }
        if new_status == ApplicationStatus.SELESAI:
            update_kwargs["placement_end_date"] = placement_end_date or now.date()

        apps = list(
            cohort.applications.filter(status__in=valid_froms)
            .select_related("applicant__user")
        )

        if new_status == ApplicationStatus.DITERIMA:
            job = cohort.job
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
                apps = apps[:remaining_slots]

        if new_status == ApplicationStatus.BERANGKAT:
            blocked_labels: set[str] = set()
            missing_confirmation = False
            for app in apps:
                progress = cls.get_document_collection_progress(app)
                if progress["is_complete"]:
                    attendance_map = (
                        dict(app.attendance_by_stage)
                        if isinstance(app.attendance_by_stage, dict)
                        else {}
                    )
                    if not attendance_map.get(ApplicationStatus.DITERIMA):
                        missing_confirmation = True
                else:
                    for item in progress["items"]:
                        if not item["done"]:
                            blocked_labels.add(item["label"])
            if blocked_labels:
                raise TransitionError(
                    "Sebagian pelamar belum menyelesaikan tahap Pengumpulan Dokumen. "
                    f"Kekurangan: {', '.join(sorted(blocked_labels))}."
                )
            if missing_confirmation:
                raise TransitionError(
                    "Sebagian pelamar belum mengkonfirmasi 'Dokumen Selesai' "
                    "pada tahap Diterima."
                )

        if not apps:
            return []

        old_statuses = {app.pk: app.status for app in apps}

        cohort.applications.filter(pk__in=[a.pk for a in apps]).update(**update_kwargs)

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
            if new_status == ApplicationStatus.SELESAI:
                app.placement_end_date = update_kwargs["placement_end_date"]

        return apps

    @classmethod
    @transaction.atomic
    def move_applications_to_batch(
        cls,
        applications: list[JobApplication],
        target_batch: LamaranBatch,
        actor: "CustomUser",
    ) -> list[JobApplication]:
        """
        Re-batch applications within the **PRA_SELEKSI** stage of a job.
        Used to advance survivors from one tahapan to the next.

        Status is NOT changed — this is a container move only.
        Source and target batches must belong to the same job.
        """
        if not applications:
            return []

        actor_role = "admin" if (actor.role in _ADMIN_ROLES or actor.is_superuser) else "applicant"
        if actor_role != "admin":
            raise TransitionError("Hanya admin/staff yang dapat memindahkan batch pelamar.")

        ids: list[int] = []
        for app in applications:
            if app.status != ApplicationStatus.PRA_SELEKSI:
                raise TransitionError(
                    f"Pelamar '{app.applicant_id}' tidak lagi di tahap pra-seleksi."
                )
            if app.job_id != target_batch.job_id:
                raise TransitionError(
                    "Batch tujuan bukan milik lowongan yang sama."
                )
            ids.append(app.pk)

        JobApplication.objects.filter(pk__in=ids).update(
            batch=target_batch,
            updated_at=timezone.now(),
        )
        for app in applications:
            app.batch = target_batch

        return applications

    @classmethod
    @transaction.atomic
    def move_applications_to_cohort(
        cls,
        applications: list[JobApplication],
        target_cohort: InterviewCohort,
        actor: "CustomUser",
    ) -> list[JobApplication]:
        """
        Re-cohort applications within the **INTERVIEW+** stages of a job.
        Status is NOT changed — only the cohort assignment.
        Used when the admin reschedules an applicant to another interview
        session, or moves them between cohorts before/after interview.
        """
        if not applications:
            return []

        actor_role = "admin" if (actor.role in _ADMIN_ROLES or actor.is_superuser) else "applicant"
        if actor_role != "admin":
            raise TransitionError("Hanya admin/staff yang dapat memindahkan cohort pelamar.")

        if not target_cohort.is_active:
            raise TransitionError("Sesi interview tujuan sudah ditandai non-aktif.")

        eligible_statuses = {
            ApplicationStatus.INTERVIEW,
            ApplicationStatus.DITERIMA,
            ApplicationStatus.BERANGKAT,
            ApplicationStatus.SELESAI,
            ApplicationStatus.DITOLAK,
        }

        ids: list[int] = []
        for app in applications:
            if app.status not in eligible_statuses:
                raise TransitionError(
                    "Pelamar belum mencapai tahap interview, tidak bisa dipindah ke cohort."
                )
            if app.job_id != target_cohort.job_id:
                raise TransitionError(
                    "Cohort tujuan bukan milik lowongan yang sama."
                )
            ids.append(app.pk)

        JobApplication.objects.filter(pk__in=ids).update(
            interview_cohort=target_cohort,
            updated_at=timezone.now(),
        )
        for app in applications:
            app.interview_cohort = target_cohort

        return applications

    @classmethod
    @transaction.atomic
    def confirm_attendance(
        cls,
        application: JobApplication,
        applicant_user: "CustomUser",
        stage: str | None = None,
    ) -> JobApplication:
        """
        Applicant confirms attendance for a stage.
        If stage is omitted, current status is used.

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
        target_stage = stage or application.status
        if target_stage not in JobApplication.ATTENDANCE_TRACKED_STATUSES:
            raise ValueError("Tahap konfirmasi hadir tidak valid.")

        reached = set(
            application.status_history.values_list("to_status", flat=True)
        )
        reached.add(application.status)
        if target_stage not in reached:
            raise TransitionError(
                "Konfirmasi hadir hanya dapat dilakukan untuk tahapan yang sudah dicapai."
            )

        if target_stage == ApplicationStatus.DITERIMA:
            cls._ensure_document_collection_complete(application)

        attendance_map = (
            dict(application.attendance_by_stage)
            if isinstance(application.attendance_by_stage, dict)
            else {}
        )
        if attendance_map.get(target_stage):
            raise ValueError("Kehadiran untuk tahapan ini sudah dikonfirmasi sebelumnya.")
        attendance_map[target_stage] = now.isoformat()
        application.attendance_by_stage = attendance_map

        update_fields = ["attendance_by_stage", "updated_at"]

        # Keep legacy fields in sync for existing UI/queries.
        if target_stage == ApplicationStatus.PRA_SELEKSI and not application.pra_seleksi_confirmed_at:
            application.pra_seleksi_confirmed_at = now
            update_fields.append("pra_seleksi_confirmed_at")
        elif target_stage == ApplicationStatus.INTERVIEW and not application.interview_confirmed_at:
            application.interview_confirmed_at = now
            update_fields.append("interview_confirmed_at")

        application.save(update_fields=update_fields)

        return application

    @classmethod
    @transaction.atomic
    def mark_placement_completed(
        cls,
        application: JobApplication,
        applicant_user: "CustomUser",
        note: str = "Pelamar mengkonfirmasi telah selesai bekerja dan kembali ke Indonesia.",
    ) -> JobApplication:
        """
        Applicant self-service completion:
        BERANGKAT -> SELESAI.
        """
        try:
            profile = applicant_user.applicant_profile
        except Exception:
            raise TransitionError("Hanya pelamar yang dapat mengkonfirmasi status selesai.")

        if application.applicant_id != profile.pk:
            raise TransitionError("Anda tidak berhak mengubah lamaran ini.")

        if application.status != ApplicationStatus.BERANGKAT:
            raise TransitionError(
                "Konfirmasi selesai hanya tersedia saat status lamaran masih Berangkat."
            )

        old_status = application.status
        now = timezone.now()
        application.status = ApplicationStatus.SELESAI
        application.reviewed_at = now
        application.placement_end_date = now.date()
        application.save(update_fields=[
            "status",
            "reviewed_at",
            "placement_end_date",
            "updated_at",
        ])

        ApplicationStatusHistory.objects.create(
            application=application,
            from_status=old_status,
            to_status=ApplicationStatus.SELESAI,
            changed_by=applicant_user,
            note=note,
        )
        return application


