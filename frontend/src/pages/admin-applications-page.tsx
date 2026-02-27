/**
 * Admin — Applications list page.
 * Thin orchestration page that renders the ApplicationTable.
 */

import { ApplicationTable } from "@/components/applications/application-table"

const APPLICATIONS_BASE = "/admin/lamaran"

export function AdminApplicationsPage() {
  return (
    <div className="flex flex-col gap-6 p-6">
      <div>
        <h1 className="text-2xl font-bold">Manajemen Lamaran</h1>
        <p className="text-muted-foreground text-sm mt-1">
          Kelola seluruh data lamaran pelamar dan penugasan admin.
        </p>
      </div>
      <ApplicationTable basePath={APPLICATIONS_BASE} />
    </div>
  )
}
