"""
Filtering and ordering for GET /api/batches/{id}/eligible-applicants/

Keeps query logic out of the viewset and centralizes validation for enums/ranges.
"""

from __future__ import annotations

from datetime import date
from typing import TYPE_CHECKING

from django.db.models import QuerySet
from django.utils.dateparse import parse_date as django_parse_date

from account.models import (
    ApplicantProfile,
    EducationLevel,
    Gender,
    MaritalStatus,
    Religion,
    WritingHand,
)

if TYPE_CHECKING:
    from rest_framework.request import Request

# Ordering allow-list: maps API param -> Django ORM field names (stable tie-break with pk).
_ELIGIBLE_APPLICANT_ORDERING: dict[str, tuple[str, ...]] = {
    "name": ("user__full_name", "pk"),
    "-name": ("-user__full_name", "pk"),
    "height_cm": ("height_cm", "user__full_name", "pk"),
    "-height_cm": ("-height_cm", "user__full_name", "pk"),
    "weight_kg": ("weight_kg", "user__full_name", "pk"),
    "-weight_kg": ("-weight_kg", "user__full_name", "pk"),
    "religion": ("religion", "user__full_name", "pk"),
    "-religion": ("-religion", "user__full_name", "pk"),
    "birth_date": ("birth_date", "user__full_name", "pk"),
    "-birth_date": ("-birth_date", "user__full_name", "pk"),
    "registration_date": ("registration_date", "user__full_name", "pk"),
    "-registration_date": ("-registration_date", "user__full_name", "pk"),
    "nik": ("nik", "pk"),
    "-nik": ("-nik", "pk"),
}

_valid_religion = {c[0] for c in Religion.choices}
_valid_gender = {c[0] for c in Gender.choices}
_valid_education = {c[0] for c in EducationLevel.choices}
_valid_marital = {c[0] for c in MaritalStatus.choices}
_valid_writing_hand = {c[0] for c in WritingHand.choices}


def _parse_optional_int(
    raw: str | None,
    *,
    field_label: str,
    min_value: int | None = None,
    max_value: int | None = None,
) -> tuple[int | None, str | None]:
    if raw is None or raw == "":
        return None, None
    try:
        v = int(raw.strip())
    except ValueError:
        return None, f"{field_label} harus berupa angka."
    if min_value is not None and v < min_value:
        return None, f"{field_label} minimal {min_value}."
    if max_value is not None and v > max_value:
        return None, f"{field_label} maksimal {max_value}."
    return v, None


def _parse_optional_bool(raw: str | None) -> bool | None:
    """Return True/False if set; None if parameter absent or empty."""
    if raw is None or raw == "":
        return None
    s = raw.strip().lower()
    if s in ("true", "1", "yes"):
        return True
    if s in ("false", "0", "no"):
        return False
    return None


def _parse_optional_date(raw: str | None, *, field_label: str) -> tuple[date | None, str | None]:
    if raw is None or raw == "":
        return None, None
    d = django_parse_date(raw.strip())
    if d is None:
        return None, f"{field_label} harus format YYYY-MM-DD."
    return d, None


def resolve_ordering(ordering_param: str | None) -> tuple[tuple[str, ...] | None, str | None]:
    """
    Returns (order_by_tuple, error_message).
    Unknown ordering returns (None, error).
    """
    if not ordering_param or not ordering_param.strip():
        return _ELIGIBLE_APPLICANT_ORDERING["name"], None
    key = ordering_param.strip()
    if key not in _ELIGIBLE_APPLICANT_ORDERING:
        allowed = ", ".join(sorted(_ELIGIBLE_APPLICANT_ORDERING.keys()))
        return None, f"ordering tidak valid. Nilai yang diizinkan: {allowed}"
    return _ELIGIBLE_APPLICANT_ORDERING[key], None


