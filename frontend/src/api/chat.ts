/**
 * Chat API — threads + messages (admin side).
 * Backend: /api/chat/
 */

import { api } from "@/lib/api"
import type { PaginatedResponse } from "@/types/admin"
import type {
  ChatThread,
  ChatMessage,
  ChatThreadsListParams,
  SendMessageInput,
} from "@/types/chat"

function buildQueryString(params: ChatThreadsListParams): string {
  const search = new URLSearchParams()
  if (params.page != null) search.set("page", String(params.page))
  if (params.page_size != null) search.set("page_size", String(params.page_size))
  if (params.search) search.set("search", params.search)
  if (params.is_closed != null) search.set("is_closed", String(params.is_closed))
  if (params.ordering) search.set("ordering", params.ordering)
  if (params.application != null) search.set("application", String(params.application))
  const qs = search.toString()
  return qs ? `?${qs}` : ""
}

/** GET /api/chat/threads/ */
export async function getChatThreads(
  params: ChatThreadsListParams = {}
): Promise<PaginatedResponse<ChatThread>> {
  const { data } = await api.get<PaginatedResponse<ChatThread>>(
    `/api/chat/threads/${buildQueryString(params)}`
  )
  return data
}

/** GET /api/chat/threads/:id/ */
export async function getChatThread(id: number): Promise<ChatThread> {
  const { data } = await api.get<ChatThread>(`/api/chat/threads/${id}/`)
  return data
}

/**
 * GET /api/chat/threads/:id/messages/?since=<ISO>
 * since: fetch only messages after this timestamp (for polling)
 */
export async function getChatMessages(
  threadId: number,
  since?: string
): Promise<ChatMessage[]> {
  const qs = since ? `?since=${encodeURIComponent(since)}` : ""
  const { data } = await api.get<{ data: ChatMessage[] }>(
    `/api/chat/threads/${threadId}/messages/${qs}`
  )
  return data.data
}

/** POST /api/chat/threads/:id/send/ */
export async function sendChatMessage(
  threadId: number,
  input: SendMessageInput
): Promise<ChatMessage> {
  const { data } = await api.post<{ data: ChatMessage }>(
    `/api/chat/threads/${threadId}/send/`,
    input
  )
  return data.data
}

/** POST /api/chat/threads/:id/close/ */
export async function closeChatThread(threadId: number): Promise<ChatThread> {
  const { data } = await api.post<{ data: ChatThread }>(
    `/api/chat/threads/${threadId}/close/`
  )
  return data.data
}

/** POST /api/chat/threads/:id/reopen/ */
export async function reopenChatThread(threadId: number): Promise<ChatThread> {
  const { data } = await api.post<{ data: ChatThread }>(
    `/api/chat/threads/${threadId}/reopen/`
  )
  return data.data
}
