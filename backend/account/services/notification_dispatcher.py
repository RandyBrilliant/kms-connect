"""
Centralized notification dispatcher.

This is the **single entry point** for all application-level notifications.
All code that wants to notify a user should call ``dispatch()`` instead of
creating Notification objects or calling tasks directly.

Design principles
-----------------
- One function per call-site — no scattered ``create_notification()`` calls.
- Preference-gated — respects per-user ``NotificationPreference`` flags.
- Deduplication — rate-limits identical events per user via Redis/cache.
- Channel separation — in-app, email, and push are independently gated.
- Non-blocking — email and push are always queued to Celery; never blocks.

Usage
-----
    from account.services.notification_dispatcher import dispatch
    from account.services.notification_events import NotificationEvent

    dispatch(
        event=NotificationEvent.PROFILE_ACCEPTED,
        user=applicant.user,
        context={"user_name": applicant.user.full_name},
        action_url="/profil",
        action_label="Lihat Profil",
    )
"""

from __future__ import annotations

import logging
from typing import Any

from django.core.cache import cache

from ..models import (
    CustomUser,
    Notification,
    NotificationPreference,
)
from .notification_events import (
    NotificationEvent,
    EventConfig,
    get_event_config,
    render_event_message,
)

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Deduplication helpers
# ---------------------------------------------------------------------------

_DEDUP_WINDOW_SECONDS = 3600  # 1 hour dedup window per event per user


def _dedup_key(user_id: int, event: NotificationEvent) -> str:
    return f"notif_dedup:{user_id}:{event.value}"


def _is_duplicate(user_id: int, event: NotificationEvent) -> bool:
    """Return True if an identical event was dispatched within the dedup window."""
    return bool(cache.get(_dedup_key(user_id, event)))


def _mark_sent(user_id: int, event: NotificationEvent) -> None:
    cache.set(_dedup_key(user_id, event), 1, timeout=_DEDUP_WINDOW_SECONDS)


# ---------------------------------------------------------------------------
# Preference gate
# ---------------------------------------------------------------------------

def _allows_email(pref: NotificationPreference | None, config: EventConfig) -> bool:
    """Return True if user allows email for this event."""
    if not config.send_email:
        return False
    if pref is None:
        return True  # Default ON if no preference record yet
    if config.email_pref_field:
        return getattr(pref, config.email_pref_field, True)
    return True  # No gate = always allow (critical events)


def _allows_push(pref: NotificationPreference | None, config: EventConfig) -> bool:
    """Return True if user allows push for this event."""
    if not config.send_push:
        return False
    if pref is None:
        return True
    if not getattr(pref, "push_enabled", True):
        return False  # Master push toggle
    if config.push_pref_field:
        return getattr(pref, config.push_pref_field, True)
    return True


def _allows_inapp(pref: NotificationPreference | None, config: EventConfig) -> bool:
    """Return True if user allows in-app notifications."""
    if not config.send_inapp:
        return False
    if pref is None:
        return True
    return getattr(pref, "inapp_enabled", True)


# ---------------------------------------------------------------------------
# Main dispatch function
# ---------------------------------------------------------------------------

