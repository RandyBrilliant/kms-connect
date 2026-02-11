/**
 * Admin users list page with table, search, filters.
 */

import { AdminTable } from "@/components/admins/admin-table"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { usePageTitle } from "@/hooks/use-page-title"

const BASE_PATH = "/admin"

export function AdminAdminListPage() {
  usePageTitle("Kelola Admin")
  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: "/" },
          { label: "Daftar Admin" },
        ]}
      />
      <h1 className="text-2xl font-bold">Kelola Admin</h1>
      <p className="text-muted-foreground">
        Daftar dan kelola pengguna dengan peran Admin
      </p>

      <AdminTable basePath={BASE_PATH} />
    </div>
  )
}
