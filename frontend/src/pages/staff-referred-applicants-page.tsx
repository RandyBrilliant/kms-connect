/**
 * Staff referred applicants page - shows applicants referred by this staff member (read-only).
 */

import { useState } from "react"
import { IconEye, IconSearch } from "@tabler/icons-react"
import { Link } from "react-router-dom"
import { format } from "date-fns"
import { id } from "date-fns/locale"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { useStaffReferredApplicantsQuery } from "@/hooks/use-staff-self-service-query"
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

export function StaffReferredApplicantsPage() {
  usePageTitle("Pelamar Rujukan - Staff")
  
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState("")
  const [statusFilter, setStatusFilter] = useState<string>("all")

  const { data, isLoading, isError } = useStaffReferredApplicantsQuery({
    page,
    search: search || undefined,
    verification_status: statusFilter !== "all" ? statusFilter : undefined,
  })

  const handlePageChange = (newPage: number) => {
    setPage(newPage)
  }

  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:gap-6 md:px-8 md:py-8">
      <div>
        <h1 className="text-2xl font-bold">Pelamar Rujukan Saya</h1>
        <p className="text-muted-foreground">
          Daftar pelamar yang Anda rujuk ke sistem KMS-Connect.
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Daftar Pelamar</CardTitle>
          <CardDescription>
            Lihat dan pantau pelamar yang Anda rujuk beserta status verifikasi mereka.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Filters */}
          <div className="flex flex-col gap-3 @xl/main:flex-row @xl/main:items-center">
            <div className="relative flex-1">
              <IconSearch className="text-muted-foreground absolute left-2.5 top-2.5 size-4" />
              <Input
                placeholder="Cari pelamar (nama, email, NIK)..."
                value={search}
                onChange={(e) => {
                  setSearch(e.target.value)
                  setPage(1)
                }}
                className="pl-8"
              />
            </div>
            <Select
              value={statusFilter}
              onValueChange={(value) => {
                setStatusFilter(value)
                setPage(1)
              }}
            >
              <SelectTrigger className="w-full @xl/main:w-[200px]">
                <SelectValue placeholder="Status Verifikasi" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Semua Status</SelectItem>
                <SelectItem value="DRAFT">Draf</SelectItem>
                <SelectItem value="SUBMITTED">Dikirim</SelectItem>
                <SelectItem value="ACCEPTED">Diterima</SelectItem>
                <SelectItem value="REJECTED">Ditolak</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Table */}
          {isLoading && (
            <p className="text-muted-foreground text-center text-sm">Memuat data...</p>
          )}

          {isError && (
            <p className="text-destructive text-center text-sm">Gagal memuat data pelamar.</p>
          )}

          {!isLoading && !isError && data && (
            <>
              <div className="rounded-md border">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Nama & Email</TableHead>
                      <TableHead>NIK</TableHead>
                      <TableHead>No. Telepon</TableHead>
                      <TableHead>Status Verifikasi</TableHead>
                      <TableHead>Terdaftar</TableHead>
                      <TableHead className="text-right">Aksi</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {data.results.length === 0 ? (
                      <TableRow>
                        <TableCell colSpan={6} className="text-center">
                          <p className="text-muted-foreground text-sm">
                            Tidak ada pelamar ditemukan.
                          </p>
                        </TableCell>
                      </TableRow>
                    ) : (
                      data.results.map((applicant) => {
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
                            <TableCell className="text-right">
                              <Button variant="ghost" size="sm" asChild>
                              <Link to={`/staff-portal/pelamar/${applicant.id}`}>
                                  <IconEye className="size-4" />
                                  Lihat
                                </Link>
                              </Button>
                            </TableCell>
                          </TableRow>
                        )
                      })
                    )}
                  </TableBody>
                </Table>
              </div>

              {/* Pagination */}
              {data.count > 0 && (
                <div className="flex items-center justify-between">
                  <p className="text-muted-foreground text-sm">
                    Menampilkan {(page - 1) * 10 + 1} hingga{" "}
                    {Math.min(page * 10, data.count)} dari {data.count} pelamar
                  </p>
                  <div className="flex gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      disabled={!data.previous}
                      onClick={() => handlePageChange(page - 1)}
                    >
                      Sebelumnya
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      disabled={!data.next}
                      onClick={() => handlePageChange(page + 1)}
                    >
                      Selanjutnya
                    </Button>
                  </div>
                </div>
              )}
            </>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
