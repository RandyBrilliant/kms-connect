/**
 * Staff dashboard home page with statistics about referred applicants.
 */

import {
  IconUsers,
  IconUserCheck,
  IconUserPlus,
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
import { useStaffDashboardStatsQuery } from "@/hooks/use-staff-self-service-query"
import { usePageTitle } from "@/hooks/use-page-title"

function formatDate(value: string | null | undefined) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy", { locale: id })
}

function verificationStatusLabel(status: string) {
  switch (status) {
    case "DRAFT":
      return "Draf"
    case "SUBMITTED":
      return "Dikirim"
    case "ACCEPTED":
      return "Diterima"
    case "REJECTED":
      return "Ditolak"
    default:
      return status
  }
}

function verificationStatusVariant(status: string) {
  switch (status) {
    case "DRAFT":
      return "outline"
    case "SUBMITTED":
      return "secondary"
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

export function StaffDashboardHomePage() {
  usePageTitle("Dashboard Staff")
  const { data: stats, isLoading, isError } = useStaffDashboardStatsQuery()

  if (isLoading) {
    return (
      <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
        <h1 className="text-2xl font-bold">Dashboard Staff</h1>
        <p className="text-muted-foreground">Memuat data...</p>
      </div>
    )
  }

  if (isError || !stats) {
    return (
      <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
        <h1 className="text-2xl font-bold">Dashboard Staff</h1>
        <p className="text-destructive">Gagal memuat data dashboard.</p>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:gap-6 md:px-8 md:py-8">
      <div>
        <h1 className="text-2xl font-bold">Dashboard Staff</h1>
        <p className="text-muted-foreground">
          Selamat datang di KMS-Connect. Lihat ringkasan pelamar yang Anda rujuk.
        </p>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-1 gap-4 @xl/main:grid-cols-2 @5xl/main:grid-cols-4">
        <StatCard
          title="Total Pelamar Rujukan"
          value={stats.total_referred_applicants}
          description="Pelamar yang Anda rujuk"
          icon={IconUsers}
        />
        <StatCard
          title="Pelamar Aktif"
          value={stats.total_active}
          description="Pelamar dengan status aktif"
          icon={IconUserPlus}
        />
        <StatCard
          title="Disetujui"
          value={stats.total_accepted}
          description="Pelamar yang diterima"
          icon={IconUserCheck}
        />
        <StatCard
          title="Menunggu Verifikasi"
          value={stats.total_submitted}
          description="Pelamar yang sudah submit"
          icon={IconChartBar}
        />
      </div>

      {/* Verification status breakdown */}
      <Card>
        <CardHeader>
          <CardTitle>Status Verifikasi</CardTitle>
          <CardDescription>Ringkasan status verifikasi pelamar rujukan Anda</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 gap-4 @xl/main:grid-cols-4">
            <div className="space-y-1">
              <p className="text-muted-foreground text-sm">Draf</p>
              <p className="text-2xl font-bold">
                {stats.verification_breakdown.DRAFT || 0}
              </p>
            </div>
            <div className="space-y-1">
              <p className="text-muted-foreground text-sm">Dikirim</p>
              <p className="text-2xl font-bold">
                {stats.verification_breakdown.SUBMITTED || 0}
              </p>
            </div>
            <div className="space-y-1">
              <p className="text-muted-foreground text-sm">Diterima</p>
              <p className="text-2xl font-bold text-green-600">
                {stats.verification_breakdown.ACCEPTED || 0}
              </p>
            </div>
            <div className="space-y-1">
              <p className="text-muted-foreground text-sm">Ditolak</p>
              <p className="text-2xl font-bold text-red-600">
                {stats.verification_breakdown.REJECTED || 0}
              </p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Recent applicants */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <div>
            <CardTitle>Pelamar Terbaru</CardTitle>
            <CardDescription>5 pelamar terbaru yang Anda rujuk</CardDescription>
          </div>
          <Button variant="outline" size="sm" asChild>
            <Link to="/staff-portal/pelamar">Lihat Semua</Link>
          </Button>
        </CardHeader>
        <CardContent>
          {stats.recent_applicants.length === 0 ? (
            <p className="text-muted-foreground text-center text-sm">
              Belum ada pelamar yang dirujuk.
            </p>
          ) : (
            <div className="rounded-md border">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Nama & Email</TableHead>
                    <TableHead>NIK</TableHead>
                    <TableHead>Status Verifikasi</TableHead>
                    <TableHead>Terdaftar</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {stats.recent_applicants.map((applicant) => {
                    const profile = applicant.applicant_profile
                    return (
                      <TableRow key={applicant.id}>
                        <TableCell>
                          <div className="flex flex-col">
                            <span className="font-medium">
                              {profile?.full_name || applicant.email}
                            </span>
                            <span className="text-muted-foreground text-xs">
                              {applicant.email}
                            </span>
                          </div>
                        </TableCell>
                        <TableCell>
                          <span className="text-sm">{profile?.nik || "-"}</span>
                        </TableCell>
                        <TableCell>
                          {profile?.verification_status && (
                            <Badge variant={verificationStatusVariant(profile.verification_status)}>
                              {verificationStatusLabel(profile.verification_status)}
                            </Badge>
                          )}
                          {!profile?.verification_status && <Badge variant="outline">-</Badge>}
                        </TableCell>
                        <TableCell>
                          <span className="text-sm">{formatDate(applicant.date_joined)}</span>
                        </TableCell>
                      </TableRow>
                    )
                  })}
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
            <Link to="/staff-portal/lowongan-kerja">
              Lihat Lowongan Kerja
            </Link>
          </Button>
          <Button variant="outline" asChild>
            <Link to="/staff-portal/pelamar">
              <IconUsers className="size-4" />
              Pelamar Saya
            </Link>
          </Button>
          <Button variant="outline" asChild>
            <Link to="/staff-portal/laporan">
              <IconChartBar className="size-4" />
              Laporan
            </Link>
          </Button>
          <Button variant="outline" asChild>
            <Link to="/staff-portal/profil">
              Pengaturan Profil
            </Link>
          </Button>
        </CardContent>
      </Card>
    </div>
  )
}
