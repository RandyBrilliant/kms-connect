/**
 * Staff laporan (reports) page - shows statistics and reports about referred applicants.
 */

import {
  IconUsers,
  IconUserCheck,
  IconUserPlus,
  IconChartBar,
  IconFileDownload,
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
import { useStaffDashboardStatsQuery, useStaffReferredApplicantsQuery } from "@/hooks/use-staff-self-service-query"
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

export function StaffLaporanPage() {
  usePageTitle("Laporan - Staff")
  
  const { data: stats, isLoading: statsLoading } = useStaffDashboardStatsQuery()
  const { data: applicants, isLoading: applicantsLoading } = useStaffReferredApplicantsQuery({
    page: 1,
  })

  const isLoading = statsLoading || applicantsLoading

  // Calculate success rate
  const successRate = stats
    ? stats.total_referred_applicants > 0
      ? ((stats.total_accepted / stats.total_referred_applicants) * 100).toFixed(1)
      : "0.0"
    : "0.0"

  const pendingRate = stats
    ? stats.total_referred_applicants > 0
      ? ((stats.total_submitted / stats.total_referred_applicants) * 100).toFixed(1)
      : "0.0"
    : "0.0"

  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:gap-6 md:px-8 md:py-8">
      <div>
        <h1 className="text-2xl font-bold">Laporan Pelamar Rujukan</h1>
        <p className="text-muted-foreground">
          Statistik dan laporan lengkap tentang pelamar yang Anda rujuk.
        </p>
      </div>

      {isLoading && (
        <p className="text-muted-foreground">Memuat data laporan...</p>
      )}

      {!isLoading && stats && (
        <>
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

          {/* Performance Metrics */}
          <div className="grid grid-cols-1 gap-4 @xl/main:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle>Tingkat Keberhasilan</CardTitle>
                <CardDescription>Persentase pelamar yang berhasil diterima</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="text-4xl font-bold text-green-600">{successRate}%</div>
                <p className="text-muted-foreground mt-2 text-sm">
                  {stats.total_accepted} dari {stats.total_referred_applicants} pelamar diterima
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Tingkat Pending</CardTitle>
                <CardDescription>Persentase pelamar menunggu verifikasi</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="text-4xl font-bold text-amber-600">{pendingRate}%</div>
                <p className="text-muted-foreground mt-2 text-sm">
                  {stats.total_submitted} dari {stats.total_referred_applicants} pelamar menunggu
                </p>
              </CardContent>
            </Card>
          </div>

          {/* Verification status breakdown */}
          <Card>
            <CardHeader>
              <CardTitle>Status Verifikasi Detail</CardTitle>
              <CardDescription>Breakdown lengkap status verifikasi pelamar rujukan</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 gap-6 @xl/main:grid-cols-4">
                <div className="space-y-2">
                  <p className="text-muted-foreground text-sm">Draf</p>
                  <p className="text-3xl font-bold">
                    {stats.verification_breakdown.DRAFT || 0}
                  </p>
                  <p className="text-muted-foreground text-xs">
                    {stats.total_referred_applicants > 0
                      ? ((stats.verification_breakdown.DRAFT || 0) / stats.total_referred_applicants * 100).toFixed(1)
                      : "0.0"}% dari total
                  </p>
                </div>
                <div className="space-y-2">
                  <p className="text-muted-foreground text-sm">Dikirim</p>
                  <p className="text-3xl font-bold text-amber-600">
                    {stats.verification_breakdown.SUBMITTED || 0}
                  </p>
                  <p className="text-muted-foreground text-xs">
                    {stats.total_referred_applicants > 0
                      ? ((stats.verification_breakdown.SUBMITTED || 0) / stats.total_referred_applicants * 100).toFixed(1)
                      : "0.0"}% dari total
                  </p>
                </div>
                <div className="space-y-2">
                  <p className="text-muted-foreground text-sm">Diterima</p>
                  <p className="text-3xl font-bold text-green-600">
                    {stats.verification_breakdown.ACCEPTED || 0}
                  </p>
                  <p className="text-muted-foreground text-xs">
                    {stats.total_referred_applicants > 0
                      ? ((stats.verification_breakdown.ACCEPTED || 0) / stats.total_referred_applicants * 100).toFixed(1)
                      : "0.0"}% dari total
                  </p>
                </div>
                <div className="space-y-2">
                  <p className="text-muted-foreground text-sm">Ditolak</p>
                  <p className="text-3xl font-bold text-red-600">
                    {stats.verification_breakdown.REJECTED || 0}
                  </p>
                  <p className="text-muted-foreground text-xs">
                    {stats.total_referred_applicants > 0
                      ? ((stats.verification_breakdown.REJECTED || 0) / stats.total_referred_applicants * 100).toFixed(1)
                      : "0.0"}% dari total
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Recent applicants list */}
          <Card>
            <CardHeader className="flex flex-row items-center justify-between">
              <div>
                <CardTitle>Daftar Pelamar Terbaru</CardTitle>
                <CardDescription>10 pelamar terakhir yang Anda rujuk</CardDescription>
              </div>
              <div className="flex gap-2">
                <Button variant="outline" size="sm" disabled>
                  <IconFileDownload className="size-4" />
                  Export
                </Button>
                <Button variant="outline" size="sm" asChild>
                  <Link to="/staff/pelamar">Lihat Semua</Link>
                </Button>
              </div>
            </CardHeader>
            <CardContent>
              {!applicants || applicants.results.length === 0 ? (
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
                        <TableHead>No. Telepon</TableHead>
                        <TableHead>Status Verifikasi</TableHead>
                        <TableHead>Terdaftar</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {applicants.results.slice(0, 10).map((applicant) => {
                        const profile = applicant.applicant_profile
                        return (
                          <TableRow key={applicant.id}>
                            <TableCell>
                              <div className="flex flex-col">
                                <Link 
                                  to={`/staff/pelamar/${applicant.id}`}
                                  className="font-medium hover:underline"
                                >
                                  {profile?.full_name || applicant.email}
                                </Link>
                                <span className="text-muted-foreground text-xs">
                                  {applicant.email}
                                </span>
                              </div>
                            </TableCell>
                            <TableCell>
                              <span className="text-sm">{profile?.nik || "-"}</span>
                            </TableCell>
                            <TableCell>
                              <span className="text-sm">{profile?.contact_phone || "-"}</span>
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

          {/* Summary insights */}
          <Card>
            <CardHeader>
              <CardTitle>Ringkasan & Wawasan</CardTitle>
              <CardDescription>Analisis performa rujukan Anda</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="rounded-lg border p-4">
                <h4 className="font-semibold">Performa Rujukan</h4>
                <p className="text-muted-foreground mt-2 text-sm">
                  Anda telah merujuk total <strong>{stats.total_referred_applicants}</strong> pelamar ke sistem KMS-Connect.
                  Dari jumlah tersebut, <strong>{stats.total_accepted}</strong> pelamar ({successRate}%) berhasil diterima,
                  dan <strong>{stats.total_submitted}</strong> pelamar ({pendingRate}%) masih menunggu proses verifikasi.
                </p>
              </div>

              {stats.total_referred_applicants > 0 && (
                <div className="rounded-lg border p-4">
                  <h4 className="font-semibold">Rekomendasi</h4>
                  <ul className="text-muted-foreground mt-2 space-y-1 text-sm">
                    {stats.total_submitted > 0 && (
                      <li>• Pantau status verifikasi {stats.total_submitted} pelamar yang masih pending</li>
                    )}
                    {(stats.verification_breakdown.DRAFT || 0) > 0 && (
                      <li>• Bantu {stats.verification_breakdown.DRAFT} pelamar untuk menyelesaikan profil mereka</li>
                    )}
                    {parseFloat(successRate) < 50 && stats.total_accepted > 0 && (
                      <li>• Tingkatkan kualitas rujukan untuk meningkatkan tingkat penerimaan</li>
                    )}
                    {parseFloat(successRate) >= 70 && (
                      <li>• Performa rujukan sangat baik! Pertahankan kualitas rujukan Anda</li>
                    )}
                  </ul>
                </div>
              )}
            </CardContent>
          </Card>
        </>
      )}
    </div>
  )
}
