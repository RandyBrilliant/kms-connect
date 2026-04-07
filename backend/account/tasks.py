"""
Background tasks for KMS-Connect (Celery).
Use for: email, OCR, export to Excel, push notifications, etc.
"""
from celery import shared_task


@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=3)
def process_document_ocr(self, document_id: int):
    """
    Jalankan OCR pada ApplicantDocument via Google Cloud Vision.
    Simpan full text ke ocr_text; untuk KTP parse ke ocr_data (nik, name, dll.).
    
    Uses bounding box extraction for improved KTP field accuracy.
    Panggil setelah upload: process_document_ocr.delay(doc.pk)
    """
    from django.conf import settings
    from django.utils import timezone

    from .models import ApplicantDocument
    from .ocr import parse_ktp_text, _extract_text_blocks

    doc = ApplicantDocument.objects.filter(pk=document_id).first()
    if not doc or not doc.file:
        return

    try:
        from google.cloud import vision
        from google.api_core.exceptions import PermissionDenied, InvalidArgument
    except ImportError:
        return

    if not getattr(settings, "GOOGLE_APPLICATION_CREDENTIALS", None) and not __import__("os").environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
        return

    with doc.file.open("rb") as f:
        content = f.read()

    client = vision.ImageAnnotatorClient()
    image = vision.Image(content=content)
    response = client.document_text_detection(image=image)

    if response.error.message:
        raise RuntimeError(response.error.message)

    full_text = (response.full_text_annotation.text or "").strip()
    doc.ocr_text = full_text
    doc.ocr_processed_at = timezone.now()

    if doc.document_type and doc.document_type.code == "ktp" and full_text:
        # Extract text blocks with bounding boxes for spatial parsing
        blocks = _extract_text_blocks(response)
        doc.ocr_data = parse_ktp_text(full_text, blocks)
    else:
        doc.ocr_data = doc.ocr_data or {}

    doc.save(update_fields=["ocr_text", "ocr_data", "ocr_processed_at"])


@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=2)
def optimize_document_image(self, document_id: int):
    """
    Kompresi gambar dokumen (JPG/PNG) agar ≤ 500 KB.
    Dipanggil setelah upload untuk tipe image; jika sudah ≤ 500 KB tidak dilakukan apa-apa.
    """
    from io import BytesIO
    from django.core.files.base import ContentFile

    from .models import ApplicantDocument
    from .document_specs import is_image_type, MAX_IMAGE_BYTES

    doc = ApplicantDocument.objects.filter(pk=document_id).select_related("document_type").first()
    if not doc or not doc.file or not doc.document_type:
        return
    if not is_image_type(doc.document_type.code):
        return
    try:
        size = doc.file.size
    except (OSError, ValueError):
        return
    if size <= MAX_IMAGE_BYTES:
        return

    try:
        from PIL import Image
    except ImportError:
        return

    with doc.file.open("rb") as f:
        try:
            im = Image.open(f).convert("RGB")
        except Exception:
            return

    # Resize jika dimensi sangat besar (hemat memori & ukuran)
    max_side = 2048
    w, h = im.size
    if w > max_side or h > max_side:
        im.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)

    # Kompresi JPEG dengan quality turun bertahap sampai ≤ 500 KB
    target = MAX_IMAGE_BYTES
    for quality in (85, 75, 65, 55, 45):
        buf = BytesIO()
        im.save(buf, "JPEG", quality=quality, optimize=True)
        if buf.tell() <= target:
            break
    else:
        # Masih besar: skala lagi
        while buf.tell() > target and max_side > 320:
            max_side = int(max_side * 0.75)
            im = im.resize((min(im.width, max_side), min(im.height, max_side)), Image.Resampling.LANCZOS)
            buf = BytesIO()
            im.save(buf, "JPEG", quality=55, optimize=True)

    buf.seek(0)
    name = doc.file.name.split("/")[-1]
    if not name.lower().endswith((".jpg", ".jpeg")):
        name = (name.rsplit(".", 1)[0] if "." in name else name) + ".jpg"
    doc.file.save(name, ContentFile(buf.read()), save=True)


@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=5)
def send_email_async(self, to_email: str, subject: str, body: str, html_message: str = None):
    """
    Kirim email di background via Django (Mailgun API bila MAILGUN_API_KEY diset).
    Rate-limited to prevent Mailgun API errors.
    """
    from .services.email_service import send_email
    from .services.rate_limiter import RateLimitExceeded

    try:
        send_email(
            to=to_email,
            subject=subject,
            body=body,
            html=html_message,
            fail_silently=False,
        )
    except RateLimitExceeded as e:
        # Retry with delay when rate limited
        raise self.retry(exc=e, countdown=e.retry_after + 1)


