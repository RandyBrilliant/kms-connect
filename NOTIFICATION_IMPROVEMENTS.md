# Notification System - Required Improvements

## Executive Summary

Your notification system has a solid foundation but is **missing critical push notification functionality**. The backend cannot send push notifications to mobile devices, and the mobile app cannot receive in-app notifications from the backend.

**Recommendation: YES, use Firebase Cloud Messaging** - You already have it set up in the mobile app, just need backend integration.

---

## Critical Improvements Required

### 1. Backend: Add Firebase Admin SDK Integration

#### a) Install Firebase Admin SDK
```bash
cd backend
pip install firebase-admin
```

Add to `requirements.txt`:
```
firebase-admin==6.5.0
```

#### b) Add FCM Token Storage to User Model

**File: `backend/account/models.py`**

Add to `CustomUser` model:
```python
class CustomUser(AbstractBaseUser, PermissionsMixin):
    # ... existing fields ...
    
    # FCM (Firebase Cloud Messaging) tokens for push notifications
    fcm_tokens = models.JSONField(
        _("FCM tokens"),
        default=list,
        blank=True,
        help_text=_("Firebase Cloud Messaging device tokens (array)")
    )
```

Or create a separate DeviceToken model (better for multiple devices):
```python
class DeviceToken(models.Model):
    """FCM device tokens for push notifications."""
    
    user = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name="device_tokens",
        verbose_name=_("pengguna"),
    )
    token = models.CharField(
        _("FCM token"),
        max_length=255,
        unique=True,
    )
    device_type = models.CharField(
        _("tipe perangkat"),
        max_length=20,
        choices=[("android", "Android"), ("ios", "iOS"), ("web", "Web")],
        default="android",
    )
    is_active = models.BooleanField(
        _("aktif"),
        default=True,
    )
    created_at = models.DateTimeField(_("dibuat pada"), auto_now_add=True)
    last_used_at = models.DateTimeField(_("terakhir digunakan"), auto_now=True)

    class Meta:
        verbose_name = _("device token")
        verbose_name_plural = _("device tokens")
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "is_active"]),
            models.Index(fields=["token"]),
        ]

    def __str__(self) -> str:
        return f"{self.user.email} - {self.device_type} - {self.token[:20]}..."
```

#### c) Create FCM Utility Service

**File: `backend/account/services/fcm_service.py`**

```python
"""
Firebase Cloud Messaging service for push notifications.
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
                    logger.warning(f"Failed to send to token {tokens[idx]}: {resp.exception}")
        
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
) -> bool:
    """
    Send push notification to a single user (all their devices).
    
    Args:
        user: CustomUser instance
        title: Notification title
        body: Notification body
        data: Additional data payload
        notification_type: Type of notification
    
    Returns:
        True if sent to at least one device
    """
    # Option 1: If using fcm_tokens JSONField on user
    tokens = user.fcm_tokens if hasattr(user, 'fcm_tokens') else []
    
    # Option 2: If using DeviceToken model
    # from ..models import DeviceToken
    # tokens = list(
    #     DeviceToken.objects.filter(user=user, is_active=True)
    #     .values_list('token', flat=True)
    # )
    
    if not tokens:
        logger.info(f"No FCM tokens for user {user.email}")
        return False
    
    success_count, _ = send_fcm_notification(
        tokens=tokens,
        title=title,
        body=body,
        data=data,
        notification_type=notification_type,
    )
    
    return success_count > 0
```

#### d) Update Notification Delivery Service

**File: `backend/account/services/notification_delivery.py`**

Add push notification support:
```python
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
    send_push: bool = True,  # ADD THIS
) -> Notification:
    """
    Create a notification and optionally send email/push.
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
    
    # Send email async
    if send_email:
        from ..tasks import send_notification_email_task
        send_notification_email_task.delay(notification.id)
    
    # Send push notification async (ADD THIS)
    if send_push:
        from ..tasks import send_notification_push_task
        send_notification_push_task.delay(notification.id)
    
    return notification
```

#### e) Add FCM Push Task

**File: `backend/account/tasks.py`**

