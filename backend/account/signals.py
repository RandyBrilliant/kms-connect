"""
Signals for account app.

- Queue OCR when a KTP ApplicantDocument is created or its file is replaced (saves Vision quota).
- Queue image optimization for large image documents.
- Auto-generate referral codes for new staff/admin users.
- Auto-create NotificationPreference for every new user.
- Fire notification events when ApplicantProfile verification status changes.
- Fire notification event when a document is rejected.
- Send FCM push notification whenever a new Notification record is created.
"""
from django.db.models.signals import pre_save, post_save, post_delete
from django.dispatch import receiver

from .document_specs import MAX_IMAGE_BYTES, is_image_type
from .models import (
    ApplicantDocument,
    ApplicantProfile,
    ApplicantVerificationStatus,
    CustomUser,
    DocumentReviewStatus,
    DocumentType,
    NotificationPreference,
    UserRole,
    Notification,
)
from .tasks import process_document_ocr, optimize_document_image
from django.core.cache import cache


def _previous_file_name(instance: ApplicantDocument) -> str | None:
    """Nama file sebelum save (untuk deteksi ganti file)."""
    return getattr(instance, "_previous_file_name", None)


@receiver(pre_save, sender=ApplicantDocument)
def _store_previous_file_name(sender, instance: ApplicantDocument, **kwargs):
    if instance.pk:
        try:
            old = ApplicantDocument.objects.only("file").get(pk=instance.pk)
            instance._previous_file_name = old.file.name if old.file else None
        except ApplicantDocument.DoesNotExist:
            instance._previous_file_name = None
    else:
        instance._previous_file_name = None


def _file_was_created_or_replaced(instance: ApplicantDocument, created: bool) -> bool:
    if not instance.file:
        return False
    if created:
        return True
    prev = _previous_file_name(instance)
    return prev != (instance.file.name if instance.file else None)


def _is_ktp_document_for_ocr(instance: ApplicantDocument) -> bool:
    """Google Vision OCR hanya untuk tipe dokumen KTP (hemat quota)."""
    if not instance.document_type_id:
        return False
    doc_type = getattr(instance, "document_type", None)
    if doc_type is not None:
        return doc_type.code == "ktp"
    return DocumentType.objects.filter(pk=instance.document_type_id, code="ktp").exists()


@receiver(post_save, sender=ApplicantDocument)
def queue_ocr_on_document_upload(sender, instance: ApplicantDocument, created, **kwargs):
    """
    Setelah KTP diunggah (baru atau file diganti), antrekan OCR di background.
    Dokumen selain KTP tidak memanggil Vision. Skipped when KTP_OCR_ENABLED is off.
    """
    from django.conf import settings

    if not getattr(settings, "KTP_OCR_ENABLED", False):
        return
    if not _file_was_created_or_replaced(instance, created):
        return
    if not _is_ktp_document_for_ocr(instance):
        return
    process_document_ocr.delay(instance.pk)


@receiver(post_save, sender=ApplicantDocument)
def queue_optimize_image_on_upload(sender, instance: ApplicantDocument, created, **kwargs):
    """
    Untuk dokumen tipe gambar: jika ukuran > 500 KB, antrekan kompresi di background.
    """
    if not instance.file or not instance.document_type_id:
        return
    if not is_image_type(instance.document_type.code):
        return
    if not _file_was_created_or_replaced(instance, created):
        return
    try:
        if instance.file.size <= MAX_IMAGE_BYTES:
            return
    except (OSError, ValueError):
        return
    optimize_document_image.delay(instance.pk)


@receiver(post_save, sender=ApplicantDocument)
@receiver(post_delete, sender=ApplicantDocument)
def invalidate_applicant_document_cache(sender, instance: ApplicantDocument, **kwargs):
    """Invalidate applicant document cache when documents change or are deleted."""
    if instance.applicant_profile_id:
        cache.delete(f"applicant_{instance.applicant_profile_id}_doc_approval_rate")
        cache.delete(f"applicant_{instance.applicant_profile_id}_complete_docs")


@receiver(post_save, sender=CustomUser)
def auto_generate_referral_code(sender, instance: CustomUser, created, **kwargs):
    """
    Auto-generate referral code for new staff/admin users.
    Also ensures existing staff/admin get codes if they don't have one.
    """
    if instance.role not in (UserRole.STAFF, UserRole.MASTER_ADMIN, UserRole.ADMIN):
        return
    
    if not instance.referral_code:
        instance.ensure_referral_code()


@receiver(post_save, sender=Notification)
def send_push_on_notification_created(sender, instance: Notification, created: bool, **kwargs):
    """
    Immediately deliver an FCM push notification whenever a new Notification
    record is created — regardless of how it was created (Django admin,
    broadcast delivery, API, signals, etc.).

    Respects the ``_skip_push`` flag set by notification_dispatcher.dispatch()
    when the user's push preference is disabled.

    Runs in a daemon thread so it is non-blocking and does NOT depend on the
    Celery worker being available. This guarantees real-time delivery even in
    development environments where Celery may not be running.
    """
    if not created:
        return

    # Dispatcher can tag the instance to skip push for this notification
    if getattr(instance, "_skip_push", False):
        return

    notification_id = instance.pk
    user = instance.user
    title = instance.title
    message = instance.message
    notification_type = instance.notification_type
    priority = instance.priority
    action_url = instance.action_url or ""
    action_label = instance.action_label or ""

    import threading

    def _send_push():
        try:
            from .services.fcm_service import send_fcm_to_user
            import django.db
            try:
                data = {
                    "notification_id": str(notification_id),
                    "action_url": action_url,
                    "action_label": action_label,
                }
                fcm_priority = "high" if priority in ["HIGH", "URGENT"] else "normal"
                send_fcm_to_user(
                    user=user,
                    title=title,
                    body=message,
                    data=data,
                    notification_type=notification_type,
                    priority=fcm_priority,
                )
            finally:
                django.db.close_old_connections()
        except Exception as exc:
            import logging
            logging.getLogger(__name__).warning(
                "FCM push delivery failed for notification %s: %s", notification_id, exc
            )

    thread = threading.Thread(target=_send_push, daemon=True)
    thread.start()


