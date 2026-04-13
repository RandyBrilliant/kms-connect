"""
Scoring utilities for ApplicantProfile (pelamar readiness score).

Design goals:
- Pure, side-effect free functions (no DB writes, no external I/O).
- Centralised, declarative configuration so new criteria are easy to add.
- Fast enough to run on every relevant save (only uses already-loaded fields).

Current v1 score:
- Profile completeness (important biodata fields)
- Document completeness (approved document ratio, using existing properties)
"""

from __future__ import annotations

from typing import Any, Iterable


# We deliberately do NOT import ApplicantProfile here to avoid circular imports.
# All functions work with any object that has the expected attributes.


PROFILE_COMPLETENESS_WEIGHT: float = 0.6
DOCUMENT_WEIGHT: float = 0.4


# Important biodata fields that count towards profile completeness.
# We prefer *_id fields for FKs to avoid triggering extra DB fetches.
#
# Groups below roughly align with the applicant form sections:
#   1. Data pribadi (basic identity + contact)
#   2. Data pribadi tambahan
#   3. Ciri fisik
#   4. Data paspor
#   5. Informasi rujukan
#   6. Data orang tua (grouped: if either Ayah or Ibu is filled → full credit)
#   7. Ahli waris (grouped: requires at least nama + kontak)
PROFILE_COMPLETENESS_FIELDS: tuple[str, ...] = (
    # --- Data pribadi (existing fields) ---
    "user.full_name",
    "nik",
    "birth_date",
    "gender",
    "address",
    "contact_phone",
    "province_id",
    "district_id",
    "village_id",
    "education_level",
    "marital_status",
    # --- Data pribadi tambahan ---
    "registration_date",
    "destination_country",
    "sibling_count",
    "birth_order",
    "religion",
    "education_major",
    "data_declaration_confirmed",
    "zero_cost_understood",
    # --- Ciri fisik ---
    "height_cm",
    "weight_kg",
    "wears_glasses",
    "writing_hand",
    "shoe_size",
    "shirt_size",
    # --- Data paspor ---
    "passport_number",
    "passport_issue_date",
    "passport_issue_place",
    "passport_expiry_date",
    # --- Informasi rujukan ---
    "referrer_id",
)

# Grouped completeness units. Each group contributes 1 "slot" to the
# completeness ratio.
PROFILE_COMPLETENESS_GROUPS: tuple[dict[str, Any], ...] = (
    {
        "name": "parent_info",
        "fields": ("father_name", "mother_name"),
        "mode": "any",  # either Ayah or Ibu data is sufficient
    },
    {
        "name": "heir_info",
        "fields": ("heir_name", "heir_contact_phone"),
        "mode": "all",  # require at least name + contact
    },
)


def _get_nested_attr(obj: Any, path: str) -> Any:
    """
    Safely get a nested attribute via dotted path (e.g. \"user.full_name\").

    Returns None when any part of the path is missing instead of raising.
    """
    current: Any = obj
    for part in path.split("."):
        if current is None:
            return None
        # Support dict-like objects if ever needed
        if isinstance(current, dict):
            current = current.get(part)
        else:
            current = getattr(current, part, None)
    return current


def _is_filled(value: Any) -> bool:
    """
    Determine whether a field should be considered "filled" for completeness.

    Rules:
    - None -> False
    - Empty string -> False
    - Booleans -> use their actual value (True counts, False does not)
    - For numbers, zero is allowed and treated as filled (if not None)
    - For other types, rely on truthiness.
    """
    if value is None:
        return False
    if isinstance(value, str):
        return value.strip() != ""
    if isinstance(value, bool):
        return value
    return True


def profile_completeness_ratio(applicant_profile: Any) -> float:
    """
    Calculate ratio (0..1) of important biodata fields that are filled.

    Includes both individual fields (PROFILE_COMPLETENESS_FIELDS) and grouped
    units (PROFILE_COMPLETENESS_GROUPS).
    """
    total = len(PROFILE_COMPLETENESS_FIELDS) + len(PROFILE_COMPLETENESS_GROUPS)
    if total == 0:
        return 0.0

    filled = 0
    # Count individual fields
    for field in PROFILE_COMPLETENESS_FIELDS:
        if _is_filled(_get_nested_attr(applicant_profile, field)):
            filled += 1

    # Count grouped fields
    for group in PROFILE_COMPLETENESS_GROUPS:
        fields: Iterable[str] = group.get("fields", ())
        mode = group.get("mode", "any")
        values = [_get_nested_attr(applicant_profile, f) for f in fields]
        if mode == "all":
            if all(_is_filled(v) for v in values):
                filled += 1
        else:  # "any"
            if any(_is_filled(v) for v in values):
                filled += 1

    return filled / float(total)