```python
@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=2)
def send_notification_push_task(self, notification_id: int):
    """
    Send push notification via FCM.
    Called when creating notification with send_push=True.
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
    
    # Send push notification
    sent = send_fcm_to_user(
        user=notification.user,
        title=notification.title,
        body=notification.message,
        data=data,
        notification_type=notification.notification_type,
    )
    
    if sent:
        # Optionally track push sent status
        notification.push_sent = True
        notification.push_sent_at = timezone.now()
        notification.save(update_fields=["push_sent", "push_sent_at"])
```

#### f) Add API Endpoints for FCM Tokens

**File: `backend/account/views.py`**

```python
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def register_fcm_token(request):
    """
    Register FCM token for current user.
    POST /api/fcm/register/
    Body: {"token": "...", "device_type": "android|ios|web"}
    """
    token = request.data.get("token")
    device_type = request.data.get("device_type", "android")
    
    if not token:
        return Response(
            {"error": "Token is required"},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Option 1: Using fcm_tokens JSONField
    user = request.user
    if not hasattr(user, 'fcm_tokens'):
        user.fcm_tokens = []
    if token not in user.fcm_tokens:
        user.fcm_tokens.append(token)
        user.save(update_fields=["fcm_tokens"])
    
    # Option 2: Using DeviceToken model (recommended)
    # from .models import DeviceToken
    # DeviceToken.objects.update_or_create(
    #     token=token,
    #     defaults={
    #         "user": request.user,
    #         "device_type": device_type,
    #         "is_active": True,
    #     }
    # )
    
    return Response({"message": "Token registered successfully"})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def unregister_fcm_token(request):
    """
    Unregister FCM token for current user.
    POST /api/fcm/unregister/
    Body: {"token": "..."}
    """
    token = request.data.get("token")
    
    if not token:
        return Response(
            {"error": "Token is required"},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Option 1: Using fcm_tokens JSONField
    user = request.user
    if hasattr(user, 'fcm_tokens') and token in user.fcm_tokens:
        user.fcm_tokens.remove(token)
        user.save(update_fields=["fcm_tokens"])
    
    # Option 2: Using DeviceToken model
    # from .models import DeviceToken
    # DeviceToken.objects.filter(user=request.user, token=token).update(is_active=False)
    
    return Response({"message": "Token unregistered successfully"})
```

**File: `backend/account/urls.py`**

Add to urlpatterns:
```python
urlpatterns = [
    # ... existing patterns ...
    
    # FCM token management
    path("fcm/register/", views.register_fcm_token, name="fcm-register"),
    path("fcm/unregister/", views.unregister_fcm_token, name="fcm-unregister"),
]
```

#### g) Add Firebase Configuration

**File: `backend/backend/settings.py`**

```python
# Firebase Cloud Messaging
FIREBASE_CREDENTIALS_PATH = os.path.join(BASE_DIR, "firebase-service-account.json")
```

**Create `.gitignore` entry:**
```
firebase-service-account.json
```

#### h) Update Broadcast Model

**File: `backend/account/models.py`**

Add `send_push` field to Broadcast:
```python
class Broadcast(models.Model):
    # ... existing fields ...
    
    send_push = models.BooleanField(
        _("kirim push notification"),
        default=True,
        help_text=_("Kirim notifikasi push ke perangkat mobile.")
    )
```

---

### 2. Mobile App: Integrate with Backend

#### a) Send FCM Token to Backend

**File: `mobile/lib/core/api/api_client.dart`**

Add method to register FCM token:
```dart
Future<void> registerFcmToken(String token) async {
  try {
    await _dio.post(
      '/api/fcm/register/',
      data: {
        'token': token,
        'device_type': Platform.isAndroid ? 'android' : 'ios',
      },
    );
  } catch (e) {
    print('Failed to register FCM token: $e');
  }
}

Future<void> unregisterFcmToken(String token) async {
  try {
    await _dio.post(
      '/api/fcm/unregister/',
      data: {'token': token},
    );
  } catch (e) {
    print('Failed to unregister FCM token: $e');
  }
}
```

#### b) Update Notification Service

**File: `mobile/lib/features/notifications/data/services/notification_service.dart`**

