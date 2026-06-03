"""
Document-type visibility for applicant self-service (upload checklist).

Bukti Penyerahan Dokumen is only available once the pelamar has at least one
lamaran in INTERVIEW or a later pipeline status — not during initial registration
or pra-seleksi alone.
"""
from __future__ import annotations

from django.db.models import Q, QuerySet

from account.models import ApplicantProfile, DocumentType

BUKTI_PENYERAHAN_CODE = "bukti-penyerahan-dokumen"


def applicant_has_interview_stage_lamaran(profile: ApplicantProfile) -> bool:
    from main.models import ApplicationStatus, JobApplication

    return JobApplication.objects.filter(
        applicant=profile,
        status__in=(
            ApplicationStatus.INTERVIEW,
            ApplicationStatus.DITERIMA,
            ApplicationStatus.BERANGKAT,
            ApplicationStatus.SELESAI,
        ),
    ).exists()


def applicant_has_confirmed_pra_seleksi(profile: ApplicantProfile) -> bool:
    from main.models import ApplicationStatus, JobApplication

    return JobApplication.objects.filter(
        applicant=profile,
        status=ApplicationStatus.PRA_SELEKSI,
        pra_seleksi_confirmed_at__isnull=False,
    ).exists()


def get_applicant_document_types_queryset(profile: ApplicantProfile) -> QuerySet:
    """
    Document types the pelamar may see/upload, based on lamaran progress.

    - Default: INITIAL phase only.
    - INTERVIEW+ (without pra shortcut alone): INITIAL + bukti penyerahan.
    - Pra-seleksi confirmed (still PRA_SELEKSI): all except bukti penyerahan.
    - INTERVIEW+ with pra confirmed, or INTERVIEW+ alone with full unlock path:
      all types when pra confirmed OR interview+ (interview+ adds bukti early).
    """
    has_interview = applicant_has_interview_stage_lamaran(profile)
    has_pra_confirmed = applicant_has_confirmed_pra_seleksi(profile)

    if has_interview:
        if has_pra_confirmed:
            return DocumentType.objects.all().order_by("sort_order", "code")
        return (
            DocumentType.objects.filter(
                Q(phase=DocumentType.PHASE_INITIAL)
                | Q(code=BUKTI_PENYERAHAN_CODE)
            )
            .order_by("sort_order", "code")
        )

    if has_pra_confirmed:
        return (
            DocumentType.objects.exclude(code=BUKTI_PENYERAHAN_CODE)
            .order_by("sort_order", "code")
        )

    return DocumentType.objects.filter(phase=DocumentType.PHASE_INITIAL).order_by(
        "sort_order", "code"
    )


def applicant_may_upload_document_type(
    profile: ApplicantProfile, document_type: DocumentType
) -> bool:
    return get_applicant_document_types_queryset(profile).filter(
        pk=document_type.pk
    ).exists()
