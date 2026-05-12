"""
Default Disnaker text from pelamar KTP address: kabupaten/kota (Regency name), uppercase.

Used by admin UI defaults and the backfill management command.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from account.models import ApplicantProfile


def ktp_kabupaten_kota_upper(profile: ApplicantProfile) -> str:
    """
    Return kabupaten/kota for alamat KTP as stored in wilayah hierarchy.

    Prefer regency resolved from ``village`` (kelurahan → kecamatan → kab/kota).
    If there is no village but ``district`` (FK to regions.Regency) is set, use that name.
    """
    name = ""
    village = getattr(profile, "village", None)
    if getattr(profile, "village_id", None) and village is not None:
        district = getattr(village, "district", None)
        if district is not None:
            regency = getattr(district, "regency", None)
            if regency is not None and getattr(regency, "name", None):
                name = (regency.name or "").strip()
    if not name:
        reg = getattr(profile, "district", None)
        if reg is not None and getattr(reg, "name", None):
            name = (reg.name or "").strip()
    return name.upper()