def apply_eligible_applicant_filters(
    qs: QuerySet[ApplicantProfile],
    request: Request,
) -> tuple[QuerySet[ApplicantProfile], str | None]:
    """
    Apply GET query params to the ApplicantProfile queryset.

    Returns (queryset, error_detail). When error_detail is set, the view should 400.
    """
    p = request.query_params

    h_min, err = _parse_optional_int(
        p.get("height_cm_min"), field_label="height_cm_min", min_value=50, max_value=300
    )
    if err:
        return qs, err
    h_max, err = _parse_optional_int(
        p.get("height_cm_max"), field_label="height_cm_max", min_value=50, max_value=300
    )
    if err:
        return qs, err
    if h_min is not None and h_max is not None and h_min > h_max:
        return qs, "height_cm_min tidak boleh lebih besar dari height_cm_max."

    w_min, err = _parse_optional_int(
        p.get("weight_kg_min"), field_label="weight_kg_min", min_value=15, max_value=400
    )
    if err:
        return qs, err
    w_max, err = _parse_optional_int(
        p.get("weight_kg_max"), field_label="weight_kg_max", min_value=15, max_value=400
    )
    if err:
        return qs, err
    if w_min is not None and w_max is not None and w_min > w_max:
        return qs, "weight_kg_min tidak boleh lebih besar dari weight_kg_max."

    bd_from, err = _parse_optional_date(p.get("birth_date_from"), field_label="birth_date_from")
    if err:
        return qs, err
    bd_to, err = _parse_optional_date(p.get("birth_date_to"), field_label="birth_date_to")
    if err:
        return qs, err
    if bd_from is not None and bd_to is not None and bd_from > bd_to:
        return qs, "birth_date_from tidak boleh setelah birth_date_to."

    if p.get("religion", "").strip():
        rv = p.get("religion", "").strip()
        if rv not in _valid_religion:
            return qs, f"religion tidak valid: {rv}"
        qs = qs.filter(religion=rv)

    if p.get("gender", "").strip():
        gv = p.get("gender", "").strip()
        if gv not in _valid_gender:
            return qs, f"gender tidak valid: {gv}"
        qs = qs.filter(gender=gv)

    if p.get("education_level", "").strip():
        ev = p.get("education_level", "").strip()
        if ev not in _valid_education:
            return qs, f"education_level tidak valid: {ev}"
        qs = qs.filter(education_level=ev)

    if p.get("marital_status", "").strip():
        mv = p.get("marital_status", "").strip()
        if mv not in _valid_marital:
            return qs, f"marital_status tidak valid: {mv}"
        qs = qs.filter(marital_status=mv)

    if p.get("writing_hand", "").strip():
        wh = p.get("writing_hand", "").strip()
        if wh not in _valid_writing_hand:
            return qs, f"writing_hand tidak valid: {wh}"
        qs = qs.filter(writing_hand=wh)

    wg = _parse_optional_bool(p.get("wears_glasses"))
    if wg is not None:
        qs = qs.filter(wears_glasses=wg)

    hp = _parse_optional_bool(p.get("has_passport"))
    if hp is not None:
        qs = qs.filter(has_passport=hp)

    # Numeric ranges — exclude null height/weight when filtering by range (explicit behavior).
    if h_min is not None:
        qs = qs.filter(height_cm__isnull=False, height_cm__gte=h_min)
    if h_max is not None:
        qs = qs.filter(height_cm__isnull=False, height_cm__lte=h_max)

    if w_min is not None:
        qs = qs.filter(weight_kg__isnull=False, weight_kg__gte=w_min)
    if w_max is not None:
        qs = qs.filter(weight_kg__isnull=False, weight_kg__lte=w_max)

    if bd_from is not None:
        qs = qs.filter(birth_date__gte=bd_from)
    if bd_to is not None:
        qs = qs.filter(birth_date__lte=bd_to)

    fields, order_err = resolve_ordering(p.get("ordering"))
    if order_err:
        return qs, order_err
    if fields:
        qs = qs.order_by(*fields)

    return qs, None


def applicant_ktp_address_line(profile: ApplicantProfile) -> str:
    """Single readable line from stored KTP hierarchy (best-effort)."""
    if getattr(profile, "village_id", None) and getattr(profile, "village", None):
        v = profile.village
        parts: list[str] = [v.name]
        kec = getattr(v, "district", None)
        if kec:
            parts.append(kec.name)
            kab = getattr(kec, "regency", None)
            if kab:
                parts.append(kab.name)
                prov = getattr(kab, "province", None)
                if prov:
                    parts.append(prov.name)
        return ", ".join(parts)
    if getattr(profile, "district_id", None) and getattr(profile, "district", None):
        regency = profile.district
        parts_r = [regency.name]
        prov = getattr(regency, "province", None)
        if prov:
            parts_r.append(prov.name)
        return ", ".join(parts_r)
    if getattr(profile, "province_id", None) and getattr(profile, "province", None):
        return profile.province.name
    return ""
