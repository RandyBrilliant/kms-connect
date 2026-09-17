"""
Merge leftover DocumentType `pas-photo` into canonical `pas-foto`.

Production grew two types after the code renamed Pas Photo → Pas Foto. This
merge keeps the `pas-foto` row (the code CV, biodata, and scoring already use),
retargets `pas-photo` uploads onto it, then deletes the empty `pas-photo` type.

Storage files are never deleted: rows are retargeted with QuerySet.update, and
duplicate rows have their FileField cleared in SQL before the DB row is removed
so Django's FileField post_delete does not unlink the object in Spaces.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from django.core.cache import cache
from django.db import transaction

from account.models import ApplicantDocument, DocumentReviewStatus, DocumentType

CANONICAL_CODE = "pas-foto"
LEGACY_CODE = "pas-photo"

_STATUS_RANK = {
    DocumentReviewStatus.APPROVED: 2,
    DocumentReviewStatus.PENDING: 1,
    DocumentReviewStatus.REJECTED: 0,
}


@dataclass
class MergePasPhotoResult:
    dry_run: bool
    retargeted: int = 0
    duplicates_resolved: int = 0
    canonical_kept_on_duplicate: int = 0
    legacy_kept_on_duplicate: int = 0
    type_deleted: bool = False
    description_copied: bool = False
    notes: list[str] = field(default_factory=list)

    def summary_lines(self) -> list[str]:
        prefix = "[dry-run] " if self.dry_run else ""
        lines = [
            f"{prefix}retargeted pas-photo → pas-foto: {self.retargeted}",
            f"{prefix}duplicate profiles resolved: {self.duplicates_resolved} "
            f"(kept pas-foto={self.canonical_kept_on_duplicate}, "
            f"kept pas-photo file={self.legacy_kept_on_duplicate})",
            f"{prefix}copied description onto pas-foto: {self.description_copied}",
            f"{prefix}deleted pas-photo type: {self.type_deleted}",
        ]
        lines.extend(f"{prefix}{note}" for note in self.notes)
        return lines


def _has_file(doc: ApplicantDocument) -> bool:
    name = getattr(doc.file, "name", None) or ""
    return bool(str(name).strip())


def _winner(canonical: ApplicantDocument, legacy: ApplicantDocument) -> ApplicantDocument:
    """Prefer a real file, then approved review, then the newer upload."""
    c_file = _has_file(canonical)
    l_file = _has_file(legacy)
    if c_file != l_file:
        return canonical if c_file else legacy
    c_rank = _STATUS_RANK.get(canonical.review_status, 0)
    l_rank = _STATUS_RANK.get(legacy.review_status, 0)
    if c_rank != l_rank:
        return canonical if c_rank > l_rank else legacy
    c_time = canonical.uploaded_at or 0
    l_time = legacy.uploaded_at or 0
    if c_time != l_time:
        return canonical if c_time >= l_time else legacy
    return canonical


def _copy_legacy_onto_canonical(canonical: ApplicantDocument, legacy: ApplicantDocument) -> None:
    """Point the pas-foto row at the pas-photo file/metadata without touching storage."""
    ApplicantDocument.objects.filter(pk=canonical.pk).update(
        file=legacy.file.name if _has_file(legacy) else "",
        review_status=legacy.review_status,
        reviewed_by_id=legacy.reviewed_by_id,
        reviewed_at=legacy.reviewed_at,
        review_notes=legacy.review_notes,
        ocr_text=legacy.ocr_text,
        ocr_data=legacy.ocr_data or {},
        ocr_processed_at=legacy.ocr_processed_at,
        uploaded_at=legacy.uploaded_at,
    )


def _delete_row_keeping_storage(doc_id: int) -> None:
    ApplicantDocument.objects.filter(pk=doc_id).update(file="")
    ApplicantDocument.objects.filter(pk=doc_id).delete()


def merge_pas_photo_into_pas_foto(*, dry_run: bool = True) -> MergePasPhotoResult:
    result = MergePasPhotoResult(dry_run=dry_run)

    canonical = DocumentType.objects.filter(code=CANONICAL_CODE).first()
    legacy = DocumentType.objects.filter(code=LEGACY_CODE).first()

    if legacy is None:
        result.notes.append("No pas-photo type found; nothing to merge.")
        return result
    if canonical is None:
        result.notes.append(
            "pas-foto type is missing. Create it before merging; refusing to rename "
            "pas-photo in place so CV/biodata keep using code pas-foto."
        )
        return result

    if not (canonical.description or "").strip() and (legacy.description or "").strip():
        result.description_copied = True
        if not dry_run:
            DocumentType.objects.filter(pk=canonical.pk).update(
                description=legacy.description
            )

    canonical_profile_ids = ApplicantDocument.objects.filter(
        document_type=canonical
    ).values("applicant_profile_id")
    retarget_qs = ApplicantDocument.objects.filter(document_type=legacy).exclude(
        applicant_profile_id__in=canonical_profile_ids
    )
    result.retargeted = retarget_qs.count()

    duplicate_legacy = list(
        ApplicantDocument.objects.filter(document_type=legacy)
        .filter(applicant_profile_id__in=canonical_profile_ids)
        .select_related("document_type")
    )
    result.duplicates_resolved = len(duplicate_legacy)

    duplicate_pairs: list[tuple[ApplicantDocument, ApplicantDocument]] = []
    for legacy_doc in duplicate_legacy:
        canonical_doc = ApplicantDocument.objects.get(
            applicant_profile_id=legacy_doc.applicant_profile_id,
            document_type=canonical,
        )
        duplicate_pairs.append((canonical_doc, legacy_doc))
        if _winner(canonical_doc, legacy_doc).pk == legacy_doc.pk:
            result.legacy_kept_on_duplicate += 1
        else:
            result.canonical_kept_on_duplicate += 1

    if dry_run:
        result.type_deleted = True
        result.notes.append(
            "Dry-run only. Re-run with --apply to write. Storage files would be kept."
        )
        return result

    with transaction.atomic():
        retarget_qs.update(document_type=canonical)

        for canonical_doc, legacy_doc in duplicate_pairs:
            if _winner(canonical_doc, legacy_doc).pk == legacy_doc.pk:
                _copy_legacy_onto_canonical(canonical_doc, legacy_doc)
            _delete_row_keeping_storage(legacy_doc.pk)

        leftover = ApplicantDocument.objects.filter(document_type=legacy).count()
        if leftover:
            raise RuntimeError(
                f"Refusing to delete pas-photo: {leftover} documents still point at it."
            )
        legacy.delete()
        result.type_deleted = True

    cache.delete("document_types_all")
    cache.delete("document_types_required")
    cache.delete("document_types_public_list")
    return result
