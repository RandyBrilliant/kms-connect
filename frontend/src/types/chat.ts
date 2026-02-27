/**
 * Chat types — matches backend chat.serializers (ChatThread, ChatMessage).
 */

export interface ChatMessage {
  id: number
  thread: number
  sender: number
  sender_name: string
  sender_role: string
  body: string
  sent_at: string
  is_read: boolean
  read_at: string | null
}

export interface ChatThreadLastMessage {
  body: string
  sent_at: string
  sender_name: string
}

export interface ChatThread {
  id: number
  application: number
  applicant_name: string
  job_title: string
  application_status: string
  is_closed: boolean
  unread_count: number
  last_message: ChatThreadLastMessage | null
  created_at: string
  updated_at: string
}

export interface ChatThreadsListParams {
  page?: number
  page_size?: number
  search?: string
  is_closed?: boolean
  ordering?: string
  /** Filter threads by application ID */
  application?: number
}

export interface SendMessageInput {
  body: string
}
