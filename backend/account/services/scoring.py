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
PROFILE_COMPLETENESS_FIELDS: tuple[str, ...] = (
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
    """
    total = len(PROFILE_COMPLETENESS_FIELDS)
    if total == 0:
        return 0.0

    filled = 0
    for field in PROFILE_COMPLETENESS_FIELDS:
        if _is_filled(_get_nested_attr(applicant_profile, field)):
            filled += 1

    return filled / float(total)


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

