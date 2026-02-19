/**
 * Notifications API - CRUD for notifications and broadcasts.
 * Backend: /api/notifications/, /api/broadcasts/
 */

import { api } from "@/lib/api"
import type {
  Notification,
  Broadcast,
  BroadcastCreateInput,
  BroadcastUpdateInput,
  NotificationsListParams,
  BroadcastsListParams,
  PaginatedResponse,
  RecipientConfig,
} from "@/types/notification"

function buildNotificationsQueryString(params: NotificationsListParams): string {
  const search = new URLSearchParams()
  if (params.page != null) search.set("page", String(params.page))
  if (params.page_size != null) search.set("page_size", String(params.page_size))
  if (params.is_read != null) search.set("is_read", String(params.is_read))
  if (params.notification_type) search.set("notification_type", params.notification_type)
  if (params.priority) search.set("priority", params.priority)
  if (params.ordering) search.set("ordering", params.ordering)
  const qs = search.toString()
  return qs ? `?${qs}` : ""
}

function buildBroadcastsQueryString(params: BroadcastsListParams): string {
  const search = new URLSearchParams()
  if (params.page != null) search.set("page", String(params.page))
  if (params.page_size != null) search.set("page_size", String(params.page_size))
  if (params.notification_type) search.set("notification_type", params.notification_type)
  if (params.priority) search.set("priority", params.priority)
  if (params.created_by != null) search.set("created_by", String(params.created_by))
  if (params.ordering) search.set("ordering", params.ordering)
  const qs = search.toString()
  return qs ? `?${qs}` : ""
}

// ---------------------------------------------------------------------------
// Notifications (User's own notifications)
// ---------------------------------------------------------------------------

/** GET /api/notifications/ - List user's notifications */
export async function getNotifications(
  params: NotificationsListParams = {}
): Promise<PaginatedResponse<Notification>> {
  const { data } = await api.get<PaginatedResponse<Notification>>(
    `/api/notifications/${buildNotificationsQueryString(params)}`
  )
  return data
}

/** GET /api/notifications/:id/ - Retrieve single notification */
export async function getNotification(id: number): Promise<Notification> {
  const { data } = await api.get<Notification>(`/api/notifications/${id}/`)
  return data
}

/** PATCH /api/notifications/:id/mark-read/ - Mark notification as read */
export async function markNotificationRead(id: number): Promise<Notification> {
  const { data } = await api.patch<Notification>(`/api/notifications/${id}/mark-read/`)
  return data
}

/** POST /api/notifications/mark-all-read/ - Mark all notifications as read */
export async function markAllNotificationsRead(): Promise<{ updated_count: number }> {
  const { data } = await api.post<{ updated_count: number }>(
    `/api/notifications/mark-all-read/`
  )
  return data
}

/** GET /api/notifications/unread-count/ - Get unread notification count */
export async function getUnreadNotificationCount(): Promise<{ count: number }> {
  const { data } = await api.get<{ count: number }>(`/api/notifications/unread-count/`)
  return data
}

// ---------------------------------------------------------------------------
// Broadcasts (Admin only)
// ---------------------------------------------------------------------------

/** GET /api/broadcasts/ - List broadcasts */
export async function getBroadcasts(
  params: BroadcastsListParams = {}
): Promise<PaginatedResponse<Broadcast>> {
  const { data } = await api.get<PaginatedResponse<Broadcast>>(
    `/api/broadcasts/${buildBroadcastsQueryString(params)}`
  )
  return data
}

/** GET /api/broadcasts/:id/ - Retrieve single broadcast */
export async function getBroadcast(id: number): Promise<Broadcast> {
  const { data } = await api.get<Broadcast>(`/api/broadcasts/${id}/`)
  return data
}

/** POST /api/broadcasts/ - Create broadcast */
export async function createBroadcast(input: BroadcastCreateInput): Promise<Broadcast> {
  const { data } = await api.post<Broadcast>(`/api/broadcasts/`, input)
  return data
}

/** PUT /api/broadcasts/:id/ - Update broadcast (before sending) */
export async function updateBroadcast(
  id: number,
  input: BroadcastUpdateInput
): Promise<Broadcast> {
  const { data } = await api.put<Broadcast>(`/api/broadcasts/${id}/`, input)
  return data
}

/** PATCH /api/broadcasts/:id/ - Partial update broadcast */
export async function patchBroadcast(
  id: number,
  input: Partial<BroadcastUpdateInput>
): Promise<Broadcast> {
  const { data } = await api.patch<Broadcast>(`/api/broadcasts/${id}/`, input)
  return data
}

/** POST /api/broadcasts/:id/send/ - Send broadcast immediately */
export async function sendBroadcast(id: number): Promise<Broadcast> {
  const { data } = await api.post<Broadcast>(`/api/broadcasts/${id}/send/`)
  return data
}

/** POST /api/broadcasts/preview-recipients/ - Preview recipient count */
export async function previewRecipients(
  recipientConfig: RecipientConfig
): Promise<{ recipient_count: number }> {
  const { data } = await api.post<{ recipient_count: number }>(
    `/api/broadcasts/preview-recipients/`,
    { recipient_config: recipientConfig }
  )
  return data
}
