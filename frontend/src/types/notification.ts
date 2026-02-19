/**
 * Notification types - matches backend NotificationSerializer and BroadcastSerializer.
 */

export type NotificationType = "INFO" | "SUCCESS" | "WARNING" | "ERROR" | "BROADCAST"

export type NotificationPriority = "LOW" | "NORMAL" | "HIGH" | "URGENT"

export interface Notification {
  id: number
  title: string
  message: string
  notification_type: NotificationType
  priority: NotificationPriority
  action_url?: string | null
  action_label?: string
  is_read: boolean
  read_at?: string | null
  created_at: string
}

export type RecipientSelectionType = "all" | "roles" | "filters" | "users"

export interface RecipientConfig {
  selection_type: RecipientSelectionType
  roles?: string[] // UserRole[]
  user_ids?: number[]
  filters?: {
    role?: string
    is_active?: boolean
    email_verified?: boolean
    applicant_profile__verification_status?: string
    applicant_profile__created_at_after?: string
    applicant_profile__created_at_before?: string
  }
}

export interface Broadcast {
  id: number
  title: string
  message: string
  notification_type: NotificationType
  priority: NotificationPriority
  recipient_config: RecipientConfig
  send_email: boolean
  send_in_app: boolean
  created_by?: number | null
  created_by_name?: string
  scheduled_at?: string | null
  sent_at?: string | null
  total_recipients: number
  recipient_count?: number // Preview count
  created_at: string
  updated_at: string
}

export interface BroadcastCreateInput {
  title: string
  message: string
  notification_type: NotificationType
  priority: NotificationPriority
  recipient_config: RecipientConfig
  send_email: boolean
  send_in_app: boolean
  scheduled_at?: string | null
}

export interface BroadcastUpdateInput extends Partial<BroadcastCreateInput> {}

export interface NotificationsListParams {
  page?: number
  page_size?: number
  is_read?: boolean
  notification_type?: NotificationType
  priority?: NotificationPriority
  ordering?: string
}

export interface BroadcastsListParams {
  page?: number
  page_size?: number
  notification_type?: NotificationType
  priority?: NotificationPriority
  created_by?: number
  ordering?: string
}

export interface PaginatedResponse<T> {
  count: number
  next: string | null
  previous: string | null
  results: T[]
}
