/**
 * Admin broadcast list page with table, search, filters.
 */

import { BroadcastTable } from "@/components/broadcasts/broadcast-table"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { usePageTitle } from "@/hooks/use-page-title"
import { joinAdminPath, useAdminDashboard } from "@/contexts/admin-dashboard-context"

export function AdminBroadcastListPage() {
  const { basePath } = useAdminDashboard()
  const BASE_PATH = joinAdminPath(basePath, "/broadcasts")

  usePageTitle("Kelola Broadcast")

  return (
    <div className="flex flex-col gap-4 px-4 py-4 sm:gap-6 sm:px-6 sm:py-6 md:px-8 md:py-8">
      <div>
        <BreadcrumbNav
          items={[
            { label: "Dashboard", href: basePath || "/" },
            { label: "Broadcast" },
          ]}
        />
        <h1 className="mt-2 text-xl font-bold sm:text-2xl">Kelola Broadcast</h1>
        <p className="text-muted-foreground text-sm sm:text-base">
          Kirim notifikasi massal ke pengguna terpilih
        </p>
      </div>

      <BroadcastTable basePath={BASE_PATH} />
    </div>
  )
}
