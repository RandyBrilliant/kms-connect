"""
Celery tasks for the chat app.
"""
from celery import shared_task


@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=2)
def send_chat_push_notification(self, message_id: int):
    """
    Kirim FCM push notification ke penerima pesan baru.
    Dipanggil setelah ChatMessage dibuat di views.

    Logika penerima:
    - Jika pengirim adalah pelamar → notifikasi ke admin yang menangani lamaran.
    - Jika pengirim adalah admin/staff → notifikasi ke pelamar.
    """
    from account.models import UserRole
    from account.services.fcm_service import send_fcm_to_user

    from .models import ChatMessage

    msg = (
        ChatMessage.objects
        .filter(pk=message_id)
        .select_related(
            "sender",
            "thread__application__applicant__user",
            "thread__application__reviewed_by",
            "thread__application__assigned_by",
        )
        .first()
    )
    if not msg:
        return

    application = msg.thread.application
    sender = msg.sender

    # Determine recipient
    if sender.role == UserRole.APPLICANT:
        # Notify the admin currently handling this application
        recipient = application.reviewed_by or application.assigned_by
    else:
        # Notify the applicant
        recipient = getattr(application.applicant, "user", None)

    if not recipient:
        return

    send_fcm_to_user(
        user=recipient,
        title=f"Pesan baru dari {sender.full_name or sender.email}",
        body=msg.body[:120],
        data={
            "type": "chat_message",
            "thread_id": str(msg.thread_id),
            "message_id": str(msg.pk),
            "application_id": str(application.pk),
        },
        notification_type="chat",
        priority="high",
    )
