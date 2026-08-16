"""
Safe audit event emission.

Never raises into the caller. Uses transaction.on_commit so rolled-back
work is not logged. Does not perform extra DB lookups for labels.
"""
from __future__ import annotations

import logging
from typing import Any

from django.db import transaction

from .models import AuditAction, AuditEvent, AuditResourceType
from .redaction import sanitize_metadata

logger = logging.getLogger(__name__)

_USER_AGENT_MAX = 512


def get_client_ip(request) -> str | None:
    if request is None:
        return None
    forwarded = request.META.get("HTTP_X_FORWARDED_FOR")
    if forwarded:
        # First hop is the original client when behind a trusted proxy.
        return forwarded.split(",")[0].strip() or None
    return request.META.get("REMOTE_ADDR") or None


def get_user_agent(request) -> str:
    if request is None:
        return ""
    raw = request.META.get("HTTP_USER_AGENT") or ""
    return raw[:_USER_AGENT_MAX]


def emit(
    *,
    action: str,
    resource_type: str,
    summary: str,
    actor=None,
    request=None,
    resource_id: str | int | None = "",
    resource_label: str = "",
    metadata: dict[str, Any] | None = None,
    actor_email: str | None = None,
    actor_role: str | None = None,
    actor_name: str | None = None,
) -> None:
    """
    Schedule an append-only AuditEvent insert after the current DB transaction
    commits. Failures are logged and never propagated.
    """
    try:
        action_value = action.value if hasattr(action, "value") else str(action)
        resource_type_value = (
            resource_type.value if hasattr(resource_type, "value") else str(resource_type)
        )

        # Validate against known choices (still allow custom strings if needed).
        if action_value not in AuditAction.values:
            logger.warning("Unknown audit action=%s", action_value)
        if resource_type_value not in AuditResourceType.values:
            logger.warning("Unknown audit resource_type=%s", resource_type_value)

        actor_id = None
        email = (actor_email or "").strip()
        role = (actor_role or "").strip()
        name = (actor_name or "").strip()

        if actor is not None:
            actor_id = getattr(actor, "pk", None)
            if not email:
                email = (getattr(actor, "email", None) or "").strip()
            if not role:
                role = (getattr(actor, "role", None) or "").strip()
            if not name:
                name = (getattr(actor, "full_name", None) or "").strip()

        ip = get_client_ip(request)
        ua = get_user_agent(request)
        safe_meta = sanitize_metadata(metadata)
        rid = "" if resource_id is None else str(resource_id)
        label = (resource_label or "")[:255]
        summary_text = (summary or "")[:512]

        def _write():
            try:
                AuditEvent.objects.create(
                    actor_id=actor_id,
                    actor_email=email[:254],
                    actor_role=role[:32],
                    actor_name=name[:255],
                    action=action_value,
                    resource_type=resource_type_value,
                    resource_id=rid[:64],
                    resource_label=label,
                    summary=summary_text,
                    ip_address=ip,
                    user_agent=ua,
                    metadata=safe_meta,
                )
            except Exception:
                logger.exception(
                    "Failed to persist audit event action=%s resource=%s:%s",
                    action_value,
                    resource_type_value,
                    rid,
                )

        # If no transaction is active, on_commit runs immediately.
        transaction.on_commit(_write)
    except Exception:
        logger.exception("Failed to schedule audit event")
