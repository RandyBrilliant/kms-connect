"""
Firebase Cloud Messaging service for push notifications.
Handles sending push notifications to web and mobile clients via FCM.
"""
from __future__ import annotations

import logging
from typing import Dict, List, Optional, Tuple

import firebase_admin
from firebase_admin import credentials, messaging
from firebase_admin.exceptions import InvalidArgumentError
from firebase_admin.messaging import UnregisteredError
from django.conf import settings

logger = logging.getLogger(__name__)

_STALE_TOKEN_EXCEPTIONS = (
    UnregisteredError,
    InvalidArgumentError,
)

# Initialize Firebase Admin SDK (do this once)
_firebase_initialized = False


def initialize_firebase() -> None:
    """Initialize Firebase Admin SDK exactly once per process."""
    global _firebase_initialized
    if _firebase_initialized:
        return

    try:
        firebase_admin.get_app()
        _firebase_initialized = True
        logger.info("Firebase Admin SDK already initialized")
        return
    except ValueError:
        pass

    try:
        cred_path: Optional[str] = getattr(settings, "FIREBASE_CREDENTIALS_PATH", None)
        if not cred_path:
            logger.warning("FIREBASE_CREDENTIALS_PATH not set in settings")
            return

        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        logger.info("Firebase Admin SDK initialized successfully")
    except Exception:
        logger.exception("Failed to initialize Firebase")


def _webpush_fcm_options() -> Optional[messaging.WebpushFCMOptions]:
    """
    FCM requires WebpushFCMOptions.link to be a full HTTPS URL (not a path like '/').

    When FRONTEND_URL is http:// (local dev) or unset, omit fcm_options so webpush
    still works for mobile tokens; web clients get no default click URL.
    """
    base = (getattr(settings, "FRONTEND_URL", None) or "").strip().rstrip("/")
    if not base.startswith("https://"):
        return None
    return messaging.WebpushFCMOptions(link=f"{base}/")


def _build_webpush_config(title: str, body: str) -> messaging.WebpushConfig:
    """Webpush notification; click link only when FRONTEND_URL is HTTPS."""
    notification = messaging.WebpushNotification(
        title=title,
        body=body,
        icon="/logo.png",
    )
    fcm_opts = _webpush_fcm_options()
    if fcm_opts is not None:
        return messaging.WebpushConfig(
            notification=notification,
            fcm_options=fcm_opts,
        )
    return messaging.WebpushConfig(notification=notification)


def _build_android_config(priority: str) -> messaging.AndroidConfig:
    """
    Build AndroidConfig using separate transport and notification priorities.
    """
    fcm_priority = "high" if priority == "high" else "normal"
    notif_priority = "high" if priority == "high" else "default"
    return messaging.AndroidConfig(
        priority=fcm_priority,
        notification=messaging.AndroidNotification(
            channel_id="kms_connect_channel",
            priority=notif_priority,
        ),
    )


def _build_apns_config(title: str, body: str, priority: str) -> messaging.APNSConfig:
    """
    Build APNSConfig for a visible iOS push banner.
    """
    return messaging.APNSConfig(
        headers={
            # For visible alerts, APNs expects priority 10.
            "apns-priority": "10",
            # Explicit push type avoids APNs misclassification on iOS 13+.
            "apns-push-type": "alert",
        },
        payload=messaging.APNSPayload(
            aps=messaging.Aps(
                # Explicit aps.alert is required for a visible iOS notification when
                # customizing aps. Do not set content_available here: it can cause APNs
                # to treat the push as background-only, so the banner may not show.
                alert=messaging.ApsAlert(
                    title=title,
                    body=body,
                ),
                sound="default",
                badge=1,
                # Safe if NSE is absent; enables richer payload handling if present.
                mutable_content=True,
            ),
        ),
    )


def _deactivate_stale_tokens(
    tokens: List[str],
    responses: List[messaging.SendResponse],
) -> None:
    """
    Deactivate tokens that are permanently invalid and should not be retried.
    """
    from account.models import DeviceToken

    stale_tokens: List[str] = []
    for token, resp in zip(tokens, responses):
        if resp.success:
            continue
        exc = resp.exception
        if isinstance(exc, _STALE_TOKEN_EXCEPTIONS):
            stale_tokens.append(token)
            logger.info("Deactivating stale FCM token %s... (%s)", token[:20], type(exc).__name__)
        else:
            logger.warning("Transient FCM send failure for %s...: %s", token[:20], exc)

    if stale_tokens:
        updated = DeviceToken.objects.filter(token__in=stale_tokens).update(is_active=False)
        logger.info("Deactivated %d stale FCM token(s)", updated)


