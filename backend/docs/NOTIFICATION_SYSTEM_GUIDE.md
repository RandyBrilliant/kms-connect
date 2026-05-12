# Notification System Implementation Guide

## Overview

A comprehensive notification system has been implemented that allows admins to create and broadcast notifications to selected recipients. The system supports:

- **In-app notifications** (stored in database, shown in UI)
- **Email notifications** (via Celery async tasks)
- **Flexible recipient selection** (by role, filters, or specific users)
- **Scheduled broadcasts** (send now or schedule for later)

## Architecture

### Backend

#### Models (`backend/account/models.py`)
- **Broadcast**: Admin-created broadcast configuration
  - Stores title, message, notification type, priority
  - Recipient selection config (JSON field)
  - Delivery options (email, in-app)
  - Scheduling support
- **Notification**: Individual notification sent to users
  - Links to Broadcast (if part of broadcast)
  - Read/unread status
  - Email delivery tracking

#### Services (`backend/account/services/`)
- **notification_recipients.py**: Recipient selection logic
  - `get_recipients_by_config()`: Get users based on config
  - `get_recipient_count()`: Preview count before sending
  - `validate_recipient_config()`: Validate configuration
- **notification_delivery.py**: Notification creation and sending
  - `create_notification()`: Create single notification
  - `send_broadcast()`: Send broadcast to all recipients

#### Tasks (`backend/account/tasks.py`)
- `send_notification_email_task`: Async email delivery for notifications
- `send_broadcast_task`: Async broadcast sending (supports scheduling)

#### API Endpoints (`backend/account/views.py`, `urls.py`)
- **Notifications** (`/api/notifications/`):
  - `GET /api/notifications/` - List user's notifications
  - `GET /api/notifications/:id/` - Get notification details
  - `PATCH /api/notifications/:id/mark-read/` - Mark as read
  - `POST /api/notifications/mark-all-read/` - Mark all as read
  - `GET /api/notifications/unread-count/` - Get unread count

- **Broadcasts** (`/api/broadcasts/`) - Admin only:
  - `GET /api/broadcasts/` - List broadcasts
  - `POST /api/broadcasts/` - Create broadcast
  - `GET /api/broadcasts/:id/` - Get broadcast details
  - `PUT/PATCH /api/broadcasts/:id/` - Update broadcast (before sending)
  - `POST /api/broadcasts/:id/send/` - Send broadcast immediately
  - `POST /api/broadcasts/preview-recipients/` - Preview recipient count

### Frontend

#### Types (`frontend/src/types/notification.ts`)
- `Notification`, `Broadcast`, `RecipientConfig`
- `NotificationType`, `NotificationPriority`
- `BroadcastCreateInput`, `BroadcastUpdateInput`

#### API (`frontend/src/api/notifications.ts`)
- All CRUD operations for notifications and broadcasts
- Preview recipient count function

## Recipient Selection

The system supports flexible recipient selection via `recipient_config`:

```typescript
{
  selection_type: "all" | "roles" | "filters" | "users",
  
  // If selection_type === "roles"
  roles: ["ADMIN", "STAFF", "APPLICANT", "COMPANY"],
  
  // If selection_type === "users"
  user_ids: [1, 2, 3],
  
  // If selection_type === "filters"
  filters: {
    role: "APPLICANT",
    is_active: true,
    email_verified: true,
    applicant_profile__verification_status: "ACCEPTED",
    applicant_profile__created_at_after: "2024-01-01",
    applicant_profile__created_at_before: "2024-12-31"
  }
}
```

## Usage Examples

### 1. Create and Send Broadcast (Admin)

```typescript
import { createBroadcast, sendBroadcast } from "@/api/notifications"

// Create broadcast
const broadcast = await createBroadcast({
  title: "Pengumuman Penting",
  message: "Ada lowongan baru yang tersedia...",
  notification_type: "INFO",
  priority: "HIGH",
  recipient_config: {
    selection_type: "roles",
    roles: ["APPLICANT"]
  },
  send_email: true,
  send_in_app: true,
  scheduled_at: null // Send immediately
})

// Send it
await sendBroadcast(broadcast.id)
```

### 2. Preview Recipient Count

```typescript
import { previewRecipients } from "@/api/notifications"

const { recipient_count } = await previewRecipients({
  selection_type: "filters",
  filters: {
    role: "APPLICANT",
    applicant_profile__verification_status: "ACCEPTED"
  }
})

console.log(`Will send to ${recipient_count} recipients`)
```

### 3. Get User Notifications

```typescript
import { getNotifications, markNotificationRead } from "@/api/notifications"

// List notifications
const { results } = await getNotifications({
  is_read: false,
  page: 1,
  page_size: 20
})

// Mark as read
await markNotificationRead(notification.id)
```

## Next Steps

### 1. Create Migration
```bash
cd backend
python manage.py makemigrations account
python manage.py migrate
```

### 2. Create Email Template
Create `backend/account/templates/account/emails/notification_email.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>{{ title }}</title>
</head>
<body>
    <h1>{{ title }}</h1>
    <p>{{ message }}</p>
    {% if action_url %}
    <p><a href="{{ action_url }}">{{ action_label }}</a></p>
    {% endif %}
    <p>-- {{ COMPANY_NAME }}</p>
</body>
</html>
```

### 3. Create Broadcast Form Component
- Form with fields: title, message, type, priority
- Recipient selection UI (radio: all/roles/filters/users)
- Preview recipient count button
- Schedule option (date/time picker)
- Delivery options (email/in-app checkboxes)

### 4. Update SiteHeader
- Replace hardcoded `NOTIFICATIONS` array
- Fetch real notifications from API
- Show unread count badge
- Display notifications in dropdown
- Mark as read on click

### 5. Create Broadcast List Page
- Admin page to view all broadcasts
- Show status (sent/pending)
- Actions: view, edit (if not sent), resend

### 6. Add Real-time Updates (Optional)
- WebSocket or polling for new notifications
- Update unread count in real-time
- Show toast when new notification arrives

## Database Schema

### Broadcast
- `id`, `title`, `message`
- `notification_type`, `priority`
- `recipient_config` (JSON)
- `send_email`, `send_in_app`
- `created_by`, `scheduled_at`, `sent_at`
- `total_recipients`
- `created_at`, `updated_at`

### Notification
- `id`, `user` (FK), `broadcast` (FK, nullable)
- `title`, `message`
- `notification_type`, `priority`
- `action_url`, `action_label`
- `is_read`, `read_at`
- `email_sent`, `email_sent_at`
- `created_at`

## Security Considerations

- Only admins/staff can create broadcasts (`IsBackofficeAdmin` permission)
- Users can only see their own notifications
- Recipient config is validated before sending
- Email sending is async (Celery) to avoid blocking

## Performance

- Notifications are paginated (default page_size)
- Indexes on `user`, `is_read`, `created_at` for fast queries
- Celery tasks for async email delivery
- Preview count uses `count()` without fetching all objects