@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=5)
def send_verification_email_task(self, user_id: int, logo_url: str = "", verification_code: str = ""):
    """
    Kirim email verifikasi dengan 6-digit kode ke user.
    verification_code: 6-digit kode verifikasi.
    Rate-limited to prevent Mailgun API errors.
    """
    from .models import CustomUser
    from .email_utils import render_email, COMPANY_NAME
    from .services.email_service import send_email
    from .services.rate_limiter import RateLimitExceeded

    user = CustomUser.objects.filter(pk=user_id).first()
    if not user or not verification_code:
        return

    context = {
        "user": user,
        "verification_code": verification_code,
        "logo_url": logo_url or "",
        "subject": "Kode Verifikasi Email – " + COMPANY_NAME,
        "body_text": (
            f"Halo,\n\n"
            f"Kode verifikasi email Anda adalah: {verification_code}\n\n"
            f"Kode ini berlaku selama 10 menit.\n"
            f"Jika Anda tidak mendaftar, abaikan email ini.\n\n"
            f"Salam,\n{COMPANY_NAME}"
        ),
    }
    html, plain = render_email("account/emails/verification_email.html", context)
    
    try:
        send_email(
            to=user.email,
            subject=context["subject"],
            body=plain,
            html=html,
            fail_silently=False,
        )
    except RateLimitExceeded as e:
        raise self.retry(exc=e, countdown=e.retry_after + 1)


@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=5)
def send_password_reset_email_task(self, user_id: int, logo_url: str = ""):
    """
    Kirim email reset password ke user. Dipanggil oleh admin (send-password-reset).
    Rate-limited to prevent Mailgun API errors.
    """
    from .models import CustomUser
    from .email_utils import render_email, make_password_reset_link, COMPANY_NAME
    from .services.email_service import send_email
    from .services.rate_limiter import RateLimitExceeded

    user = CustomUser.objects.filter(pk=user_id).first()
    if not user:
        return

    reset_url = make_password_reset_link(user)
    if not reset_url:
        return

    context = {
        "user": user,
        "reset_url": reset_url,
        "logo_url": logo_url or "",
        "subject": "Reset Password – " + COMPANY_NAME,
        "body_text": f"Halo,\n\nAnda meminta reset password. Klik tautan berikut untuk mengatur ulang kata sandi:\n{reset_url}\n\nJika Anda tidak meminta ini, abaikan email ini.\n\nSalam,\n{COMPANY_NAME}",
    }
    html, plain = render_email("account/emails/password_reset_email.html", context)
    
    try:
        send_email(
            to=user.email,
            subject=context["subject"],
            body=plain,
            html=html,
            fail_silently=False,
        )
    except RateLimitExceeded as e:
        raise self.retry(exc=e, countdown=e.retry_after + 1)


@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=5)
def send_notification_email_task(self, notification_id: int):
    """
    Kirim email untuk notifikasi.
    Dipanggil saat membuat notifikasi dengan send_email=True.
    Rate-limited to prevent Mailgun API errors.
    """
    from django.utils import timezone
    from .models import Notification
    from .email_utils import render_email, COMPANY_NAME
    from .services.email_service import send_email
    from .services.rate_limiter import RateLimitExceeded

    notification = Notification.objects.filter(pk=notification_id).select_related("user").first()
    if not notification or not notification.user:
        return
    
    # Skip if already sent
    if notification.email_sent:
        return

    # Build email context
    context = {
        "user": notification.user,
        "title": notification.title,
        "message": notification.message,
        "action_url": notification.action_url,
        "action_label": notification.action_label or "Buka",
        "logo_url": "",
        "subject": f"{notification.title} – {COMPANY_NAME}",
        "body_text": f"{notification.message}\n\n{COMPANY_NAME}",
    }
    
    # Render email template (create a simple notification email template)
    html, plain = render_email("account/emails/notification_email.html", context)
    
    try:
        send_email(
            to=notification.user.email,
            subject=context["subject"],
            body=plain,
            html=html,
            fail_silently=False,
        )
        
        # Mark as sent
        notification.email_sent = True
        notification.email_sent_at = timezone.now()
        notification.save(update_fields=["email_sent", "email_sent_at"])
    except RateLimitExceeded as e:
        raise self.retry(exc=e, countdown=e.retry_after + 1)


@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=2)
def send_broadcast_task(self, broadcast_id: int):
    """
    Kirim broadcast notification ke semua penerima.
    Dipanggil saat admin membuat broadcast atau saat scheduled_at tiba.
    """
    from .models import Broadcast
    from .services.notification_delivery import send_broadcast

    broadcast = Broadcast.objects.filter(pk=broadcast_id).first()
    if not broadcast:
        return
    
    # Skip if already sent
    if broadcast.sent_at:
        return
    
    send_broadcast(broadcast)