Update to send token to backend:
```dart
Future<void> initialize() async {
  // ... existing code ...
  
  // Get FCM token and send to backend
  final token = await _firebaseMessaging.getToken();
  if (token != null) {
    await _sendTokenToBackend(token);
  }
  
  // Listen for token refresh
  _firebaseMessaging.onTokenRefresh.listen((newToken) async {
    await _sendTokenToBackend(newToken);
  });
}

Future<void> _sendTokenToBackend(String token) async {
  try {
    final apiClient = ApiClient();
    await apiClient.registerFcmToken(token);
    print('FCM Token registered with backend: $token');
  } catch (e) {
    print('Failed to send FCM token to backend: $e');
  }
}
```

#### c) Create Notifications API Client

**File: `mobile/lib/features/notifications/data/api/notifications_api.dart`**

```dart
import 'package:dio/dio.dart';
import '../../../../core/api/api_client.dart';

class NotificationsApi {
  final ApiClient _apiClient;

  NotificationsApi(this._apiClient);

  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int pageSize = 20,
    bool? isRead,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (isRead != null) {
      params['is_read'] = isRead;
    }

    final response = await _apiClient.dio.get(
      '/api/notifications/',
      queryParameters: params,
    );
    return response.data;
  }

  Future<int> getUnreadCount() async {
    final response = await _apiClient.dio.get('/api/notifications/unread-count/');
    return response.data['count'];
  }

  Future<void> markAsRead(int notificationId) async {
    await _apiClient.dio.patch('/api/notifications/$notificationId/mark-read/');
  }

  Future<void> markAllAsRead() async {
    await _apiClient.dio.post('/api/notifications/mark-all-read/');
  }
}
```

#### d) Create Notification Models

**File: `mobile/lib/features/notifications/data/models/notification.dart`**

```dart
class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String notificationType;
  final String priority;
  final String? actionUrl;
  final String? actionLabel;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.priority,
    this.actionUrl,
    this.actionLabel,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      notificationType: json['notification_type'],
      priority: json['priority'],
      actionUrl: json['action_url'],
      actionLabel: json['action_label'],
      isRead: json['is_read'],
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
```

#### e) Create Notifications Screen

**File: `mobile/lib/features/notifications/presentation/screens/notifications_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/notifications_api.dart';
import '../../data/models/notification.dart';
import '../../../../core/api/api_client.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }
  
  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final api = NotificationsApi(ApiClient());
      final response = await api.getNotifications();
      setState(() {
        _notifications = (response['results'] as List)
            .map((json) => NotificationModel.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading notifications: $e');
    }
  }
  
  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;
    
    try {
      final api = NotificationsApi(ApiClient());
      await api.markAsRead(notification.id);
      await _loadNotifications(); // Reload
    } catch (e) {
      print('Error marking as read: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              final api = NotificationsApi(ApiClient());
              await api.markAllAsRead();
              await _loadNotifications();
            },
            tooltip: 'Tandai semua sebagai dibaca',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('Tidak ada notifikasi'))
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Card(
                        color: notification.isRead ? null : Colors.blue.shade50,
                        child: ListTile(
                          leading: _getIconForType(notification.notificationType),
                          title: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notification.message),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(notification.createdAt),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          onTap: () => _markAsRead(notification),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
  
  Icon _getIconForType(String type) {
    switch (type) {
      case 'SUCCESS':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'WARNING':
        return const Icon(Icons.warning, color: Colors.orange);
      case 'ERROR':
        return const Icon(Icons.error, color: Colors.red);
      default:
        return const Icon(Icons.info, color: Colors.blue);
    }
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays > 0) {
      return '${diff.inDays} hari yang lalu';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} jam yang lalu';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} menit yang lalu';
    } else {
      return 'Baru saja';
    }
  }
}
```

---

### 3. Frontend Web: Add Real-time Updates (Optional but Recommended)

#### Option A: Polling (Simple)

**File: `frontend/src/hooks/useNotifications.ts`**

```typescript
import { useEffect, useState } from "react"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import { getNotifications, getUnreadNotificationCount } from "@/api/notifications"

export function useNotifications() {
  const queryClient = useQueryClient()
  
  // Poll unread count every 30 seconds
  const { data: unreadData } = useQuery({
    queryKey: ["notifications", "unread-count"],
    queryFn: getUnreadNotificationCount,
    refetchInterval: 30000, // 30 seconds
  })
  
  return {
    unreadCount: unreadData?.count ?? 0,
  }
}
```

