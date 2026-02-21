"""
Firebase Cloud Messaging service for push notifications.
Handles sending push notifications to web and mobile clients via FCM.
"""
from __future__ import annotations

import logging
from typing import List, Dict, Any

import firebase_admin
from firebase_admin import credentials, messaging
from django.conf import settings

logger = logging.getLogger(__name__)

# Initialize Firebase Admin SDK (do this once)
_firebase_initialized = False


def initialize_firebase():
    """Initialize Firebase Admin SDK."""
    global _firebase_initialized
    if _firebase_initialized:
        return
    
    try:
        # Check if already initialized
        firebase_admin.get_app()
        _firebase_initialized = True
        logger.info("Firebase Admin SDK already initialized")
        return
    except ValueError:
        # Not initialized yet, proceed with initialization
        pass
    
    try:
        # Path to your Firebase service account JSON
        cred_path = getattr(settings, 'FIREBASE_CREDENTIALS_PATH', None)
        if not cred_path:
            logger.warning("FIREBASE_CREDENTIALS_PATH not set in settings")
            return
        
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        logger.info("Firebase Admin SDK initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize Firebase: {e}")


def send_fcm_notification(
    tokens: List[str],
    title: str,
    body: str,
    data: Dict[str, str] | None = None,
    notification_type: str = "INFO",
    priority: str = "high",
) -> tuple[int, int]:
    """
    Send push notification to multiple FCM tokens.
    
    Args:
        tokens: List of FCM device tokens
        title: Notification title
        body: Notification body/message
        data: Additional data payload (optional)
        notification_type: Type of notification (INFO, SUCCESS, WARNING, ERROR)
        priority: high or normal
    
    Returns:
        Tuple of (success_count, failure_count)
    """
    initialize_firebase()
    
    if not tokens:
        return 0, 0
    
    # Prepare data payload
    data_payload = data or {}
    data_payload.update({
        "notification_type": notification_type,
        "priority": priority,
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
    })
    
    # Create FCM message
    message = messaging.MulticastMessage(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data=data_payload,
        android=messaging.AndroidConfig(
            priority=priority,
            notification=messaging.AndroidNotification(
                channel_id="kms_connect_channel",
                priority="high" if priority == "high" else "default",
            ),
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    sound="default",
                    badge=1,
                ),
            ),
        ),
        webpush=messaging.WebpushConfig(
            notification=messaging.WebpushNotification(
                title=title,
                body=body,
                icon="/logo.png",  # Update with your logo path
            ),
            fcm_options=messaging.WebpushFCMOptions(
                link="/",  # Default link when notification is clicked
            ),
        ),
        tokens=tokens,
    )
    
    try:
        response = messaging.send_multicast(message)
        logger.info(
            f"FCM sent: {response.success_count} success, {response.failure_count} failures"
        )
        
        # Log failures for debugging
        if response.failure_count > 0:
            for idx, resp in enumerate(response.responses):
                if not resp.success:
                    logger.warning(f"Failed to send to token {tokens[idx][:20]}...: {resp.exception}")
        
        return response.success_count, response.failure_count
    
    except Exception as e:
        logger.error(f"Failed to send FCM: {e}")
        return 0, len(tokens)


def send_fcm_to_user(
    user,
    title: str,
    body: str,
    data: Dict[str, str] | None = None,
    notification_type: str = "INFO",
    priority: str = "normal",
) -> bool:
    """
    Send push notification to a single user (all their active devices).
    
    Args:
        user: CustomUser instance
        title: Notification title
        body: Notification body
        data: Additional data payload
        notification_type: Type of notification
        priority: high or normal
    
    Returns:
        True if sent to at least one device
    """
    from account.models import DeviceToken
    
    # Get active tokens for user
    tokens = list(
        DeviceToken.objects.filter(user=user, is_active=True)
        .values_list('token', flat=True)
    )
    
    if not tokens:
        logger.info(f"No FCM tokens for user {user.email}")
        return False
    
    success_count, failure_count = send_fcm_notification(
        tokens=tokens,
        title=title,
        body=body,
        data=data,
        notification_type=notification_type,
        priority=priority,
    )
    
    # Deactivate failed tokens (optional - only for specific errors)
    # You might want to check the error codes and only deactivate on specific errors
    # like INVALID_TOKEN, UNREGISTERED, etc.
    
    return success_count > 0