def profile_missing_fields(applicant_profile: Any) -> list[str]:
    """
    Return list of important biodata field paths that are currently empty.

    Field names use the same dotted paths as PROFILE_COMPLETENESS_FIELDS so
    the frontend can either show them directly or map them to human labels.

    Group entries use the synthetic names defined in PROFILE_COMPLETENESS_GROUPS
    (e.g. "parent_info", "heir_info") so the frontend can treat them as a
    single unit in the UI.
    """
    missing: list[str] = []
    for field in PROFILE_COMPLETENESS_FIELDS:
        if not _is_filled(_get_nested_attr(applicant_profile, field)):
            missing.append(field)

    for group in PROFILE_COMPLETENESS_GROUPS:
        name = group.get("name") or ",".join(group.get("fields", ()))
        fields: Iterable[str] = group.get("fields", ())
        mode = group.get("mode", "any")
        values = [_get_nested_attr(applicant_profile, f) for f in fields]
        if mode == "all":
            if not all(_is_filled(v) for v in values):
                missing.append(str(name))
        else:  # "any"
            if not any(_is_filled(v) for v in values):
                missing.append(str(name))
    return missing


def document_ratio(applicant_profile: Any) -> float:
    """
    Ratio (0..1) based on approved documents.

    Uses ApplicantProfile.document_approval_rate if available.
    - 0 if property is missing or cannot be evaluated.
    - 0 if there are no documents.
    """
    rate: float | int | None
    try:
        rate = getattr(applicant_profile, "document_approval_rate", None)
    except Exception:
        # Be defensive: if anything goes wrong, treat as 0 rather than failing save.
        return 0.0

    if rate is None:
        return 0.0
    try:
        numeric = float(rate)
    except (TypeError, ValueError):
        return 0.0

    if numeric <= 0:
        return 0.0
    if numeric >= 100:
        return 1.0
    return numeric / 100.0


def calculate_readiness_score(applicant_profile: Any) -> float:
    """
    Calculate overall readiness score for an applicant (0..100, rounded to 1 decimal).

    Current formula:
        total = (
            profile_completeness_ratio * PROFILE_COMPLETENESS_WEIGHT * 100
            + document_ratio * DOCUMENT_WEIGHT * 100
        )

    The function is intentionally pure and side-effect free.
    """
    pc_ratio = profile_completeness_ratio(applicant_profile)
    doc_ratio_val = document_ratio(applicant_profile)

    total = (
        pc_ratio * PROFILE_COMPLETENESS_WEIGHT * 100.0
        + doc_ratio_val * DOCUMENT_WEIGHT * 100.0
    )

    if total < 0.0:
        total = 0.0
    elif total > 100.0:
        total = 100.0

    # Round for stable display/sorting
    return round(total, 1)


def _missing_required_document_codes(applicant_profile: Any) -> list[str]:
    """
    Return list of document codes that are missing or not approved for scoring.

    Only the following documents are included in the scoring model:
      1. KTP (code: ktp)
      2. Kartu Keluarga (code: kartu-keluarga)
      3. Ijazah (code: ijasah)
      4. Kartu BPJS Kesehatan (code: kartu-bpjs)
      5. Paspor (code: paspor) – ONLY if applicant_profile.has_passport is truthy
      6. Pas Foto (code: pas-foto)
    """
    try:
        from account.models import ApplicantDocument  # type: ignore
    except Exception:
        # If models cannot be imported (e.g. during migration), fall back gracefully.
        return []

    profile_id = getattr(applicant_profile, "id", None)
    if not profile_id:
        return []

    # Base codes always required for scoring
    required_codes: list[str] = [
        "ktp",
        "kartu-keluarga",
        "ijasah",
        "kartu-bpjs",
        "pas-foto",
    ]

    # Paspor only counted when applicant indicates they have a passport
    has_passport = getattr(applicant_profile, "has_passport", None)
    if has_passport:
        required_codes.append("paspor")

    # Codes of documents that are already approved for this applicant
    approved_codes = set(
        ApplicantDocument.objects.filter(
            applicant_profile_id=profile_id,
            document_type__code__in=required_codes,
            review_status="APPROVED",
        ).values_list("document_type__code", flat=True)
    )

    return [code for code in required_codes if code not in approved_codes]


def explain_readiness_score(applicant_profile: Any) -> dict:
    """
    Return a structured explanation/breakdown of the readiness score.

    This is intended for admin/frontend display so they can see exactly which
    parts of the biodata/documents are still incomplete, without having to
    recalculate anything on the client.

    The structure is stable and safe to expose via API.
    """
    try:
        pc_ratio = profile_completeness_ratio(applicant_profile)
        doc_ratio_val = document_ratio(applicant_profile)
        total = calculate_readiness_score(applicant_profile)
        missing_profile = profile_missing_fields(applicant_profile)
        missing_docs = _missing_required_document_codes(applicant_profile)
    except Exception:
        # Never let explanation errors break API responses.
        return {}

    return {
        "score": total,
        "profile_completeness_ratio": pc_ratio,
        "document_ratio": doc_ratio_val,
        "profile_missing_fields": missing_profile,
        "missing_required_document_codes": missing_docs,
    }


def recalculate_and_persist_score(applicant_profile: Any) -> None:
    """
    Convenience helper to recompute and persist score for a profile.

    This is intended to be called from model methods (e.g. ApplicantDocument.save/delete)
    where we already have a profile instance.
    """
    from account.models import ApplicantProfile  # type: ignore

    if not isinstance(applicant_profile, ApplicantProfile):
        return

    try:
        new_score = calculate_readiness_score(applicant_profile)
    except Exception:
        # Fail-safe: never break save/delete flows because of scoring.
        return

    if applicant_profile.score == new_score:
        return

    applicant_profile.score = new_score
    applicant_profile.save(update_fields=["score"])

