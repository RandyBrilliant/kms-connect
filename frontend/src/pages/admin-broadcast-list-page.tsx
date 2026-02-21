/**
 * Admin broadcast list page with table, search, filters.
 */

import { BroadcastTable } from "@/components/broadcasts/broadcast-table"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { usePageTitle } from "@/hooks/use-page-title"

const BASE_PATH = "/broadcasts"

export function AdminBroadcastListPage() {
  usePageTitle("Kelola Broadcast")
  
  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: "/" },
          { label: "Broadcast" },
        ]}
      />
      <h1 className="text-2xl font-bold">Kelola Broadcast</h1>
      <p className="text-muted-foreground">
        Kirim notifikasi massal ke pengguna terpilih
      </p>

      <BroadcastTable basePath={BASE_PATH} />
    </div>
  )
}