@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=2)
def send_notification_push_task(self, notification_id: int):
    """
    Kirim push notification via FCM.
    Dipanggil saat membuat notifikasi dengan send_push=True.
    """
    from .models import Notification
    from .services.fcm_service import send_fcm_to_user

    notification = Notification.objects.filter(pk=notification_id).select_related("user").first()
    if not notification or not notification.user:
        return

    data = {
        "notification_id": str(notification.id),
        "action_url": notification.action_url or "",
        "action_label": notification.action_label or "",
    }
    priority = "high" if notification.priority in ["HIGH", "URGENT"] else "normal"

    send_fcm_to_user(
        user=notification.user,
        title=notification.title,
        body=notification.message,
        data=data,
        notification_type=notification.notification_type,
        priority=priority,
    )


# ---------------------------------------------------------------------------
# Event-driven email task (dispatched by notification_dispatcher.dispatch())
# ---------------------------------------------------------------------------

@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=5)
def send_event_email_task(
    self,
    user_id: int,
    event_value: str,
    context: dict,
    action_url: str = "",
):
    """
    Send a transactional email for a specific notification event.

    Uses per-event HTML templates when available, falls back to the generic
    notification_email.html template.
    Rate-limited to prevent Mailgun API errors.

    Template lookup order:
      1. account/emails/events/<event_snake>.html  (per-event template)
      2. account/emails/notification_email.html    (generic fallback)
    """
    import re
    from django.conf import settings
    from django.template.loader import get_template
    from django.template.exceptions import TemplateDoesNotExist

    from .models import CustomUser
    from .email_utils import render_email, COMPANY_NAME
    from .services.notification_events import NotificationEvent, render_event_message
    from .services.email_service import send_email
    from .services.rate_limiter import RateLimitExceeded

    user = CustomUser.objects.filter(pk=user_id, is_active=True).first()
    if not user or not user.email:
        return

    try:
        event = NotificationEvent(event_value)
    except ValueError:
        return

    title, message = render_event_message(event, context)
    frontend_url = getattr(settings, "FRONTEND_URL", "").rstrip("/")
    full_action_url = (frontend_url + action_url) if action_url and not action_url.startswith("http") else action_url

    # Build template context
    ctx = {
        "user": user,
        "title": title,
        "message": message,
        "action_url": full_action_url,
        "action_label": context.get("action_label", "Buka Aplikasi"),
        "logo_url": getattr(settings, "LOGO_URL", ""),
        "subject": f"{title} – {COMPANY_NAME}",
        "body_text": f"{message}\n\n{COMPANY_NAME}",
        **context,
    }

    # Per-event template slug: e.g. "account.password_changed" → "account_password_changed"
    event_slug = re.sub(r"[^a-z0-9]", "_", event.value.lower())
    per_event_template = f"account/emails/events/{event_slug}.html"
    fallback_template = "account/emails/notification_email.html"

    try:
        get_template(per_event_template)  # Raises if not found
        template_name = per_event_template
    except TemplateDoesNotExist:
        template_name = fallback_template

    html, plain = render_email(template_name, ctx)

    try:
        send_email(
            to=user.email,
            subject=ctx["subject"],
            body=plain,
            html=html,
            fail_silently=False,
        )
    except RateLimitExceeded as e:
        raise self.retry(exc=e, countdown=e.retry_after + 1)


# ---------------------------------------------------------------------------
# Scheduled: Admin daily digest
# ---------------------------------------------------------------------------

@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=5)
def send_admin_daily_digest(self):
    """
    Send a daily digest email to all Admin and Staff users summarising:
    - Number of applicant profiles pending verification
    - Number of new applicants registered today

    Scheduled via CELERY_BEAT_SCHEDULE (see backend/settings.py).
    Rate-limited to prevent Mailgun API errors.
    """
    from django.conf import settings
    from django.utils import timezone
    from django.db.utils import ProgrammingError

    from .models import CustomUser, UserRole, ApplicantProfile, ApplicantVerificationStatus
    from .email_utils import render_email, COMPANY_NAME
    from .services.email_service import send_email_bulk
    from .services.rate_limiter import RateLimitExceeded

    try:
        now = timezone.now()
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

        pending_profiles = ApplicantProfile.objects.filter(
            verification_status=ApplicantVerificationStatus.SUBMITTED
        ).count()
        new_today = ApplicantProfile.objects.filter(created_at__gte=today_start).count()

        if pending_profiles == 0 and new_today == 0:
            return  # Skip empty digest

        recipients = list(
            CustomUser.objects.filter(
                role__in=[UserRole.MASTER_ADMIN, UserRole.ADMIN, UserRole.STAFF],
                is_active=True,
            ).values_list("email", flat=True)
        )
        if not recipients:
            return

        ctx = {
            "pending_profiles": pending_profiles,
            "new_today": new_today,
            "date": now.strftime("%d %B %Y"),
            "logo_url": getattr(settings, "LOGO_URL", ""),
            "subject": f"Ringkasan Harian Admin – {COMPANY_NAME}",
            "body_text": (
                f"Ringkasan {now.strftime('%d %B %Y')}:\n"
                f"- {pending_profiles} profil menunggu verifikasi\n"
                f"- {new_today} pelamar baru hari ini\n\n{COMPANY_NAME}"
            ),
        }
        html, plain = render_email("account/emails/events/admin_daily_digest.html", ctx)

        try:
            send_email_bulk(
                recipients=recipients,
                subject=ctx["subject"],
                body=plain,
                html=html,
                fail_silently=False,
            )
        except RateLimitExceeded as e:
            raise self.retry(exc=e, countdown=e.retry_after + 1)

    except ProgrammingError as e:
        if "does not exist" in str(e):
            return  # Tables not created yet (fresh DB)
        raise


