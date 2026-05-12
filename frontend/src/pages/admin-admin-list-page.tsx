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
    <div className="flex flex-col gap-4 px-4 py-4 sm:gap-6 sm:px-6 sm:py-6 md:px-8 md:py-8">
      <div>
        <BreadcrumbNav
          items={[
            { label: "Dashboard", href: basePath || "/" },
            { label: "Daftar Admin" },
          ]}
        />
        <h1 className="mt-2 text-xl font-bold sm:text-2xl">Kelola Admin</h1>
        <p className="text-muted-foreground text-sm sm:text-base">
          {readOnly
            ? "Daftar pengguna admin (tampilan saja)."
            : "Daftar dan kelola pengguna dengan peran Admin"}
        </p>
      </div>

      <AdminTable basePath={adminBase} readOnly={readOnly} />
    </div>
  )
}
