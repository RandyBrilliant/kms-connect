/**
 * Company job listings page - read-only view for companies.
 */

import { useState } from "react"
import { IconBriefcase, IconSearch } from "@tabler/icons-react"
import { format } from "date-fns"
import { id } from "date-fns/locale"

import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
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
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { useCompanyJobsQuery } from "@/hooks/use-company-self-service-query"
import { usePageTitle } from "@/hooks/use-page-title"
import type { JobsListParams, JobStatus, EmploymentType } from "@/types/jobs"

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100]

function formatDate(value: string | null) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy", { locale: id })
}

function statusLabel(status: JobStatus) {
  switch (status) {
    case "DRAFT":
      return "Draf"
    case "OPEN":
      return "Dibuka"
    case "CLOSED":
      return "Ditutup"
    case "ARCHIVED":
      return "Diarsipkan"
    default:
      return status
  }
}

function statusVariant(status: JobStatus) {
  switch (status) {
    case "DRAFT":
      return "secondary"
    case "OPEN":
      return "default"
    case "CLOSED":
      return "outline"
    case "ARCHIVED":
      return "secondary"
    default:
      return "outline"
  }
}

function employmentLabel(type: EmploymentType) {
  switch (type) {
    case "FULL_TIME":
      return "Penuh waktu"
    case "PART_TIME":
      return "Paruh waktu"
    case "CONTRACT":
      return "Kontrak"
    case "INTERNSHIP":
      return "Magang"
    default:
      return type
  }
}

