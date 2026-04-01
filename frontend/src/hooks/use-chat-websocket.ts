/**
 * React hook for WebSocket chat connection.
 *
 * Connects to `ws(s)://<host>/ws/chat/<threadId>/?token=<JWT>` and provides
 * a stream of events: new messages, typing indicators, and read receipts.
 *
 * Falls back gracefully to polling if WebSocket connection fails.
 */

import { useEffect, useRef, useCallback, useState } from "react"
import { useQueryClient } from "@tanstack/react-query"
import { env } from "@/lib/env"
import { chatKeys } from "./use-chat-query"

// ── Types ──────────────────────────────────────────────────────────────────

interface ChatWsMessage {
  type: "chat.message"
  message: {
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
}

interface ChatWsTyping {
  type: "chat.typing"
  user_id: number
  user_name: string
}

interface ChatWsRead {
  type: "chat.read"
  user_id: number
  read_at: string
}

type ChatWsEvent = ChatWsMessage | ChatWsTyping | ChatWsRead

export interface UseChatWebSocketResult {
  /** Whether the WebSocket is currently connected */
  connected: boolean
  /** The name of the user currently typing (null if nobody) */
  typingUser: string | null
  /** Send a typing indicator to the server */
  sendTyping: () => void
  /** Send a mark_read event */
  sendMarkRead: () => void
}

// ── Helpers ────────────────────────────────────────────────────────────────

function getAccessToken(): string | null {
  // Read from cookie (same approach as the API client)
  const cookies = document.cookie.split(";")
  for (const c of cookies) {
    const [key, val] = c.trim().split("=")
    if (key === "kms_access" && val) return decodeURIComponent(val)
  }
  // Fallback: localStorage
  return localStorage.getItem("access_token")
}

/**
 * WebSocket host must match the REST API (same as axios `VITE_API_URL`).
 * Legacy: if you still set `VITE_API_BASE_URL` only, set `VITE_API_URL` to the same value in production.
 */
function buildWsUrl(threadId: number, token: string): string {
  const legacyBase = import.meta.env.VITE_API_BASE_URL as string | undefined
  const base = env.VITE_API_URL || legacyBase
  if (base) {
    const url = new URL(base)
    const scheme = url.protocol === "https:" ? "wss" : "ws"
    return `${scheme}://${url.host}/ws/chat/${threadId}/?token=${encodeURIComponent(token)}`
  }
  const loc = window.location
  const wsScheme = loc.protocol === "https:" ? "wss" : "ws"
  return `${wsScheme}://${loc.host}/ws/chat/${threadId}/?token=${encodeURIComponent(token)}`
}

// ── Hook ───────────────────────────────────────────────────────────────────

const MAX_RECONNECT_ATTEMPTS = 10

export function useChatWebSocket(
  threadId: number | null,
  enabled = true
): UseChatWebSocketResult {
  const queryClient = useQueryClient()
  const wsRef = useRef<WebSocket | null>(null)
  const reconnectAttemptRef = useRef(0)
  const reconnectTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const typingTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const outgoingTypingTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  const [connected, setConnected] = useState(false)
  const [typingUser, setTypingUser] = useState<string | null>(null)

  const connect = useCallback(() => {
    if (!threadId || !enabled) return

    const token = getAccessToken()
    if (!token) return

    try {
      const url = buildWsUrl(threadId, token)
      const ws = new WebSocket(url)
      wsRef.current = ws

      ws.onopen = () => {
        setConnected(true)
        reconnectAttemptRef.current = 0
      }

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data) as ChatWsEvent

          switch (data.type) {
            case "chat.message":
              // Invalidate queries so TanStack refetches
              queryClient.invalidateQueries({
                queryKey: chatKeys.messages(threadId),
              })
              queryClient.invalidateQueries({
                queryKey: chatKeys.threads(),
              })
              // Clear typing when message arrives
              setTypingUser(null)
              break

            case "chat.typing":
              setTypingUser(data.user_name)
              if (typingTimerRef.current)
                clearTimeout(typingTimerRef.current)
              typingTimerRef.current = setTimeout(
                () => setTypingUser(null),
                3000
              )
              break

            case "chat.read":
              queryClient.invalidateQueries({
                queryKey: chatKeys.messages(threadId),
              })
              break
          }
        } catch {
          // Ignore parse errors
        }
      }

      ws.onclose = () => {
        setConnected(false)
        wsRef.current = null
        scheduleReconnect()
      }

      ws.onerror = () => {
        ws.close()
      }
    } catch {
      scheduleReconnect()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [threadId, enabled, queryClient])

  const scheduleReconnect = useCallback(() => {
    if (reconnectAttemptRef.current >= MAX_RECONNECT_ATTEMPTS) return
    reconnectAttemptRef.current++
    const delay = Math.min(
      1000 * Math.pow(2, reconnectAttemptRef.current - 1),
      30000
    )
    reconnectTimerRef.current = setTimeout(() => connect(), delay)
  }, [connect])

  const sendTyping = useCallback(() => {
    if (outgoingTypingTimerRef.current) return // debounce
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify({ type: "typing" }))
      outgoingTypingTimerRef.current = setTimeout(() => {
        outgoingTypingTimerRef.current = null
      }, 2000)
    }
  }, [])

  const sendMarkRead = useCallback(() => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify({ type: "mark_read" }))
    }
  }, [])

  // Connect on mount / when threadId changes
  useEffect(() => {
    connect()

    return () => {
      if (reconnectTimerRef.current) clearTimeout(reconnectTimerRef.current)
      if (typingTimerRef.current) clearTimeout(typingTimerRef.current)
      if (outgoingTypingTimerRef.current)
        clearTimeout(outgoingTypingTimerRef.current)
      wsRef.current?.close()
      wsRef.current = null
      setConnected(false)
      setTypingUser(null)
    }
  }, [connect])

  return { connected, typingUser, sendTyping, sendMarkRead }
}
