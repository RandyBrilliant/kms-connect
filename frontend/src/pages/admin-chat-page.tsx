/**
 * Admin — Chat overview page.
 * Full-width thread list that navigates into individual application chat panels.
 */

import { IconMessage } from "@tabler/icons-react"
import { ChatThreadList } from "@/components/chat/chat-thread-list"

const APPLICATIONS_BASE = "/admin/lamaran"

export function AdminChatPage() {
  return (
    <div className="flex flex-col gap-4 h-[calc(100vh-4rem)]">
      <div className="px-6 pt-6 shrink-0">
        <div className="flex items-center gap-2">
          <IconMessage className="size-6" />
          <h1 className="text-2xl font-bold">Percakapan</h1>
        </div>
        <p className="text-muted-foreground text-sm mt-1">
          Daftar seluruh thread percakapan antara admin dan pelamar.
        </p>
      </div>
      <div className="flex-1 overflow-hidden mx-6 mb-6 rounded-lg border">
        <ChatThreadList basePath={APPLICATIONS_BASE} />
      </div>
    </div>
  )
}
