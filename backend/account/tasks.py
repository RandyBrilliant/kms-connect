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
    Panggil setelah upload: process_document_ocr.delay(doc.pk)
    """
    from django.conf import settings
    from django.utils import timezone

    from .models import ApplicantDocument
    from .ocr import parse_ktp_text

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
        doc.ocr_data = parse_ktp_text(full_text)
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


@shared_task
def send_email_async(to_email: str, subject: str, body: str, html_message: str = None):
    """
    Kirim email di background via Django (Mailgun API bila MAILGUN_API_KEY diset).
    """
    from django.core.mail import send_mail
    from django.conf import settings

    send_mail(
        subject=subject,
        message=body,
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[to_email],
        html_message=html_message,
        fail_silently=False,
    )


@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=2)
def send_verification_email_task(self, user_id: int, logo_url: str = "", verify_url: str = ""):
    """
    Kirim email verifikasi ke user. Dipanggil oleh admin (send-verification-email).
    verify_url: URL lengkap untuk link verifikasi (dibangun di view).
    """
    from django.conf import settings
    from .models import CustomUser
    from .email_utils import render_email, COMPANY_NAME

    user = CustomUser.objects.filter(pk=user_id).first()
    if not user or not verify_url:
        return

    context = {
        "user": user,
        "verify_url": verify_url,
        "logo_url": logo_url or "",
        "subject": "Verifikasi Email – " + COMPANY_NAME,
        "body_text": f"Halo,\n\nSilakan verifikasi email Anda dengan mengklik tautan berikut:\n{verify_url}\n\nSalam,\n{COMPANY_NAME}",
    }
    html, plain = render_email("account/emails/verification_email.html", context)
    from django.core.mail import send_mail
    send_mail(
        subject=context["subject"],
        message=plain,
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[user.email],
        html_message=html,
        fail_silently=False,
    )


@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=2)
def send_password_reset_email_task(self, user_id: int, logo_url: str = ""):
    """
    Kirim email reset password ke user. Dipanggil oleh admin (send-password-reset).
    """
    from django.conf import settings
    from .models import CustomUser
    from .email_utils import render_email, make_password_reset_link, COMPANY_NAME

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
    from django.core.mail import send_mail
    send_mail(
        subject=context["subject"],
        message=plain,
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[user.email],
        html_message=html,
        fail_silently=False,
    )


@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=2)
def send_notification_email_task(self, notification_id: int):
    """
    Kirim email untuk notifikasi.
    Dipanggil saat membuat notifikasi dengan send_email=True.
    """
    from django.conf import settings
    from django.utils import timezone
    from .models import Notification
    from .email_utils import render_email, COMPANY_NAME

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
    
    from django.core.mail import send_mail
    send_mail(
        subject=context["subject"],
        message=plain,
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[notification.user.email],
        html_message=html,
        fail_silently=False,
    )
    
    # Mark as sent
    notification.email_sent = True
    notification.email_sent_at = timezone.now()
    notification.save(update_fields=["email_sent", "email_sent_at"])


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
    
    # Prepare data payload
    data = {
        "notification_id": str(notification.id),
        "action_url": notification.action_url or "",
        "action_label": notification.action_label or "",
    }
    
    # Determine priority
    priority = "high" if notification.priority in ["HIGH", "URGENT"] else "normal"
    
    # Send push notification
    sent = send_fcm_to_user(
        user=notification.user,
        title=notification.title,
        body=notification.message,
        data=data,
        notification_type=notification.notification_type,
        priority=priority,
    )
    
    if sent:
        # Optionally track push sent status (you can add these fields to Notification model)
        # notification.push_sent = True
        # notification.push_sent_at = timezone.now()
        # notification.save(update_fields=["push_sent", "push_sent_at"])
        pass

