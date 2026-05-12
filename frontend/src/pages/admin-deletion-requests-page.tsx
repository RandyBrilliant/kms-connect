/**
 * Admin: Permintaan Penghapusan Akun
 * List, approve, reject deletion requests submitted by applicants.
 */

import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { DeletionRequestsTable } from "@/components/deletion-requests/deletion-requests-table"
import { usePageTitle } from "@/hooks/use-page-title"
import { joinAdminPath, useAdminDashboard } from "@/contexts/admin-dashboard-context"

export function AdminDeletionRequestsPage() {
    usePageTitle("Permintaan Penghapusan Akun")
    const { basePath } = useAdminDashboard()

    return (
        <div className="flex flex-col gap-4 px-4 py-4 sm:gap-6 sm:px-6 sm:py-6 md:px-8 md:py-8">
            <div>
                <BreadcrumbNav
                    items={[
                        { label: "Dashboard", href: basePath || "/" },
                        { label: "Permintaan Hapus Akun", href: joinAdminPath(basePath, "/hapus-akun") },
                    ]}
                />
                <h1 className="mt-2 text-xl font-bold sm:text-2xl">Permintaan Penghapusan Akun</h1>
                <p className="text-muted-foreground text-sm sm:text-base">
                    Tinjau dan proses permintaan penghapusan akun dari pengguna.
                </p>
            </div>

            <DeletionRequestsTable />
        </div>
    )
}
