"""
Notification delivery service.

Handles creating and sending notifications (in-app and email).
Uses Celery for async email delivery.
"""

from __future__ import annotations

from typing import Any
from django.utils import timezone

from ..models import CustomUser, Broadcast, Notification, NotificationType, NotificationPriority
from .notification_recipients import get_recipients_by_config


def create_notification(
    user: CustomUser,
    title: str,
    message: str,
    notification_type: str = NotificationType.INFO,
    priority: str = NotificationPriority.NORMAL,
    broadcast: Broadcast | None = None,
    action_url: str | None = None,
    action_label: str = "",
    send_email: bool = False,
) -> Notification:
    """
    Create a single notification for a user.
    
    Args:
        user: The recipient user
        title: Notification title
        message: Notification message
        notification_type: Type of notification
        priority: Priority level
        broadcast: Optional broadcast this notification belongs to
        action_url: Optional URL for action button
        action_label: Optional label for action button
        send_email: Whether to send email (will queue Celery task)
    
    Returns:
        Created Notification instance
    """
    notification = Notification.objects.create(
        user=user,
        broadcast=broadcast,
        title=title,
        message=message,
        notification_type=notification_type,
        priority=priority,
        action_url=action_url,
        action_label=action_label,
    )
    
    # Queue email delivery if requested
    if send_email:
        from ..tasks import send_notification_email_task
        send_notification_email_task.delay(notification.id)
    
    return notification


def send_broadcast(broadcast: Broadcast) -> int:
    """
    Send a broadcast notification to all configured recipients.
    
    Args:
        broadcast: Broadcast instance to send
    
    Returns:
        Number of recipients who received the notification
    """
    # Get recipients based on config
    recipients = get_recipients_by_config(broadcast.recipient_config)
    
    # Create notifications for each recipient
    notifications_created = []
    for user in recipients:
        notification = create_notification(
            user=user,
            title=broadcast.title,
            message=broadcast.message,
            notification_type=broadcast.notification_type,
            priority=broadcast.priority,
            broadcast=broadcast,
            send_email=broadcast.send_email,
        )
        notifications_created.append(notification)
    
    # Update broadcast metadata
    broadcast.total_recipients = len(notifications_created)
    broadcast.sent_at = timezone.now()
    broadcast.save(update_fields=["total_recipients", "sent_at"])
    
    return len(notifications_created)
