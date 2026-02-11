/**
 * Staff users list page with table, search, filters.
 */

import { StaffTable } from "@/components/staffs/staff-table"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { usePageTitle } from "@/hooks/use-page-title"

const BASE_PATH = "/staff"

export function StaffStaffListPage() {
  usePageTitle("Kelola Staff")
  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: "/" },
          { label: "Daftar Staff" },
        ]}
      />
      <h1 className="text-2xl font-bold">Kelola Staff</h1>
      <p className="text-muted-foreground">
        Daftar dan kelola pengguna dengan peran Staff
      </p>

      <StaffTable basePath={BASE_PATH} />
    </div>
  )
}