#### Option B: WebSocket (Better)

Install Django Channels:
```bash
pip install channels channels-redis
```

This requires more setup but provides real-time updates without polling.

---

## Implementation Priority

### Phase 1: Critical (Do First)
1. ✅ Add Firebase Admin SDK to backend
2. ✅ Add FCM token storage (DeviceToken model)
3. ✅ Create FCM service and push task
4. ✅ Add API endpoints for token registration
5. ✅ Update mobile app to send tokens to backend
6. ✅ Test push notifications end-to-end

### Phase 2: Important (Do Second)
1. ✅ Create notifications screen in mobile app
2. ✅ Integrate mobile app with backend API
3. ✅ Update broadcast creation to include push option
4. ✅ Test broadcast to mobile devices

### Phase 3: Nice to Have (Do Later)
1. Add web push notifications (service workers)
2. Add WebSocket for real-time updates
3. Add notification preferences (email/push/in-app per type)
4. Add notification analytics

---

## Testing Checklist

### Backend
- [ ] Can store FCM tokens
- [ ] Can send push notification to single user
- [ ] Can send broadcast push to multiple users
- [ ] Email notifications still work
- [ ] In-app notifications still work

### Mobile
- [ ] FCM token sent to backend on login
- [ ] Push notifications received when app in foreground
- [ ] Push notifications received when app in background
- [ ] Push notifications received when app is killed
- [ ] Notification tap opens correct screen
- [ ] Can fetch in-app notifications from API
- [ ] Can mark notifications as read

### Integration
- [ ] Admin creates broadcast → Mobile receives push
- [ ] Admin creates broadcast → Mobile sees in-app notification
- [ ] Admin creates broadcast → Users receive email
- [ ] Push notification data includes correct action URL

---

## Estimated Effort

- **Backend Integration**: 4-6 hours
- **Mobile Integration**: 3-4 hours
- **Testing**: 2-3 hours
- **Total**: 9-13 hours for a single developer

---

## Security Considerations

1. **Firebase Service Account**: Store `firebase-service-account.json` securely
   - Add to `.gitignore`
   - Use environment variables in production
   - Restrict file permissions

2. **Token Validation**: Validate FCM tokens before storing

3. **Rate Limiting**: Add rate limits to token registration endpoint

4. **User Privacy**: Users should only see their own notifications

---

## Cost Analysis

### Firebase Cloud Messaging
- **Free Tier**: Unlimited messages
- **Cost**: $0/month
- **Limits**: None for basic usage

### Alternative: OneSignal
- **Free Tier**: 10,000 subscribers
- **Cost**: $9/month for 10,000-30,000 subscribers
- **Pros**: Easier setup, nice dashboard
- **Cons**: Additional service dependency

**Recommendation**: Stick with Firebase - it's free, reliable, and you already have it set up.

---

## Future Enhancements

1. **Rich Notifications**
   - Images in push notifications
   - Action buttons
   - Custom sounds

2. **Notification Preferences**
   - Let users choose what notifications they receive
   - Email vs Push vs In-app preferences

3. **Notification Analytics**
   - Track open rates
   - Track click-through rates
   - A/B testing for messages

4. **Scheduled Notifications**
   - Send at optimal times based on user timezone
   - Recurring notifications

5. **Notification Grouping**
   - Group similar notifications
   - Summary notifications

---

## Common Issues & Solutions

### Issue: Push notifications not received
**Solutions:**
- Check FCM token is registered in backend
- Verify Firebase service account is valid
- Check network connectivity
- Verify notification permissions granted

### Issue: Notifications work in foreground but not background
**Solutions:**
- Verify background handler is registered (top-level function)
- Check Android notification channel configuration
- Verify data payload is correctly formatted

### Issue: Token registration fails
**Solutions:**
- Check authentication token is valid
- Verify API endpoint is correct
- Check network errors in logs

---

## Resources

- [Firebase Admin SDK Documentation](https://firebase.google.com/docs/admin/setup)
- [FCM HTTP v1 API](https://firebase.google.com/docs/cloud-messaging/http-server-ref)
- [Flutter Firebase Messaging](https://firebase.flutter.dev/docs/messaging/overview)
- [Django Background Tasks with Celery](https://docs.celeryproject.org/en/stable/django/)
