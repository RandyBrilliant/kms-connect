/**
 * Master Admin audit log page — append-only activity feed.
 */

import { AuditEventsTable } from "@/components/audit/audit-events-table"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { usePageTitle } from "@/hooks/use-page-title"
import { useAdminDashboard } from "@/contexts/admin-dashboard-context"

export function AdminAuditLogPage() {
  const { basePath } = useAdminDashboard()

  usePageTitle("Log Audit")
  return (
    <div className="flex flex-col gap-4 px-4 py-4 sm:gap-6 sm:px-6 sm:py-6 md:px-8 md:py-8">
      <div>
        <BreadcrumbNav
          items={[
            { label: "Dashboard", href: basePath || "/" },
            { label: "Log Audit" },
          ]}
        />
        <h1 className="mt-2 text-xl font-bold sm:text-2xl">Log Audit</h1>
        <p className="text-muted-foreground text-sm sm:text-base">
          Riwayat aktivitas sistem (tulis & keamanan). Hanya Admin Utama yang dapat
          melihat. Catatan tidak dapat dihapus atau diubah.
        </p>
      </div>

      <AuditEventsTable />
    </div>
  )
}
