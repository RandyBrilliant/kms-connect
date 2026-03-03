/**
 * Full inline chat panel for a specific JobApplication / ChatThread.
 * Uses WebSocket for real-time updates with polling fallback via useChatMessagesQuery.
 */

import { useState, useRef, useEffect } from "react"
import { format } from "date-fns"
import { id } from "date-fns/locale"
import { IconSend, IconLock, IconLockOpen } from "@tabler/icons-react"

import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Badge } from "@/components/ui/badge"
import {
  useChatThreadQuery,
  useChatMessagesQuery,
  useSendMessageMutation,
  useCloseChatThreadMutation,
  useReopenChatThreadMutation,
} from "@/hooks/use-chat-query"
import { useChatWebSocket } from "@/hooks/use-chat-websocket"
import { toast } from "@/lib/toast"
import { cn } from "@/lib/utils"

interface ChatPanelProps {
  /** Backend ChatThread ID */
  threadId: number
  /** The user ID that is "me" — messages from this sender appear on the right */
  currentUserId: number
  /** If false, the send form and close/reopen buttons are hidden (read-only view) */
  canManage?: boolean
}

export function ChatPanel({
  threadId,
  currentUserId,
  canManage = true,
}: ChatPanelProps) {
  const [body, setBody] = useState("")
  const bottomRef = useRef<HTMLDivElement>(null)

  const { data: thread } = useChatThreadQuery(threadId)
  const { data: messages, isLoading } = useChatMessagesQuery(threadId)
  const sendMutation = useSendMessageMutation(threadId)
  const closeMutation = useCloseChatThreadMutation()
  const reopenMutation = useReopenChatThreadMutation()

  // WebSocket for real-time updates + typing indicator
  const { connected, typingUser, sendTyping, sendMarkRead } =
    useChatWebSocket(threadId, canManage)

  const isClosed = thread?.is_closed ?? false

  // Scroll to bottom when messages arrive
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" })
  }, [messages])

  // Mark as read when panel opens
  useEffect(() => {
    if (threadId && connected) {
      sendMarkRead()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [threadId, connected])

  const handleSend = async () => {
    const trimmed = body.trim()
    if (!trimmed || sendMutation.isPending) return
    setBody("")
    try {
      await sendMutation.mutateAsync({ body: trimmed })
    } catch {
      toast.error("Gagal mengirim", "Pesan gagal terkirim, coba lagi.")
      setBody(trimmed) // restore
    }
  }

  const handleClose = async () => {
    try {
      await closeMutation.mutateAsync(threadId)
      toast.success("Chat ditutup", "Thread percakapan telah ditutup.")
    } catch {
      toast.error("Gagal menutup", "Coba lagi nanti.")
    }
  }

  const handleReopen = async () => {
    try {
      await reopenMutation.mutateAsync(threadId)
      toast.success("Chat dibuka kembali", "Thread percakapan aktif kembali.")
    } catch {
      toast.error("Gagal membuka kembali", "Coba lagi nanti.")
    }
  }

  return (
    <div className="flex flex-col h-full min-h-[400px] rounded-lg border bg-background overflow-hidden">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-2 border-b bg-muted/30">
        <div className="flex items-center gap-2">
          <span className="font-medium text-sm">Percakapan</span>
          {isClosed && (
            <Badge variant="secondary" className="text-xs">
              Ditutup
            </Badge>
          )}
          {!isClosed && (
            <span
              className={cn(
                "inline-block size-2 rounded-full",
                connected ? "bg-green-500" : "bg-muted-foreground/40"
              )}
              title={connected ? "Terhubung" : "Terputus"}
            />
          )}
          {typingUser && (
            <span className="text-xs text-muted-foreground italic animate-pulse">
              {typingUser} sedang mengetik...
            </span>
          )}
        </div>
        {canManage && (
          <div>
            {isClosed ? (
              <Button
                variant="ghost"
                size="sm"
                className="h-7 cursor-pointer gap-1 text-xs"
                onClick={handleReopen}
                disabled={reopenMutation.isPending}
              >
                <IconLockOpen className="size-3.5" />
                Buka Kembali
              </Button>
            ) : (
              <Button
                variant="ghost"
                size="sm"
                className="h-7 cursor-pointer gap-1 text-xs text-muted-foreground hover:text-destructive"
                onClick={handleClose}
                disabled={closeMutation.isPending}
              >
                <IconLock className="size-3.5" />
                Tutup Chat
              </Button>
            )}
          </div>
        )}
      </div>

      {/* Messages */}
      <ScrollArea className="flex-1 px-4 py-3">
        {isLoading ? (
          <div className="flex justify-center py-8">
            <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          </div>
        ) : !messages?.length ? (
          <p className="text-center text-sm text-muted-foreground py-8">
            Belum ada pesan. Mulai percakapan sekarang.
          </p>
        ) : (
          <div className="flex flex-col gap-3">
            {messages.map((msg) => {
              const isMe = msg.sender === currentUserId
              return (
                <div
                  key={msg.id}
                  className={cn(
                    "flex flex-col max-w-[75%] gap-0.5",
                    isMe ? "self-end items-end" : "self-start items-start"
                  )}
                >
                  {!isMe && (
                    <span className="text-xs text-muted-foreground font-medium">
                      {msg.sender_name ?? "Pelamar"}
                    </span>
                  )}
                  <div
                    className={cn(
                      "rounded-2xl px-3 py-2 text-sm leading-relaxed break-words whitespace-pre-wrap",
                      isMe
                        ? "bg-primary text-primary-foreground rounded-br-sm"
                        : "bg-muted text-foreground rounded-bl-sm"
                    )}
                  >
                    {msg.body}
                  </div>
                  <time className="text-[10px] text-muted-foreground">
                    {format(new Date(msg.sent_at), "HH:mm, dd MMM", {
                      locale: id,
                    })}
                  </time>
                </div>
              )
            })}
            <div ref={bottomRef} />
          </div>
        )}
      </ScrollArea>

      {/* Send form */}
      {canManage && !isClosed && (
        <form
          className="flex items-center gap-2 px-4 py-3 border-t"
          onSubmit={(e) => {
            e.preventDefault()
            handleSend()
          }}
        >
          <Input
            value={body}
            onChange={(e) => {
              setBody(e.target.value)
              sendTyping()
            }}
            placeholder="Tulis pesan..."
            className="flex-1"
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault()
                handleSend()
              }
            }}
          />
          <Button
            type="submit"
            size="icon"
            className="cursor-pointer shrink-0"
            disabled={!body.trim() || sendMutation.isPending}
          >
            <IconSend className="size-4" />
            <span className="sr-only">Kirim</span>
          </Button>
        </form>
      )}
    </div>
  )
}
