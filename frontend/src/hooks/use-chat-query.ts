/**
 * TanStack Query hooks for chat (admin side).
 * Messages use a 30-second polling fallback when WebSocket is connected.
 * WebSocket (use-chat-websocket.ts) handles real-time invalidation.
 */

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"

import {
  getChatThreads,
  getChatThread,
  getChatMessages,
  sendChatMessage,
  closeChatThread,
  reopenChatThread,
} from "@/api/chat"
import type { ChatThreadsListParams, SendMessageInput } from "@/types/chat"

// Fallback polling interval — WebSocket handles instant updates;
// this is a safety net for missed events.
const POLL_INTERVAL_MS = 30_000

export const chatKeys = {
  all: ["chat"] as const,
  threads: () => [...chatKeys.all, "threads"] as const,
  threadList: (params: ChatThreadsListParams) =>
    [...chatKeys.threads(), params] as const,
  thread: (id: number) => [...chatKeys.threads(), id] as const,
  messages: (threadId: number) =>
    [...chatKeys.all, "messages", threadId] as const,
}

export function useChatThreadsQuery(params: ChatThreadsListParams = {}) {
  return useQuery({
    queryKey: chatKeys.threadList(params),
    queryFn: () => getChatThreads(params),
  })
}

export function useChatThreadQuery(id: number | null, enabled = true) {
  return useQuery({
    queryKey: chatKeys.thread(id ?? 0),
    queryFn: () => getChatThread(id!),
    enabled: enabled && id != null && id > 0,
  })
}

/**
 * Messages query with polling fallback.
 * WebSocket provides instant updates; this refetches every 30s as safety net.
 */
export function useChatMessagesQuery(threadId: number | null, enabled = true) {
  return useQuery({
    queryKey: chatKeys.messages(threadId ?? 0),
    queryFn: () => getChatMessages(threadId!),
    enabled: enabled && threadId != null && threadId > 0,
    refetchInterval: enabled ? POLL_INTERVAL_MS : false,
    staleTime: 0, // Always treat as stale so every poll fetches fresh data
  })
}

export function useSendMessageMutation(threadId: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: SendMessageInput) => sendChatMessage(threadId, input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: chatKeys.messages(threadId) })
      queryClient.invalidateQueries({ queryKey: chatKeys.threads() })
    },
  })
}

export function useCloseChatThreadMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (threadId: number) => closeChatThread(threadId),
    onSuccess: (_data, threadId) => {
      queryClient.invalidateQueries({ queryKey: chatKeys.thread(threadId) })
      queryClient.invalidateQueries({ queryKey: chatKeys.threads() })
    },
  })
}

export function useReopenChatThreadMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (threadId: number) => reopenChatThread(threadId),
    onSuccess: (_data, threadId) => {
      queryClient.invalidateQueries({ queryKey: chatKeys.thread(threadId) })
      queryClient.invalidateQueries({ queryKey: chatKeys.threads() })
    },
  })
}
