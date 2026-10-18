"""
Document-type visibility for applicant self-service (upload checklist).

Bukti Penyerahan Dokumen is only available once the pelamar has at least one
lamaran in INTERVIEW or a later pipeline status. The other POST_INTERVIEW
documents ("Setelah wawancara") unlock only at DITERIMA or later.
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


def applicant_has_diterima_or_later(profile: ApplicantProfile) -> bool:
    from main.models import ApplicationStatus, JobApplication

    return JobApplication.objects.filter(
        applicant=profile,
        status__in=(
            ApplicationStatus.DITERIMA,
            ApplicationStatus.BERANGKAT,
            ApplicationStatus.SELESAI,
        ),
    ).exists()


def get_applicant_document_types_queryset(profile: ApplicantProfile) -> QuerySet:
    """
    Document types the pelamar may see/upload, based on lamaran progress.

    - Default (incl. pra-seleksi, confirmed or not): INITIAL phase only.
    - INTERVIEW: INITIAL + bukti penyerahan.
    - DITERIMA+ (lulus interview / diterima): all types.
    """
    if applicant_has_diterima_or_later(profile):
        return DocumentType.objects.all().order_by("sort_order", "code")

    if applicant_has_interview_stage_lamaran(profile):
        return (
            DocumentType.objects.filter(
                Q(phase=DocumentType.PHASE_INITIAL)
                | Q(code=BUKTI_PENYERAHAN_CODE)
            )
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
