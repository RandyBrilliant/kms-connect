/**
 * Company dashboard home page with statistics and recent activity.
 */

import {
  IconBriefcase,
  IconUsers,
  IconFileText,
  IconChartBar,
} from "@tabler/icons-react"
import { format } from "date-fns"
import { id } from "date-fns/locale"
import { Link } from "react-router-dom"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { useCompanyDashboardStatsQuery } from "@/hooks/use-company-self-service-query"
import { usePageTitle } from "@/hooks/use-page-title"
import type { ApplicationStatus } from "@/types/job-applications"

function formatDate(value: string | null | undefined) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy HH:mm", { locale: id })
}

function applicationStatusLabel(status: ApplicationStatus) {
  switch (status) {
    case "APPLIED":
      return "Dilamar"
    case "UNDER_REVIEW":
      return "Dalam Review"
    case "ACCEPTED":
      return "Diterima"
    case "REJECTED":
      return "Ditolak"
    default:
      return status
  }
}

function applicationStatusVariant(status: ApplicationStatus) {
  switch (status) {
    case "APPLIED":
      return "secondary"
    case "UNDER_REVIEW":
      return "default"
    case "ACCEPTED":
      return "default"
    case "REJECTED":
      return "destructive"
    default:
      return "outline"
  }
}

function StatCard({
  title,
  value,
  description,
  icon: Icon,
}: {
  title: string
  value: number | string
  description: string
  icon: React.ComponentType<{ className?: string }>
}) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium">{title}</CardTitle>
        <Icon className="text-muted-foreground size-4" />
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">{value}</div>
        <p className="text-muted-foreground text-xs">{description}</p>
      </CardContent>
    </Card>
  )
}

export function CompanyDashboardHomePage() {
  usePageTitle("Dashboard Perusahaan")
  const { data: stats, isLoading, isError } = useCompanyDashboardStatsQuery()

  if (isLoading) {
    return (
      <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
        <h1 className="text-2xl font-bold">Dashboard Perusahaan</h1>
        <p className="text-muted-foreground">Memuat data...</p>
      </div>
    )
  }

  if (isError || !stats) {
    return (
      <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
        <h1 className="text-2xl font-bold">Dashboard Perusahaan</h1>
        <p className="text-destructive">Gagal memuat data dashboard.</p>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:gap-6 md:px-8 md:py-8">
      <div>
        <h1 className="text-2xl font-bold">Dashboard Perusahaan</h1>
        <p className="text-muted-foreground">
          Selamat datang di KMS-Connect. Lihat ringkasan lowongan dan lamaran.
        </p>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-1 gap-4 @xl/main:grid-cols-2 @5xl/main:grid-cols-4">
        <StatCard
          title="Total Lowongan"
          value={stats.total_jobs}
          description="Total lowongan kerja yang dipublikasikan"
          icon={IconBriefcase}
        />
        <StatCard
          title="Lowongan Aktif"
          value={stats.total_open_jobs}
          description="Lowongan yang sedang dibuka"
          icon={IconChartBar}
        />
        <StatCard
          title="Total Lamaran"
          value={stats.total_applications}
          description="Lamaran yang masuk"
          icon={IconFileText}
        />
        <StatCard
          title="Pelamar Unik"
          value={stats.total_applicants}
          description="Jumlah pelamar berbeda"
          icon={IconUsers}
        />
      </div>

      {/* Application status breakdown */}
      <Card>
        <CardHeader>
          <CardTitle>Status Lamaran</CardTitle>
          <CardDescription>Ringkasan status lamaran yang masuk</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 gap-4 @xl/main:grid-cols-4">
            <div className="space-y-1">
              <p className="text-muted-foreground text-sm">Dilamar</p>
              <p className="text-2xl font-bold">
                {stats.status_breakdown.APPLIED || 0}
              </p>
            </div>
            <div className="space-y-1">
              <p className="text-muted-foreground text-sm">Dalam Review</p>
              <p className="text-2xl font-bold">
                {stats.status_breakdown.UNDER_REVIEW || 0}
              </p>
            </div>
            <div className="space-y-1">
              <p className="text-muted-foreground text-sm">Diterima</p>
              <p className="text-2xl font-bold text-green-600">
                {stats.status_breakdown.ACCEPTED || 0}
              </p>
            </div>
            <div className="space-y-1">
              <p className="text-muted-foreground text-sm">Ditolak</p>
              <p className="text-2xl font-bold text-red-600">
                {stats.status_breakdown.REJECTED || 0}
              </p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Recent applications */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <div>
            <CardTitle>Lamaran Terbaru</CardTitle>
            <CardDescription>5 lamaran terbaru yang masuk</CardDescription>
          </div>
          <Button variant="outline" size="sm" asChild>
            <Link to="/company/lowongan-kerja">Lihat Semua</Link>
          </Button>
        </CardHeader>
        <CardContent>
          {stats.recent_applications.length === 0 ? (
            <p className="text-muted-foreground text-center text-sm">
              Belum ada lamaran masuk.
            </p>
          ) : (
            <div className="rounded-md border">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Pelamar</TableHead>
                    <TableHead>Lowongan</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Tanggal Lamar</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {stats.recent_applications.map((app) => (
                    <TableRow key={app.id}>
                      <TableCell>
                        <div className="flex flex-col">
                          <span className="font-medium">
                            {app.applicant_name || "-"}
                          </span>
                          <span className="text-muted-foreground text-xs">
                            {app.applicant_email || "-"}
                          </span>
                        </div>
                      </TableCell>
                      <TableCell>
                        <span className="text-sm">{app.job_title || "-"}</span>
                      </TableCell>
                      <TableCell>
                        <Badge variant={applicationStatusVariant(app.status)}>
                          {applicationStatusLabel(app.status)}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <span className="text-sm">{formatDate(app.applied_at)}</span>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Quick actions */}
      <Card>
        <CardHeader>
          <CardTitle>Akses Cepat</CardTitle>
          <CardDescription>Menu-menu yang sering digunakan</CardDescription>
        </CardHeader>
        <CardContent className="flex flex-wrap gap-2">
          <Button variant="outline" asChild>
            <Link to="/company/lowongan-kerja">
              <IconBriefcase className="size-4" />
              Lihat Lowongan
            </Link>
          </Button>
          <Button variant="outline" asChild>
            <Link to="/company/pelamar">
              <IconUsers className="size-4" />
              Lihat Pelamar
            </Link>
          </Button>
          <Button variant="outline" asChild>
            <Link to="/company/profil">
              Pengaturan Profil
            </Link>
          </Button>
        </CardContent>
      </Card>
    </div>
  )
}
