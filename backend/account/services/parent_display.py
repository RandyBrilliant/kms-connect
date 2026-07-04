"""Shared formatting for orang tua / keluarga fields when deceased (almarhum)."""

ALM_PREFIX = "Alm."
ALM_AGE_PLACEHOLDER = "-"


def format_parent_name(name: str | None, *, almarhum: bool) -> str:
    """Return display name; prepend ``Alm.`` when marked almarhum."""
    raw = (name or "").strip()
    if not almarhum:
        return raw
    if not raw:
        return ALM_PREFIX
    upper = raw.upper()
    if upper.startswith("ALM.") or upper.startswith("ALM "):
        return raw
    return f"{ALM_PREFIX} {raw}"


def format_parent_age(age, *, almarhum: bool, fallback: str = "") -> str:
    """Return age for display; ``-`` when marked almarhum."""
    if almarhum:
        return ALM_AGE_PLACEHOLDER
    if age is None:
        return fallback
    s = str(age).strip()
    return s if s else fallback
