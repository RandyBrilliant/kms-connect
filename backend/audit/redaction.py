"""
Helpers to keep audit metadata free of secrets and bulky payloads.
"""
from __future__ import annotations

from typing import Any, Iterable

# Field names (case-insensitive) that must never appear in metadata values.
SENSITIVE_KEYS = frozenset(
    {
        "password",
        "old_password",
        "new_password",
        "confirm_password",
        "token",
        "access",
        "refresh",
        "otp",
        "code",
        "secret",
        "authorization",
        "cookie",
        "ktp",
        "file",
        "image",
        "content",
        "body",
        "message",
        "id_token",
        "identity_token",
        "google_id",
        "apple_id",
    }
)

MAX_METADATA_KEYS = 40
MAX_STRING_LEN = 200
MAX_LIST_LEN = 20


def sanitize_metadata(data: dict[str, Any] | None) -> dict[str, Any]:
    """Return a shallow-safe copy of metadata with secrets stripped."""
    if not data:
        return {}
    out: dict[str, Any] = {}
    for i, (key, value) in enumerate(data.items()):
        if i >= MAX_METADATA_KEYS:
            out["_truncated"] = True
            break
        key_str = str(key)
        if key_str.lower() in SENSITIVE_KEYS:
            continue
        out[key_str] = _sanitize_value(value)
    return out


def changed_field_names(fields: Iterable[str] | None) -> list[str]:
    """Return non-sensitive field names only."""
    if not fields:
        return []
    names: list[str] = []
    for name in fields:
        if str(name).lower() in SENSITIVE_KEYS:
            continue
        names.append(str(name))
        if len(names) >= MAX_METADATA_KEYS:
            break
    return names


def _sanitize_value(value: Any) -> Any:
    if value is None or isinstance(value, (bool, int, float)):
        return value
    if isinstance(value, str):
        if len(value) > MAX_STRING_LEN:
            return value[: MAX_STRING_LEN - 1] + "…"
        return value
    if isinstance(value, (list, tuple)):
        items = list(value)[:MAX_LIST_LEN]
        return [_sanitize_value(v) for v in items]
    if isinstance(value, dict):
        return sanitize_metadata(value)
    # Files, bytes, complex objects → string label only
    return str(value)[:MAX_STRING_LEN]
