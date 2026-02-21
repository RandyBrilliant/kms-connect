/**
 * Staff job listings page - shows all available job listings (read-only).
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
import { useStaffJobsQuery } from "@/hooks/use-staff-self-service-query"
import { usePageTitle } from "@/hooks/use-page-title"
import type { JobStatus, EmploymentType } from "@/types/jobs"

function formatDate(value: string | null | undefined) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy", { locale: id })
}

function jobStatusLabel(status: string) {
  switch (status) {
    case "OPEN":
      return "Buka"
    case "CLOSED":
      return "Tutup"
    case "DRAFT":
      return "Draf"
    default:
      return status
  }
}

function jobStatusVariant(status: string) {
  switch (status) {
    case "OPEN":
      return "default"
    case "CLOSED":
      return "outline"
    case "DRAFT":
      return "secondary"
    default:
      return "outline"
  }
}

function employmentTypeLabel(type: string) {
  switch (type) {
    case "FULL_TIME":
      return "Full Time"
    case "PART_TIME":
      return "Part Time"
    case "CONTRACT":
      return "Kontrak"
    case "INTERNSHIP":
      return "Magang"
    default:
      return type
  }
}

export function StaffJobListingsPage() {
  usePageTitle("Lowongan Kerja - Staff")
  
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState("")
  const [statusFilter, setStatusFilter] = useState<JobStatus | "all">("all")
  const [employmentTypeFilter, setEmploymentTypeFilter] = useState<EmploymentType | "all">("all")

  const { data, isLoading, isError } = useStaffJobsQuery({
    page,
    search: search || undefined,
    status: statusFilter !== "all" ? statusFilter : undefined,
    employment_type: employmentTypeFilter !== "all" ? employmentTypeFilter : undefined,
  })

  const handlePageChange = (newPage: number) => {
    setPage(newPage)
  }

  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:gap-6 md:px-8 md:py-8">
      <div>
        <h1 className="text-2xl font-bold">Lowongan Kerja</h1>
        <p className="text-muted-foreground">
          Daftar lowongan kerja yang tersedia di sistem.
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Daftar Lowongan Kerja</CardTitle>
          <CardDescription>
            Lihat semua lowongan kerja yang tersedia untuk dirujuk kepada pelamar.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Filters */}
          <div className="flex flex-col gap-3 @xl/main:flex-row @xl/main:items-center">
            <div className="relative flex-1">
              <IconSearch className="text-muted-foreground absolute left-2.5 top-2.5 size-4" />
              <Input
                placeholder="Cari lowongan..."
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
                setStatusFilter(value as JobStatus | "all")
                setPage(1)
              }}
            >
              <SelectTrigger className="w-full @xl/main:w-[180px]">
                <SelectValue placeholder="Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Semua Status</SelectItem>
                <SelectItem value="OPEN">Buka</SelectItem>
                <SelectItem value="CLOSED">Tutup</SelectItem>
                <SelectItem value="DRAFT">Draf</SelectItem>
              </SelectContent>
            </Select>
            <Select
              value={employmentTypeFilter}
              onValueChange={(value) => {
                setEmploymentTypeFilter(value as EmploymentType | "all")
                setPage(1)
              }}
            >
              <SelectTrigger className="w-full @xl/main:w-[180px]">
                <SelectValue placeholder="Tipe Pekerjaan" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Semua Tipe</SelectItem>
                <SelectItem value="FULL_TIME">Full Time</SelectItem>
                <SelectItem value="PART_TIME">Part Time</SelectItem>
                <SelectItem value="CONTRACT">Kontrak</SelectItem>
                <SelectItem value="INTERNSHIP">Magang</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Table */}
          {isLoading && (
            <p className="text-muted-foreground text-center text-sm">Memuat data...</p>
          )}

          {isError && (
            <p className="text-destructive text-center text-sm">Gagal memuat data lowongan kerja.</p>
          )}

          {!isLoading && !isError && data && (
            <>
              <div className="rounded-md border">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Posisi & Perusahaan</TableHead>
                      <TableHead>Tipe</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Tanggal Tutup</TableHead>
                      <TableHead className="text-right">Aksi</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {data.results.length === 0 ? (
                      <TableRow>
                        <TableCell colSpan={5} className="text-center">
                          <p className="text-muted-foreground text-sm">
                            Tidak ada lowongan kerja ditemukan.
                          </p>
                        </TableCell>
                      </TableRow>
                    ) : (
                      data.results.map((job) => (
                        <TableRow key={job.id}>
                          <TableCell>
                            <div className="flex flex-col">
                              <span className="font-medium">{job.title}</span>
                              <span className="text-muted-foreground text-xs">
                                {job.company_name || "-"}
                              </span>
                            </div>
                          </TableCell>
                          <TableCell>
                            <Badge variant="outline">
                              {employmentTypeLabel(job.employment_type)}
                            </Badge>
                          </TableCell>
                          <TableCell>
                            <Badge variant={jobStatusVariant(job.status)}>
                              {jobStatusLabel(job.status)}
                            </Badge>
                          </TableCell>
                          <TableCell>
                            <span className="text-sm">{formatDate(job.deadline)}</span>
                          </TableCell>
                          <TableCell className="text-right">
                            <Button variant="ghost" size="sm" asChild>
                              <Link to={`/lowongan-kerja/${job.id}`}>
                                <IconEye className="size-4" />
                                Lihat
                              </Link>
                            </Button>
                          </TableCell>
                        </TableRow>
                      ))
                    )}
                  </TableBody>
                </Table>
              </div>

              {/* Pagination */}
              {data.count > 0 && (
                <div className="flex items-center justify-between">
                  <p className="text-muted-foreground text-sm">
                    Menampilkan {(page - 1) * 10 + 1} hingga{" "}
                    {Math.min(page * 10, data.count)} dari {data.count} lowongan kerja
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
