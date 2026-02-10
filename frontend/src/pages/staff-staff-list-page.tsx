/**
 * Staff users list page with table, search, filters.
 */

import { Link } from "react-router-dom"
import { IconArrowLeft } from "@tabler/icons-react"

import { StaffTable } from "@/components/staffs/staff-table"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Button } from "@/components/ui/button"

const BASE_PATH = "/staff"

export function StaffStaffListPage() {
    return (
        <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
            <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                <div className="flex flex-col gap-2">
                    <Button variant="ghost" size="sm" className="w-fit -ml-2" asChild>
                        <Link to="/">
                            <IconArrowLeft className="mr-2 size-4" />
                            Kembali
                        </Link>
                    </Button>
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
                </div>
            </div>

            <StaffTable basePath={BASE_PATH} />
        </div>
    )
}
