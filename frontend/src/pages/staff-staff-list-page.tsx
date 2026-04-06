/**
 * Staff users list page with table, search, filters.
 */

import { StaffTable } from "@/components/staffs/staff-table"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { usePageTitle } from "@/hooks/use-page-title"
import { useAdminDashboard } from "@/contexts/admin-dashboard-context"
import { useAuth } from "@/hooks/use-auth"
import { isRestrictedAdmin } from "@/types/auth"

export function StaffStaffListPage() {
  const { basePath } = useAdminDashboard()
  const { user } = useAuth()
  const staffBase = `${basePath}/staff`
  const readOnly = user ? isRestrictedAdmin(user.role) : false

  usePageTitle("Kelola Staff")
  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: basePath || "/" },
          { label: "Daftar Staff" },
        ]}
      />
      <h1 className="text-2xl font-bold">Kelola Staff</h1>
      <p className="text-muted-foreground">
        {readOnly
          ? "Daftar staff (tampilan saja)."
          : "Daftar dan kelola pengguna dengan peran Staff"}
      </p>

      <StaffTable basePath={staffBase} readOnly={readOnly} />
    </div>
  )
}
