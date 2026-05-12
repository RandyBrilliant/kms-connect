/**
 * Company users list page with table, search, filters.
 */

import { CompanyTable } from "@/components/companies/company-table"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { usePageTitle } from "@/hooks/use-page-title"

const BASE_PATH = "/perusahaan"

export function CompanyCompanyListPage() {
  usePageTitle("Kelola Perusahaan")
  return (
    <div className="flex flex-col gap-4 px-4 py-4 sm:gap-6 sm:px-6 sm:py-6 md:px-8 md:py-8">
      <div>
        <BreadcrumbNav
          items={[
            { label: "Dashboard", href: "/" },
            { label: "Daftar Perusahaan" },
          ]}
        />
        <h1 className="mt-2 text-xl font-bold sm:text-2xl">Kelola Perusahaan</h1>
        <p className="text-muted-foreground text-sm sm:text-base">
          Daftar dan kelola pengguna dengan peran Perusahaan
        </p>
      </div>

      <CompanyTable basePath={BASE_PATH} />
    </div>
  )
}

