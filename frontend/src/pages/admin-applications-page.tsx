/**
 * Admin — Applications list page.
 * Follows the AdminAdminListPage layout convention:
 * BreadcrumbNav + usePageTitle + consistent padding + table component.
 */

import { ApplicationTable } from "@/components/applications/application-table"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { usePageTitle } from "@/hooks/use-page-title"

const APPLICATIONS_BASE = "/lamaran"

export function AdminApplicationsPage() {
  usePageTitle("Manajemen Lamaran")
  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: "/" },
          { label: "Manajemen Lamaran" },
        ]}
      />
      <h1 className="text-2xl font-bold">Manajemen Lamaran</h1>
      <p className="text-muted-foreground">
        Kelola seluruh data lamaran pelamar dan penugasan admin
      </p>
      <ApplicationTable basePath={APPLICATIONS_BASE} />
    </div>
  )
}