export function CompanyJobListingsPage() {
  usePageTitle("Lowongan Kerja Saya")
  const [params, setParams] = useState<JobsListParams>({
    page: 1,
    page_size: 20,
    search: "",
    ordering: "-posted_at",
  })
  const [searchInput, setSearchInput] = useState("")

  const { data, isLoading, isError, error } = useCompanyJobsQuery(params)

  const handleSearch = () => {
    setParams((p) => ({
      ...p,
      search: searchInput.trim() || undefined,
      page: 1,
    }))
  }

  const handleFilterChange = <K extends keyof JobsListParams>(
    key: K,
    value: JobsListParams[K]
  ) => {
    setParams((p) => ({ ...p, [key]: value, page: 1 }))
  }

  const handlePageChange = (page: number) => {
    setParams((p) => ({ ...p, page }))
  }

  const totalPages = data ? Math.ceil(data.count / (params.page_size || 20)) : 0

  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: "/company" },
          { label: "Lowongan Kerja Saya" },
        ]}
      />
      <h1 className="text-2xl font-bold">Lowongan Kerja Saya</h1>
      <p className="text-muted-foreground">
        Daftar lowongan kerja yang dipublikasikan oleh perusahaan Anda (hanya tampilan).
      </p>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <IconBriefcase className="size-5" />
            Daftar Lowongan
          </CardTitle>
          <CardDescription>
            Anda dapat melihat lowongan kerja yang telah dipublikasikan.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Filters */}
          <div className="flex flex-col gap-4 sm:flex-row sm:items-end">
            <div className="flex-1 space-y-2">
              <Label htmlFor="search">Cari</Label>
              <div className="flex gap-2">
                <Input
                  id="search"
                  placeholder="Cari judul, deskripsi..."
                  value={searchInput}
                  onChange={(e) => setSearchInput(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") handleSearch()
                  }}
                />
                <Button onClick={handleSearch} size="icon" variant="secondary">
                  <IconSearch className="size-4" />
                </Button>
              </div>
            </div>
            <div className="flex gap-2">
              <div className="space-y-2">
                <Label htmlFor="status">Status</Label>
                <Select
                  value={params.status || "ALL"}
                  onValueChange={(v) =>
                    handleFilterChange("status", v === "ALL" ? undefined : (v as JobStatus))
                  }
                >
                  <SelectTrigger id="status" className="w-[140px]">
                    <SelectValue placeholder="Semua Status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="ALL">Semua Status</SelectItem>
                    <SelectItem value="DRAFT">Draf</SelectItem>
                    <SelectItem value="OPEN">Dibuka</SelectItem>
                    <SelectItem value="CLOSED">Ditutup</SelectItem>
                    <SelectItem value="ARCHIVED">Diarsipkan</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="employment_type">Jenis</Label>
                <Select
                  value={params.employment_type || "ALL"}
                  onValueChange={(v) =>
                    handleFilterChange(
                      "employment_type",
                      v === "ALL" ? undefined : (v as EmploymentType)
                    )
                  }
                >
                  <SelectTrigger id="employment_type" className="w-[140px]">
                    <SelectValue placeholder="Semua Jenis" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="ALL">Semua Jenis</SelectItem>
                    <SelectItem value="FULL_TIME">Penuh waktu</SelectItem>
                    <SelectItem value="PART_TIME">Paruh waktu</SelectItem>
                    <SelectItem value="CONTRACT">Kontrak</SelectItem>
                    <SelectItem value="INTERNSHIP">Magang</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="page_size">Per Halaman</Label>
                <Select
                  value={(params.page_size || 20).toString()}
                  onValueChange={(v) => handleFilterChange("page_size", Number(v))}
                >
                  <SelectTrigger id="page_size" className="w-[100px]">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {PAGE_SIZE_OPTIONS.map((size) => (
                      <SelectItem key={size} value={size.toString()}>
                        {size}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
          </div>

          {/* Table */}
          <div className="rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Judul & Perusahaan</TableHead>
                  <TableHead>Lokasi</TableHead>
                  <TableHead>Jenis</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Tanggal Posting</TableHead>
                  <TableHead>Batas Lamaran</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {isLoading ? (
                  <TableRow>
                    <TableCell colSpan={6} className="h-24 text-center">
                      Memuat data...
                    </TableCell>
                  </TableRow>
                ) : isError ? (
                  <TableRow>
                    <TableCell colSpan={6} className="h-24 text-center text-destructive">
                      Error: {error?.message || "Gagal memuat data"}
                    </TableCell>
                  </TableRow>
                ) : !data?.results.length ? (
                  <TableRow>
                    <TableCell colSpan={6} className="h-24 text-center text-muted-foreground">
                      Tidak ada lowongan kerja.
                    </TableCell>
                  </TableRow>
                ) : (
                  data.results.map((job) => (
                    <TableRow key={job.id}>
                      <TableCell>
                        <div className="flex items-center gap-2">
                          <IconBriefcase className="text-muted-foreground size-4" />
                          <div className="flex flex-col">
                            <span className="font-medium line-clamp-2">{job.title}</span>
                            {job.company_name && (
                              <span className="text-muted-foreground text-xs">
                                {job.company_name}
                              </span>
                            )}
                          </div>
                        </div>
                      </TableCell>
                      <TableCell>
                        <div className="text-sm">
                          {job.location_country}
                          {job.location_city && (
                            <>
                              <br />
                              <span className="text-muted-foreground text-xs">
                                {job.location_city}
                              </span>
                            </>
                          )}
                        </div>
                      </TableCell>
                      <TableCell>
                        <span className="text-sm">{employmentLabel(job.employment_type)}</span>
                      </TableCell>
                      <TableCell>
                        <Badge variant={statusVariant(job.status)}>
                          {statusLabel(job.status)}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <span className="text-sm">{formatDate(job.posted_at)}</span>
                      </TableCell>
                      <TableCell>
                        <span className="text-sm">{formatDate(job.deadline)}</span>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </div>

          {/* Pagination */}
          {data && data.count > 0 && (
            <div className="flex items-center justify-between">
              <div className="text-muted-foreground text-sm">
                Menampilkan {((params.page || 1) - 1) * (params.page_size || 20) + 1} -{" "}
                {Math.min((params.page || 1) * (params.page_size || 20), data.count)} dari {data.count}{" "}
                lowongan
              </div>
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handlePageChange((params.page || 1) - 1)}
                  disabled={(params.page || 1) <= 1}
                >
                  Sebelumnya
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handlePageChange((params.page || 1) + 1)}
                  disabled={(params.page || 1) >= totalPages}
                >
                  Selanjutnya
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
