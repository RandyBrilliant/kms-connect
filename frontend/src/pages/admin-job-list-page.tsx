/**
 * Admin jobs list page with table, search, filters.
 * Sidebar "Lowongan Kerja" points to "/lowongan-kerja".
 */

import { JobTable } from "@/components/jobs/job-table"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { usePageTitle } from "@/hooks/use-page-title"

const BASE_PATH = "/lowongan-kerja"

export function AdminJobListPage() {
  usePageTitle("Kelola Lowongan Kerja")
  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: "/" },
          { label: "Lowongan Kerja" },
        ]}
      />
      <h1 className="text-2xl font-bold">Kelola Lowongan Kerja</h1>
      <p className="text-muted-foreground">
        Daftar dan kelola lowongan kerja yang dapat dilamar oleh pelamar.
      </p>

      <JobTable basePath={BASE_PATH} />
    </div>
  )
}

