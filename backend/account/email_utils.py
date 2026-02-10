"""
Email verification & password reset: tokens, links, template rendering, and send.
Used by admin endpoints and public verify/confirm-reset.
"""
from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.tokens import default_token_generator
from django.core.signing import BadSignature, SignatureExpired, TimestampSigner
from django.template.loader import render_to_string
from django.utils import timezone
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode


User = get_user_model()
COMPANY_NAME = "PT. Karyatama Mitra Sejati"
SIGNER = TimestampSigner()
VERIFICATION_MAX_AGE_DAYS = getattr(
    settings, "EMAIL_VERIFICATION_MAX_AGE_DAYS", 7
)
FRONTEND_URL = (getattr(settings, "FRONTEND_URL", "") or "").rstrip("/")


# ---------------------------------------------------------------------------
# Verification (signed token)
# ---------------------------------------------------------------------------

def make_verification_token(user):
    """Signed token for email verification; expires after VERIFICATION_MAX_AGE_DAYS."""
    payload = f"verify:{user.pk}"
    return SIGNER.sign(payload)


def verification_link(user):
    """Token only; caller builds full URL (e.g. request.build_absolute_uri + ?token=)."""
    return make_verification_token(user)


def verify_email_token(token):
    """
    Validate token and return user if valid. Returns None if invalid/expired.
    """
    try:
        payload = SIGNER.unsign(
            token,
            max_age=VERIFICATION_MAX_AGE_DAYS * 24 * 60 * 60,
        )
    except (BadSignature, SignatureExpired):
        return None
    if not payload.startswith("verify:"):
        return None
    try:
        user_id = int(payload.split(":", 1)[1])
    except (ValueError, IndexError):
        return None
    return User.objects.filter(pk=user_id).first()


# ---------------------------------------------------------------------------
# Password reset (Django default token generator)
# ---------------------------------------------------------------------------

def make_password_reset_link(user, base_url=None):
    """URL for user to open reset-password page (frontend). uid + token for API confirm."""
    base = (base_url or FRONTEND_URL or "").rstrip("/")
    if not base:
        return ""
    uid = urlsafe_base64_encode(force_bytes(user.pk))
    token = default_token_generator.make_token(user)
    return f"{base}/reset-password?uid={uid}&token={token}"


def get_user_from_reset_uid_token(uidb64, token):
    """Validate uid + token and return user if valid; else None."""
    try:
        raw = urlsafe_base64_decode(uidb64)
        uid = force_str(raw) if isinstance(raw, bytes) else raw
        user = User.objects.get(pk=int(uid))
    except (TypeError, ValueError, OverflowError, User.DoesNotExist):
        return None
    if not default_token_generator.check_token(user, token):
        return None
    return user


# ---------------------------------------------------------------------------
# Templates & send
# ---------------------------------------------------------------------------

def render_email(template_name, context):
    """Render HTML and plain text from template; context should include company_name, logo_url."""
    ctx = {"company_name": COMPANY_NAME, "timezone_now": timezone.now()}
    ctx.update(context)
    html = render_to_string(template_name, ctx)
    plain_name = template_name.replace(".html", ".txt")
    try:
        plain = render_to_string(plain_name, ctx)
    except Exception:
        plain = (
            ctx.get("subject", "KMS-Connect")
            + "\n\n"
            + (ctx.get("body_text", "") or "Silakan buka email dalam format HTML.")
        )
    return html, plain


def send_verification_email(user, logo_url=None, verify_url=None):
    """
    Queue sending verification email.
    verify_url: full URL for verify link (build in view: request.build_absolute_uri(...)).
    logo_url: optional absolute URL for logo.
    """
    from .tasks import send_verification_email_task
    send_verification_email_task.delay(user.pk, logo_url or "", verify_url or "")


def send_password_reset_email(user, logo_url=None):
    """Queue sending password reset email."""
    from .tasks import send_password_reset_email_task
    send_password_reset_email_task.delay(user.pk, logo_url or "")
