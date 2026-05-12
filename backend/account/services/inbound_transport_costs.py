"""
Merge DB rows with canonical inbound transport stages for API + PDF.
Tanggal proses per stage comes from JobApplication.diterima_step_confirmations.
"""

from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from typing import TYPE_CHECKING, Any

from django.db import transaction
from django.utils import timezone

from account.inbound_transport_stages import (
    INBOUND_TRANSPORT_STAGE_CODES,
    INBOUND_TRANSPORT_STAGES,
)

if TYPE_CHECKING:
    from account.models import ApplicantInboundTransportStageCost, ApplicantProfile


def _to_decimal(value: Any) -> Decimal | None:
    if value is None or value == "":
        return None
    if isinstance(value, Decimal):
        return value
    try:
        return Decimal(str(value).replace(",", "").strip())
    except (InvalidOperation, ValueError, TypeError):
        return None


def parse_iso_datetime_to_date(value: Any) -> date | None:
    """Parse values stored in ``diterima_step_confirmations`` (ISO strings)."""
    if value is None:
        return None
    if isinstance(value, date) and not isinstance(value, datetime):
        return value
    if isinstance(value, datetime):
        return timezone.localdate(value) if timezone.is_aware(value) else value.date()
    s = str(value).strip()
    if not s:
        return None
    try:
        if s.endswith("Z"):
            s = s[:-1] + "+00:00"
        dt = datetime.fromisoformat(s)
        if timezone.is_aware(dt):
            dt = timezone.localtime(dt)
        return dt.date()
    except ValueError:
        return None


def primary_diterima_job_application_for_profile(profile: ApplicantProfile) -> Any:
    """
    Pick the JobApplication used for sub-tahapan Diterima timestamps.

    Prefer DITERIMA, then BERANGKAT / SELESAI (confirmations JSON may still hold dates).
    """
    from main.models import ApplicationStatus, JobApplication

    base = JobApplication.objects.filter(applicant_id=profile.pk).order_by("-updated_at")
    for st in (
        ApplicationStatus.DITERIMA,
        ApplicationStatus.BERANGKAT,
        ApplicationStatus.SELESAI,
    ):
        app = base.filter(status=st).first()
        if app:
            return app
    return base.first()


def step_confirmation_dates_by_stage_for_profile(profile: ApplicantProfile) -> dict[str, date]:
    """Map Diterima sub-step code → calendar date from confirmations JSON."""
    app = primary_diterima_job_application_for_profile(profile)
    if not app:
        return {}
    raw = app.diterima_step_confirmations
    if not isinstance(raw, dict):
        return {}
    out: dict[str, date] = {}
    for code, val in raw.items():
        d = parse_iso_datetime_to_date(val)
        if d:
            out[str(code)] = d
    return out


def merged_inbound_transport_stage_costs_for_profile(
    profile: ApplicantProfile,
) -> list[dict[str, Any]]:
    """
    One dict per canonical stage, in Diterima order.

    Reads ``profile.inbound_transport_stage_costs`` (prefetch recommended).
    ``tanggal_proses`` is read-only, from the active lamaran's confirmations.
    """
    dates = step_confirmation_dates_by_stage_for_profile(profile)

    by_code: dict[str, ApplicantInboundTransportStageCost] = {}
    for row in profile.inbound_transport_stage_costs.all():
        by_code[row.stage_code] = row

    out: list[dict[str, Any]] = []
    for code, label in INBOUND_TRANSPORT_STAGES:
        row = by_code.get(code)
        amt = None
        if row and row.amount is not None:
            try:
                amt = float(row.amount)
            except (TypeError, ValueError):
                amt = None
        d = dates.get(code)
        out.append(
            {
                "stage_code": code,
                "label": label,
                "amount": amt,
                "keterangan": (row.keterangan or "") if row else "",
                "tanggal_proses": d.isoformat() if d else None,
            }
        )
    return out


@transaction.atomic
def upsert_inbound_transport_stage_costs(
    profile: ApplicantProfile, rows: list[dict[str, Any]]
) -> None:
    """Replace/update rows from admin payload (partial list allowed)."""
    from account.models import ApplicantInboundTransportStageCost

    allowed = set(INBOUND_TRANSPORT_STAGE_CODES)
    for raw in rows:
        if not isinstance(raw, dict):
            raise ValueError("Each inbound_transport_stage_costs item must be an object.")
        code = raw.get("stage_code")
        if code not in allowed:
            raise ValueError(f"Invalid stage_code: {code!r}")

        amount = _to_decimal(raw.get("amount"))
        ket = (raw.get("keterangan") or "")
        if not isinstance(ket, str):
            ket = str(ket)
        ket = ket.strip()[:500]

        if amount is None and not ket:
            ApplicantInboundTransportStageCost.objects.filter(
                profile=profile, stage_code=code
            ).delete()
            continue

        ApplicantInboundTransportStageCost.objects.update_or_create(
            profile=profile,
            stage_code=code,
            defaults={
                "amount": amount,
                "keterangan": ket,
            },
        )
