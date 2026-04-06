/**
 * Admin jobs list page with table, search, filters.
 */

import { JobTable } from "@/components/jobs/job-table"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { usePageTitle } from "@/hooks/use-page-title"
import { useAdminDashboard } from "@/contexts/admin-dashboard-context"
import { useAuth } from "@/hooks/use-auth"
import { isRestrictedAdmin } from "@/types/auth"

export function AdminJobListPage() {
  const { basePath } = useAdminDashboard()
  const { user } = useAuth()
  const jobsBase = `${basePath}/lowongan-kerja`
  const readOnly = user ? isRestrictedAdmin(user.role) : false

  usePageTitle("Kelola Lowongan Kerja")
  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: basePath || "/" },
          { label: "Lowongan Kerja" },
        ]}
      />
      <h1 className="text-2xl font-bold">Kelola Lowongan Kerja</h1>
      <p className="text-muted-foreground">
        {readOnly
          ? "Daftar lowongan (lihat saja). Pengaturan master data hanya untuk Admin Utama."
          : "Daftar dan kelola lowongan kerja yang dapat dilamar oleh pelamar."}
      </p>

      <JobTable basePath={jobsBase} readOnly={readOnly} />
    </div>
  )
}
