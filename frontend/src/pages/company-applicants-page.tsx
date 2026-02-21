/**
 * Company applicants page - read-only view of applicants who applied to company's jobs.
 */

import { useState } from "react"
import { IconUsers, IconSearch, IconEye } from "@tabler/icons-react"
import { format } from "date-fns"
import { id } from "date-fns/locale"
import { Link } from "react-router-dom"

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
import { useCompanyApplicantsQuery } from "@/hooks/use-company-self-service-query"
import { usePageTitle } from "@/hooks/use-page-title"

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100]

function formatDate(value: string | null | undefined) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy", { locale: id })
}

export function CompanyApplicantsPage() {
  usePageTitle("Pelamar")
  const [params, setParams] = useState<{
    page: number
    page_size: number
    search?: string
    ordering: string
  }>({
    page: 1,
    page_size: 20,
    search: "",
    ordering: "-date_joined",
  })
  const [searchInput, setSearchInput] = useState("")

  const { data, isLoading, isError, error } = useCompanyApplicantsQuery(params)

  const handleSearch = () => {
    setParams((p) => ({
      ...p,
      search: searchInput.trim() || undefined,
      page: 1,
    }))
  }

  const handleFilterChange = (key: string, value: unknown) => {
    setParams((p) => ({ ...p, [key]: value, page: 1 }))
  }

  const handlePageChange = (page: number) => {
    setParams((p) => ({ ...p, page }))
  }

  const totalPages = data ? Math.ceil(data.count / params.page_size) : 0

  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: "/company" },
          { label: "Pelamar" },
        ]}
      />
      <h1 className="text-2xl font-bold">Pelamar</h1>
      <p className="text-muted-foreground">
        Daftar pelamar yang telah melamar ke lowongan pekerjaan Anda (hanya tampilan).
      </p>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <IconUsers className="size-5" />
            Daftar Pelamar
          </CardTitle>
          <CardDescription>
            Anda dapat melihat data pelamar yang melamar ke lowongan kerja perusahaan Anda.
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
                  placeholder="Cari nama, email, NIK, telepon..."
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
                <Label htmlFor="page_size">Per Halaman</Label>
                <Select
                  value={params.page_size.toString()}
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
                  <TableHead>Nama & Email</TableHead>
                  <TableHead>NIK</TableHead>
                  <TableHead>Telepon</TableHead>
                  <TableHead>Status Verifikasi</TableHead>
                  <TableHead>Terdaftar</TableHead>
                  <TableHead>Aksi</TableHead>
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
                      Belum ada pelamar.
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
                          <span className="text-sm">
                            {profile?.nik || "-"}
                          </span>
                        </TableCell>
                        <TableCell>
                          <span className="text-sm">
                            {profile?.contact_phone || "-"}
                          </span>
                        </TableCell>
                        <TableCell>
                          {profile?.verification_status === "ACCEPTED" && (
                            <Badge variant="default">Diterima</Badge>
                          )}
                          {profile?.verification_status === "SUBMITTED" && (
                            <Badge variant="secondary">Dikirim</Badge>
                          )}
                          {profile?.verification_status === "REJECTED" && (
                            <Badge variant="destructive">Ditolak</Badge>
                          )}
                          {profile?.verification_status === "DRAFT" && (
                            <Badge variant="outline">Draf</Badge>
                          )}
                          {!profile?.verification_status && (
                            <Badge variant="outline">-</Badge>
                          )}
                        </TableCell>
                        <TableCell>
                          <span className="text-sm">{formatDate(applicant.date_joined)}</span>
                        </TableCell>
                        <TableCell>
                          <Button
                            size="sm"
                            variant="ghost"
                            asChild
                          >
                            <Link to={`/company/pelamar/${applicant.id}`}>
                              <IconEye className="size-4" />
                              <span className="sr-only">Lihat detail</span>
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
          {data && data.count > 0 && (
            <div className="flex items-center justify-between">
              <div className="text-muted-foreground text-sm">
                Menampilkan {(params.page - 1) * params.page_size + 1} -{" "}
                {Math.min(params.page * params.page_size, data.count)} dari {data.count}{" "}
                pelamar
              </div>
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handlePageChange(params.page - 1)}
                  disabled={params.page <= 1}
                >
                  Sebelumnya
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handlePageChange(params.page + 1)}
                  disabled={params.page >= totalPages}
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
