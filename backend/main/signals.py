"""
Signals for the main app.

- Dispatch notification events when a JobApplication status changes.
- Dispatch notification when a BatchAnnouncement is created.
"""

from django.db.models.signals import pre_save, post_save
from django.dispatch import receiver

from .models import ApplicationStatus, JobApplication, BatchAnnouncement


# ---------------------------------------------------------------------------
# Job application status change tracking
# ---------------------------------------------------------------------------

@receiver(pre_save, sender=JobApplication)
def _store_previous_application_status(
    sender, instance: JobApplication, **kwargs
):
    """Cache the old status before save so we can detect the transition."""
    if instance.pk:
        try:
            old = JobApplication.objects.only("status").get(pk=instance.pk)
            instance._previous_status = old.status
        except JobApplication.DoesNotExist:
            instance._previous_status = None
    else:
        instance._previous_status = None


@receiver(post_save, sender=JobApplication)
def notify_on_application_status_change(
    sender, instance: JobApplication, created: bool, **kwargs
):
    """
    Dispatch the appropriate NotificationEvent when a JobApplication's status
    changes. Handles both new assignments (created=True → PRA_SELEKSI) and
    admin-driven status transitions.

    The notification_dispatcher respects the applicant's NotificationPreference
    for both email and push delivery.
    """
    from account.services.notification_dispatcher import dispatch, build_application_context
    from account.services.notification_events import NotificationEvent

    old_status = getattr(instance, "_previous_status", None)
    new_status = instance.status

    # Skip if no change (only field update, not status transition)
    if not created and new_status == old_status:
        return

    user = None
    try:
        # Reuse cached related object if already loaded
        user = instance.applicant.user
    except Exception:
        return

    if not user or not user.is_active:
        return

    # Eagerly load related objects for context building (avoid N+1)
    try:
        if not hasattr(instance, "_job_loaded"):
            instance = (
                JobApplication.objects
                .select_related("job__company", "batch", "applicant__user")
                .get(pk=instance.pk)
            )
    except JobApplication.DoesNotExist:
        return

    ctx = build_application_context(instance)
    ctx["user_name"] = instance.applicant.user.full_name or instance.applicant.user.email

    # Map status → event
    status_event_map = {
        ApplicationStatus.PRA_SELEKSI: NotificationEvent.APPLICATION_ASSIGNED,
        ApplicationStatus.INTERVIEW:   NotificationEvent.APPLICATION_INTERVIEW,
        ApplicationStatus.DITERIMA:    NotificationEvent.APPLICATION_ACCEPTED,
        ApplicationStatus.DITOLAK:     NotificationEvent.APPLICATION_REJECTED,
        ApplicationStatus.BERANGKAT:   NotificationEvent.APPLICATION_DEPARTED,
        ApplicationStatus.SELESAI:     NotificationEvent.APPLICATION_COMPLETED,
    }

    event = status_event_map.get(new_status)
    if not event:
        return

    # Build deep-link URL to the specific application
    action_url = f"/lamaran/{instance.pk}"
    action_label = "Lihat Detail"

    dispatch(
        event=event,
        user=user,
        context=ctx,
        action_url=action_url,
        action_label=action_label,
        # Don't deduplicate application status changes — each transition is unique.
        deduplicate=False,
    )


# ---------------------------------------------------------------------------
# Batch announcement → notify all applicants in the batch
# ---------------------------------------------------------------------------

@receiver(post_save, sender=BatchAnnouncement)
def notify_on_batch_announcement(
    sender, instance: BatchAnnouncement, created: bool, **kwargs
):
    """
    When a new BatchAnnouncement is posted, notify applicants selected by
    recipient_config (in-app + push).
    """
    if not created:
        return

    from account.services.notification_dispatcher import dispatch_bulk
    from account.services.notification_events import NotificationEvent
    from .batch_announcement_recipients import applications_for_recipient_config

    try:
        batch = instance.batch
        job_title = batch.job.title if batch.job_id else ""
    except Exception:
        return

    ctx = {
        "batch_name": batch.name,
        "job_title": job_title,
        "announcement_title": instance.title,
        "announcement_body": instance.body,
    }

    config = instance.recipient_config or {}
    applications = applications_for_recipient_config(batch, config).select_related(
        "applicant__user",
        "applicant__user__notification_preference",
    )

    users = [app.applicant.user for app in applications]

    if users:
        dispatch_bulk(
            event=NotificationEvent.BATCH_ANNOUNCEMENT,
            users=users,
            context=ctx,
            action_url=f"/batch/{batch.pk}/announcements",
            action_label="Lihat Pengumuman",
            deduplicate=False,
        )
