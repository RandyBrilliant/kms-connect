"""
Rate-limited email service for Mailgun.

This module provides a centralized email sending function that automatically
applies rate limiting to prevent Mailgun API rate limit errors.

Usage:
    from account.services.email_service import send_email

    send_email(
        to="user@example.com",
        subject="Hello",
        body="Plain text body",
        html="<h1>HTML body</h1>",
    )

Configuration (in settings.py):
    EMAIL_RATE_LIMIT = 60       # Max emails per window (default: 60)
    EMAIL_RATE_LIMIT_WINDOW = 60  # Window in seconds (default: 60)
"""

import logging
from typing import Optional

from django.conf import settings
from django.core.mail import send_mail as django_send_mail

from .rate_limiter import RateLimitExceeded, get_limiter

logger = logging.getLogger(__name__)

# Default rate limit settings
DEFAULT_RATE_LIMIT = 60  # emails per window
DEFAULT_RATE_LIMIT_WINDOW = 60  # seconds


def get_email_rate_limit() -> int:
    """Get configured email rate limit."""
    return getattr(settings, "EMAIL_RATE_LIMIT", DEFAULT_RATE_LIMIT)


def get_email_rate_limit_window() -> int:
    """Get configured email rate limit window in seconds."""
    return getattr(settings, "EMAIL_RATE_LIMIT_WINDOW", DEFAULT_RATE_LIMIT_WINDOW)


def send_email(
    to: str | list[str],
    subject: str,
    body: str,
    html: Optional[str] = None,
    from_email: Optional[str] = None,
    fail_silently: bool = False,
    bypass_rate_limit: bool = False,
) -> bool:
    """
    Send an email with automatic rate limiting.

    This is the recommended way to send emails in the application. It ensures
    that Mailgun API rate limits are respected across all Celery workers.

    Args:
        to: Recipient email address(es)
        subject: Email subject
        body: Plain text body
        html: Optional HTML body
        from_email: Sender email (defaults to settings.DEFAULT_FROM_EMAIL)
        fail_silently: If True, suppress exceptions (default: False)
        bypass_rate_limit: If True, skip rate limiting (use sparingly!)

    Returns:
        True if email was sent successfully

    Raises:
        RateLimitExceeded: When rate limit is hit (will trigger Celery retry)
        Exception: Other email sending errors (if fail_silently=False)
    """
    # Normalize recipient list
    if isinstance(to, str):
        recipient_list = [to]
    else:
        recipient_list = list(to)

    # Get rate limit settings
    rate_limit = get_email_rate_limit()
    rate_window = get_email_rate_limit_window()

    # Apply rate limiting (unless bypassed)
    if not bypass_rate_limit:
        limiter = get_limiter("mailgun", limit=rate_limit, period=rate_window)

        if not limiter.acquire(block=False):
            status = limiter.get_status()
            logger.warning(
                f"Email rate limit hit: {status['current_count']}/{status['limit']} emails sent. "
                f"Retry after {status['reset_in']:.1f}s. Recipients: {recipient_list}"
            )
            raise RateLimitExceeded("mailgun", retry_after=status["reset_in"])

    # Send the email
    try:
        django_send_mail(
            subject=subject,
            message=body,
            from_email=from_email or settings.DEFAULT_FROM_EMAIL,
            recipient_list=recipient_list,
            html_message=html,
            fail_silently=fail_silently,
        )
        logger.debug(f"Email sent to {recipient_list}: {subject}")
        return True

    except Exception as e:
        logger.error(f"Failed to send email to {recipient_list}: {e}")
        if not fail_silently:
            raise
        return False


def send_email_bulk(
    recipients: list[str],
    subject: str,
    body: str,
    html: Optional[str] = None,
    from_email: Optional[str] = None,
    fail_silently: bool = False,
) -> bool:
    """
    Send a bulk email to multiple recipients (single API call).

    This sends one email with all recipients in the "To" field. Use this for
    emails where recipients don't need personalization (e.g., admin digest).

    For personalized bulk emails, use send_email() in a loop with Celery tasks.

    Args:
        recipients: List of recipient email addresses
        subject: Email subject
        body: Plain text body
        html: Optional HTML body
        from_email: Sender email
        fail_silently: If True, suppress exceptions

    Returns:
        True if email was sent successfully
    """
    if not recipients:
        logger.warning("send_email_bulk called with empty recipients list")
        return False

    # For bulk emails, we still apply rate limiting (counts as 1 API call)
    return send_email(
        to=recipients,
        subject=subject,
        body=body,
        html=html,
        from_email=from_email,
        fail_silently=fail_silently,
    )


def get_rate_limit_status() -> dict:
    """
    Get current rate limit status for monitoring.

    Returns:
        dict with keys: limit, current_count, remaining, reset_in
    """
    rate_limit = get_email_rate_limit()
    rate_window = get_email_rate_limit_window()
    limiter = get_limiter("mailgun", limit=rate_limit, period=rate_window)
    return limiter.get_status()
