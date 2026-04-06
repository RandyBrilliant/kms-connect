/**
 * Admin users list page with table, search, filters.
 */

import { AdminTable } from "@/components/admins/admin-table"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { usePageTitle } from "@/hooks/use-page-title"
import { useAdminDashboard } from "@/contexts/admin-dashboard-context"
import { useAuth } from "@/hooks/use-auth"
import { isRestrictedAdmin } from "@/types/auth"

export function AdminAdminListPage() {
  const { basePath } = useAdminDashboard()
  const { user } = useAuth()
  const adminBase = `${basePath}/admin`
  const readOnly = user ? isRestrictedAdmin(user.role) : false

  usePageTitle("Kelola Admin")
  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: basePath || "/" },
          { label: "Daftar Admin" },
        ]}
      />
      <h1 className="text-2xl font-bold">Kelola Admin</h1>
      <p className="text-muted-foreground">
        {readOnly
          ? "Daftar pengguna admin (tampilan saja)."
          : "Daftar dan kelola pengguna dengan peran Admin"}
      </p>

      <AdminTable basePath={adminBase} readOnly={readOnly} />
    </div>
  )
}
