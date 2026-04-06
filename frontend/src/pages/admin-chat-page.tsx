/**
 * Admin — Chat overview page.
 * Full-width thread list that navigates into individual application chat panels.
 */

import { ChatThreadList } from "@/components/chat/chat-thread-list"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { usePageTitle } from "@/hooks/use-page-title"
import { joinAdminPath, useAdminDashboard } from "@/contexts/admin-dashboard-context"

export function AdminChatPage() {
  const { basePath } = useAdminDashboard()
  const lamaranBase = joinAdminPath(basePath, "/lamaran")

  usePageTitle("Percakapan")
  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8 h-[calc(100vh-4rem)]">
      <div className="shrink-0 flex flex-col gap-4">
        <BreadcrumbNav
          items={[
            { label: "Dashboard", href: basePath || "/" },
            { label: "Percakapan" },
          ]}
        />
        <h1 className="text-2xl font-bold">Percakapan</h1>
        <p className="text-muted-foreground">
          Daftar seluruh thread percakapan antara admin dan pelamar
        </p>
      </div>
      <div className="flex-1 overflow-hidden rounded-lg border min-h-0">
        <ChatThreadList basePath={lamaranBase} />
      </div>
    </div>
  )
}