# ---------------------------------------------------------------------------
# Auto-create NotificationPreference when a new user is created
# ---------------------------------------------------------------------------

@receiver(post_save, sender=CustomUser)
def auto_create_notification_preference(sender, instance: CustomUser, created: bool, **kwargs):
    """Create a NotificationPreference record for every new user."""
    if created:
        NotificationPreference.objects.get_or_create(user=instance)


# ---------------------------------------------------------------------------
# Profile verification status change → dispatch notifications
# ---------------------------------------------------------------------------

@receiver(pre_save, sender=ApplicantProfile)
def _store_previous_verification_status(sender, instance: ApplicantProfile, **kwargs):
    """Cache the old verification_status before save so we can detect changes."""
    if instance.pk:
        try:
            old = ApplicantProfile.objects.only("verification_status").get(pk=instance.pk)
            instance._previous_verification_status = old.verification_status
        except ApplicantProfile.DoesNotExist:
            instance._previous_verification_status = None
    else:
        instance._previous_verification_status = None


@receiver(post_save, sender=ApplicantProfile)
def notify_on_verification_status_change(
    sender, instance: ApplicantProfile, created: bool, **kwargs
):
    """
    Dispatch in-app + email + push notifications when a profile's verification
    status changes to ACCEPTED or REJECTED.

    Also notifies Admin/Staff when a new SUBMITTED profile arrives.
    """
    from .services.notification_dispatcher import dispatch, build_profile_context
    from .services.notification_events import NotificationEvent

    new_status = instance.verification_status
    old_status = getattr(instance, "_previous_verification_status", None)

    # Skip if status hasn't changed (or it's a new record not yet SUBMITTED)
    if new_status == old_status:
        return

    ctx = build_profile_context(instance)

    if new_status == ApplicantVerificationStatus.ACCEPTED:
        dispatch(
            event=NotificationEvent.PROFILE_ACCEPTED,
            user=instance.user,
            context=ctx,
            action_url="/profil",
            action_label="Lihat Profil",
        )

    elif new_status == ApplicantVerificationStatus.REJECTED:
        dispatch(
            event=NotificationEvent.PROFILE_REJECTED,
            user=instance.user,
            context=ctx,
        )

    elif new_status == ApplicantVerificationStatus.SUBMITTED:
        # Notify all Admin and Staff users about the new submission
        # OPTIMIZED: Use dispatch_bulk() instead of looping
        from .services.notification_dispatcher import dispatch_bulk
        
        admins_staff = list(
            CustomUser.objects.filter(
                role__in=[UserRole.MASTER_ADMIN, UserRole.ADMIN, UserRole.STAFF],
                is_active=True,
            ).select_related("notification_preference")
        )
        
        if admins_staff:
            dispatch_bulk(
                event=NotificationEvent.PROFILE_SUBMITTED,
                users=admins_staff,
                context=ctx,
                # SPA + API use CustomUser id, not ApplicantProfile.pk (they often differ).
                action_url=f"/pelamar/{instance.user_id}",
                action_label="Review Profil",
                deduplicate=True,
            )


# ---------------------------------------------------------------------------
# Document rejected → dispatch notification to applicant
# ---------------------------------------------------------------------------

@receiver(pre_save, sender=ApplicantDocument)
def _store_previous_review_status(sender, instance: ApplicantDocument, **kwargs):
    """Cache old review_status before save."""
    if instance.pk:
        try:
            old = ApplicantDocument.objects.only("review_status").get(pk=instance.pk)
            instance._previous_review_status = old.review_status
        except ApplicantDocument.DoesNotExist:
            instance._previous_review_status = None
    else:
        instance._previous_review_status = None


@receiver(post_save, sender=ApplicantDocument)
def notify_on_document_rejected(sender, instance: ApplicantDocument, created: bool, **kwargs):
    """Notify applicant when a specific document is rejected by admin."""
    from .services.notification_dispatcher import dispatch
    from .services.notification_events import NotificationEvent

    if created:
        return

    old_status = getattr(instance, "_previous_review_status", None)
    if (
        instance.review_status == DocumentReviewStatus.REJECTED
        and old_status != DocumentReviewStatus.REJECTED
    ):
        try:
            user = instance.applicant_profile.user
            doc_name = instance.document_type.name if instance.document_type_id else "Dokumen"
            reason = getattr(instance, "review_notes", "") or ""
        except Exception:
            return

        dispatch(
            event=NotificationEvent.DOCUMENT_REJECTED,
            user=user,
            context={"document_name": doc_name, "rejection_reason": reason},
            action_url="/dokumen",
            action_label="Unggah Ulang",
        )
