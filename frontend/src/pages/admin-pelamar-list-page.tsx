/**
 * Pelamar list page.
 */

import { ApplicantTable } from "@/components/applicants/applicant-table"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { usePageTitle } from "@/hooks/use-page-title"

const BASE_PATH = "/pelamar"

export function AdminPelamarListPage() {
  usePageTitle("Daftar Pelamar")
  return (
    <div className="flex flex-col gap-6 px-6 py-6 md:px-8 md:py-8">
      <div>
        <BreadcrumbNav
          items={[
            { label: "Dashboard", href: "/" },
            { label: "Daftar Pelamar", href: BASE_PATH },
          ]}
        />
        <h1 className="mt-2 text-2xl font-bold">Daftar Pelamar</h1>
        <p className="text-muted-foreground">
          Kelola data pelamar / CPMI
        </p>
      </div>

      <ApplicantTable basePath={BASE_PATH} />
    </div>
  )
}
