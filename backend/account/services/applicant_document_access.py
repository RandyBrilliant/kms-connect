"""
Document-type visibility for applicant self-service (upload checklist).

All POST_INTERVIEW documents ("Setelah wawancara"), including Bukti Penyerahan
Dokumen, unlock only once the pelamar has passed the interview (DITERIMA or later).
"""
from __future__ import annotations

from django.db.models import QuerySet

from account.models import ApplicantProfile, DocumentType

BUKTI_PENYERAHAN_CODE = "bukti-penyerahan-dokumen"

# Data Rekening PMI — pelamar may fill these once lulus interview (DITERIMA+),
# even when the rest of the profile is locked (ACCEPTED).
BANK_ACCOUNT_FIELDS = frozenset({"bank", "bank_account_holder", "no_rek"})


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

    - Default (incl. pra-seleksi and interview): INITIAL phase only.
    - DITERIMA+ (lulus interview / diterima): all types, incl. bukti penyerahan.
    """
    if applicant_has_diterima_or_later(profile):
        return DocumentType.objects.all().order_by("sort_order", "code")

    return DocumentType.objects.filter(phase=DocumentType.PHASE_INITIAL).order_by(
        "sort_order", "code"
    )


def applicant_may_upload_document_type(
    profile: ApplicantProfile, document_type: DocumentType
) -> bool:
    return get_applicant_document_types_queryset(profile).filter(
        pk=document_type.pk
    ).exists()