def send_fcm_notification(
    tokens: List[str],
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
    notification_type: str = "INFO",
    priority: str = "high",
) -> Tuple[int, int]:
    """
    Send push notification to multiple FCM tokens.
    """
    initialize_firebase()
    if not _firebase_initialized:
        logger.error("Firebase not initialized - skipping FCM send")
        return 0, len(tokens)

    if not tokens:
        return 0, 0

    data_payload: Dict[str, str] = {
        "notification_type": notification_type,
        "priority": priority,
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
        **{str(k): str(v) for k, v in (data or {}).items()},
    }

    message = messaging.MulticastMessage(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data=data_payload,
        android=_build_android_config(priority),
        apns=_build_apns_config(title, body, priority),
        webpush=_build_webpush_config(title, body),
        tokens=tokens,
    )

    try:
        response = messaging.send_each_for_multicast(message)
        logger.info(
            "FCM sent: %d success, %d failures",
            response.success_count,
            response.failure_count,
        )

        if response.failure_count > 0:
            _deactivate_stale_tokens(tokens, response.responses)

        return response.success_count, response.failure_count
    except Exception:
        logger.exception("Failed to send FCM")
        return 0, len(tokens)


def send_fcm_to_user(
    user,
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
    notification_type: str = "INFO",
    priority: str = "normal",
) -> bool:
    """
    Send push notification to a single user (all their active devices).
    """
    from account.models import DeviceToken

    tokens: List[str] = list(
        DeviceToken.objects.filter(user=user, is_active=True)
        .values_list("token", flat=True)
    )

    if not tokens:
        logger.info("No FCM tokens for user %s", getattr(user, "email", user))
        return False

    success_count, _ = send_fcm_notification(
        tokens=tokens,
        title=title,
        body=body,
        data=data,
        notification_type=notification_type,
        priority=priority,
    )
    return success_count > 0


def _build_apns_silent_config() -> messaging.APNSConfig:
    """
    Build APNSConfig for an iOS silent/background push.
    """
    return messaging.APNSConfig(
        headers={
            "apns-priority": "5",
            "apns-push-type": "background",
        },
        payload=messaging.APNSPayload(
            aps=messaging.Aps(
                # Background wake-up (no alert/sound/badge).
                content_available=True,
            ),
        ),
    )


def _build_android_silent_config() -> messaging.AndroidConfig:
    """
    Build AndroidConfig for data-only silent push.
    """
    return messaging.AndroidConfig(
        # High priority helps prompt delivery for background sync.
        priority="high",
    )


def send_silent_fcm(
    tokens: List[str],
    data: Optional[Dict[str, str]] = None,
    sync_type: str = "DATA_SYNC",
) -> Tuple[int, int]:
    """
    Send a silent background push to one or more FCM tokens.
    """
    initialize_firebase()
    if not _firebase_initialized:
        logger.error("Firebase not initialized - skipping silent FCM send")
        return 0, len(tokens)

    if not tokens:
        return 0, 0

    merged_data: Dict[str, str] = {
        "sync_type": sync_type,
        **{str(k): str(v) for k, v in (data or {}).items()},
    }

    message = messaging.MulticastMessage(
        # No top-level notification keeps this data-only.
        data=merged_data,
        android=_build_android_silent_config(),
        apns=_build_apns_silent_config(),
        tokens=tokens,
    )

    try:
        response = messaging.send_each_for_multicast(message)
        logger.info(
            "Silent FCM sent: %d success, %d failures",
            response.success_count,
            response.failure_count,
        )

        if response.failure_count > 0:
            _deactivate_stale_tokens(tokens, response.responses)

        return response.success_count, response.failure_count
    except Exception:
        logger.exception("Failed to send silent FCM")
        return 0, len(tokens)


def send_silent_fcm_to_user(
    user,
    data: Optional[Dict[str, str]] = None,
    sync_type: str = "DATA_SYNC",
) -> bool:
    """
    Send silent background push to all active devices of a user.
    """
    from account.models import DeviceToken

    tokens: List[str] = list(
        DeviceToken.objects.filter(user=user, is_active=True)
        .values_list("token", flat=True)
    )

    if not tokens:
        logger.info(
            "No active FCM tokens for user %s (silent push skipped)",
            getattr(user, "email", user),
        )
        return False

    success_count, _ = send_silent_fcm(
        tokens=tokens,
        data=data,
        sync_type=sync_type,
    )
    return success_count > 0
