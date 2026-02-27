/**
 * Sidebar list of all chat threads with unread count and last message preview.
 * Clicking a thread navigates to the admin application detail page.
 */

import { useState } from "react"
import { useNavigate } from "react-router-dom"
import { format } from "date-fns"
import { id } from "date-fns/locale"
import { IconSearch, IconMessage } from "@tabler/icons-react"

import { Input } from "@/components/ui/input"
import { Badge } from "@/components/ui/badge"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Button } from "@/components/ui/button"
import { useChatThreadsQuery } from "@/hooks/use-chat-query"
import { cn } from "@/lib/utils"

interface ChatThreadListProps {
  /** Base path for application detail. Thread click → {basePath}/{application_id}?tab=chat */
  basePath: string
  /** Highlight the thread currently open */
  activeThreadId?: number
}

export function ChatThreadList({ basePath, activeThreadId }: ChatThreadListProps) {
  const [search, setSearch] = useState("")
  const [page, setPage] = useState(1)

  const { data, isLoading } = useChatThreadsQuery({
    page,
    page_size: 30,
    search: search.trim() || undefined,
  })

  const navigate = useNavigate()

  return (
    <div className="flex flex-col h-full">
      {/* Search */}
      <div className="relative p-3 border-b">
        <IconSearch className="absolute left-6 top-1/2 -translate-y-1/2 size-4 text-muted-foreground" />
        <Input
          placeholder="Cari percakapan..."
          className="pl-8"
          value={search}
          onChange={(e) => {
            setSearch(e.target.value)
            setPage(1)
          }}
        />
      </div>

      <ScrollArea className="flex-1">
        {isLoading ? (
          <div className="flex justify-center py-8">
            <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          </div>
        ) : !data?.results?.length ? (
          <div className="flex flex-col items-center gap-2 py-12 text-center px-4">
            <IconMessage className="size-10 text-muted-foreground/40" />
            <p className="text-sm text-muted-foreground">
              {search ? "Tidak ada percakapan yang cocok." : "Belum ada percakapan."}
            </p>
          </div>
        ) : (
          <ul className="divide-y">
            {data.results.map((thread) => {
              const isActive = thread.id === activeThreadId
              const lastMsg = thread.last_message
              return (
                <li key={thread.id}>
                  <button
                    type="button"
                    onClick={() =>
                      navigate(
                        `${basePath}/${thread.application}?tab=chat`
                      )
                    }
                    className={cn(
                      "w-full text-left flex items-start gap-3 px-4 py-3 hover:bg-muted/50 transition-colors",
                      isActive && "bg-muted"
                    )}
                  >
                    <div className="flex-1 min-w-0 flex flex-col gap-0.5">
                      <div className="flex items-center justify-between gap-2">
                        <span className="font-medium text-sm truncate">
                          {thread.applicant_name ?? `Lamaran #${thread.application}`}
                        </span>
                        {lastMsg && (
                          <time className="text-[10px] text-muted-foreground shrink-0">
                            {format(new Date(lastMsg.sent_at), "HH:mm", {
                              locale: id,
                            })}
                          </time>
                        )}
                      </div>
                      <p className="text-xs text-muted-foreground truncate">
                        {lastMsg ? lastMsg.body : "Belum ada pesan"}
                      </p>
                    </div>
                    {thread.unread_count > 0 && (
                      <Badge className="shrink-0 h-5 min-w-5 justify-center text-[10px] px-1">
                        {thread.unread_count > 99 ? "99+" : thread.unread_count}
                      </Badge>
                    )}
                  </button>
                </li>
              )
            })}
          </ul>
        )}
      </ScrollArea>

      {/* Pagination controls (simple prev/next) */}
      {data && data.count > 30 && (
        <div className="flex items-center justify-between px-4 py-2 border-t">
          <Button
            variant="ghost"
            size="sm"
            className="cursor-pointer text-xs"
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            disabled={page <= 1}
          >
            Sebelumnya
          </Button>
          <span className="text-xs text-muted-foreground">
            Hal. {page} / {Math.ceil(data.count / 30)}
          </span>
          <Button
            variant="ghost"
            size="sm"
            className="cursor-pointer text-xs"
            onClick={() => setPage((p) => p + 1)}
            disabled={page >= Math.ceil(data.count / 30)}
          >
            Selanjutnya
          </Button>
        </div>
      )}
    </div>
  )
}
