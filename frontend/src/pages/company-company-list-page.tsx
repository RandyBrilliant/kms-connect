/**
 * Company users list page with table, search, filters.
 */

import { CompanyTable } from "@/components/companies/company-table"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"

const BASE_PATH = "/perusahaan"

export function CompanyCompanyListPage() {
  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: "/" },
          { label: "Daftar Perusahaan" },
        ]}
      />
      <h1 className="text-2xl font-bold">Kelola Perusahaan</h1>
      <p className="text-muted-foreground">
        Daftar dan kelola pengguna dengan peran Perusahaan
      </p>

      <CompanyTable basePath={BASE_PATH} />
    </div>
  )
}