# ---------------------------------------------------------------------------
# Scheduled: Job deadline reminders
# ---------------------------------------------------------------------------

@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=2)
def send_job_deadline_reminders(self):
    """
    Notify verified applicants when a job they're eligible for has a
    deadline in exactly 3 days.

    Scheduled via CELERY_BEAT_SCHEDULE (daily at 9 AM WIB).
    """
    from django.utils import timezone
    from django.db.utils import ProgrammingError

    try:
        from datetime import timedelta
        from .models import ApplicantProfile, ApplicantVerificationStatus
        from .services.notification_dispatcher import dispatch
        from .services.notification_events import NotificationEvent

        now = timezone.now()
        target_date = (now + timedelta(days=3)).date()

        # Import here to avoid circular at module level
        from main.models import LowonganKerja, JobStatus  # type: ignore[import]

        jobs = LowonganKerja.objects.filter(
            status=JobStatus.OPEN,
            deadline__date=target_date,
        ).select_related("company")

        if not jobs.exists():
            return

        # Notify all ACCEPTED applicants
        applicants = (
            ApplicantProfile.objects.filter(
                verification_status=ApplicantVerificationStatus.ACCEPTED,
                user__is_active=True,
            )
            .select_related("user", "user__notification_preference")
        )

        for job in jobs:
            ctx = {
                "job_title": job.title,
                "company_name": getattr(job.company, "company_name", ""),
                "days_remaining": 3,
            }
            for profile in applicants:
                dispatch(
                    event=NotificationEvent.JOB_DEADLINE_APPROACHING,
                    user=profile.user,
                    context=ctx,
                    action_url=f"/lowongan/{job.pk}",
                    action_label="Lihat Lowongan",
                    deduplicate=True,
                )

    except ProgrammingError as e:
        if "does not exist" in str(e):
            return
        raise


# ---------------------------------------------------------------------------
# Scheduled: Batch departure reminders
# ---------------------------------------------------------------------------

@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=2)
def send_batch_departure_reminders(self):
    """
    Notify applicants in BERANGKAT-status batches:
    - 7 days before departure
    - 1 day before departure

    Scheduled via CELERY_BEAT_SCHEDULE (daily at 8 AM WIB).
    Departure date is derived from LamaranBatch.interview_date as a proxy
    (adjust to a dedicated departure_date field if/when added).
    """
    from django.utils import timezone
    from django.db.utils import ProgrammingError

    try:
        from datetime import timedelta
        from main.models import LamaranBatch, ApplicationStatus  # type: ignore[import]
        from .services.notification_dispatcher import dispatch
        from .services.notification_events import NotificationEvent

        now = timezone.now()

        for days, event in [
            (7, NotificationEvent.BATCH_DEPARTURE_UPCOMING_7D),
            (1, NotificationEvent.BATCH_DEPARTURE_UPCOMING_1D),
        ]:
            target_date = (now + timedelta(days=days)).date()

            batches = LamaranBatch.objects.filter(
                pra_seleksi_date__date=target_date,
            ).select_related("job", "job__company").prefetch_related(
                "applications__applicant__user",
                "applications__applicant__user__notification_preference",
            )

            for batch in batches:
                ctx = {
                    "batch_name": batch.name,
                    "job_title": batch.job.title,
                    "company_name": getattr(batch.job.company, "company_name", ""),
                    "days_remaining": days,
                }
                for application in batch.applications.filter(
                    status=ApplicationStatus.BERANGKAT
                ):
                    dispatch(
                        event=event,
                        user=application.applicant.user,
                        context=ctx,
                        action_url=f"/lamaran/{application.pk}",
                        action_label="Lihat Detail",
                        deduplicate=True,
                    )

    except ProgrammingError as e:
        if "does not exist" in str(e):
            return
        raise