def dispatch(
    event: NotificationEvent,
    user: CustomUser,
    context: dict[str, Any] | None = None,
    action_url: str | None = None,
    action_label: str = "",
    *,
    deduplicate: bool = True,
    force_email: bool = False,
    force_push: bool = False,
) -> Notification | None:
    """
    Dispatch a notification event to a single user.

    Parameters
    ----------
    event       : The notification event (from NotificationEvent enum).
    user        : The recipient CustomUser.
    context     : Dict used to render the title/message template for this event.
    action_url  : Optional deep-link URL shown in the notification.
    action_label: Optional button label for the action URL.
    deduplicate : If True, skip if the same event was sent to this user
                  within _DEDUP_WINDOW_SECONDS (default: True).
    force_email : Override email preference gate (use for critical events).
    force_push  : Override push preference gate (use for critical events).

    Returns
    -------
    Notification instance if created, None if skipped.
    """
    ctx = context or {}
    config = get_event_config(event)

    # Deduplication guard
    if deduplicate and _is_duplicate(user.pk, event):
        logger.debug("dispatch: duplicate skipped event=%s user=%s", event.value, user.pk)
        return None

    # Load preferences (single cached query; fallback to None)
    pref: NotificationPreference | None = None
    try:
        pref = user.notification_preference
    except NotificationPreference.DoesNotExist:
        pass

    # Resolve channel flags
    send_email = force_email or _allows_email(pref, config)
    send_push = force_push or _allows_push(pref, config)
    send_inapp = _allows_inapp(pref, config)

    # Render message
    try:
        title, message = render_event_message(event, ctx)
    except Exception:
        logger.exception("dispatch: failed to render message for event=%s", event.value)
        title = "Notifikasi"
        message = "Anda memiliki notifikasi baru."

    # Create in-app notification (drives push via post_save signal)
    notification: Notification | None = None
    if send_inapp:
        try:
            notification = Notification(
                user=user,
                title=title,
                message=message,
                notification_type=config.notification_type,
                priority=config.priority,
                action_url=action_url,
                action_label=action_label,
            )
            if not send_push:
                notification._skip_push = True
            notification.save()

        except Exception:
            logger.exception("dispatch: failed to create Notification for event=%s user=%s", event.value, user.pk)

    # Queue email separately (decoupled from in-app)
    if send_email and notification:
        try:
            from ..tasks import send_event_email_task
            send_event_email_task.delay(
                user_id=user.pk,
                event_value=event.value,
                context=_serialise_context(ctx),
                action_url=action_url or "",
            )
        except Exception:
            logger.exception("dispatch: failed to queue email for event=%s user=%s", event.value, user.pk)

    # Mark dedup
    if notification and deduplicate:
        _mark_sent(user.pk, event)

    return notification


def dispatch_bulk(
    event: NotificationEvent,
    users: list[CustomUser],
    context: dict[str, Any] | None = None,
    action_url: str | None = None,
    action_label: str = "",
    *,
    deduplicate: bool = False,  # Off by default for bulk since each user is different
) -> int:
    """
    Dispatch the same event to multiple users.
    Returns the number of notifications created.

    Note: For large recipient lists (>100), prefer a dedicated Celery task to
    avoid blocking the caller. This helper is suitable for small lists.
    """
    count = 0
    for user in users:
        result = dispatch(
            event=event,
            user=user,
            context=context,
            action_url=action_url,
            action_label=action_label,
            deduplicate=deduplicate,
        )
        if result:
            count += 1
    return count


# ---------------------------------------------------------------------------
# Context helpers
# ---------------------------------------------------------------------------

def _serialise_context(ctx: dict) -> dict:
    """
    Make context JSON-safe for Celery task serialization.
    Strips any non-primitive values (model instances, querysets, etc.).
    """
    safe: dict = {}
    for key, val in ctx.items():
        if isinstance(val, (str, int, float, bool, type(None))):
            safe[key] = val
        else:
            safe[key] = str(val)
    return safe


def build_application_context(application) -> dict[str, Any]:
    """
    Build a notification context dict from a JobApplication instance.
    Avoids N+1 — assumes application has been select_related.
    """
    job_title = ""
    company_name = ""
    batch_name = ""
    interview_date_str = ""
    interview_location = ""

    try:
        job_title = application.job.title
    except Exception:
        pass
    try:
        company_name = application.job.company.company_name
    except Exception:
        pass
    try:
        batch_name = application.batch.name if application.batch_id else ""
    except Exception:
        pass
    try:
        if application.batch and application.batch.interview_date:
            interview_date_str = application.batch.interview_date.strftime("%d %B %Y, %H:%M")
            interview_location = application.batch.interview_location or ""
    except Exception:
        pass

    return {
        "job_title": job_title,
        "company_name": company_name,
        "batch_name": batch_name,
        "interview_date_str": interview_date_str,
        "interview_location": interview_location,
        "notes": getattr(application, "notes", ""),
    }


def build_profile_context(profile) -> dict[str, Any]:
    """Build a notification context dict from an ApplicantProfile instance."""
    return {
        "user_name": profile.user.full_name or profile.user.email,
        "applicant_name": profile.user.full_name or profile.user.email,
        "register_number": profile.register_number or "",
        "verification_notes": profile.verification_notes or "",
    }
