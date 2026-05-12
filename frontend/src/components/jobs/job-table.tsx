/**
 * Jobs table with server-side pagination, search, and filters.
 * Layout aligned with ApplicantTable / CompanyTable.
 */

import { useState, useMemo, useCallback } from "react"
import { Link, useNavigate } from "react-router-dom"
import {
  flexRender,
  getCoreRowModel,
  useReactTable,
  type ColumnDef,
} from "@tanstack/react-table"
import {
  IconArrowsSort,
  IconBriefcase,
  IconChevronLeft,
  IconChevronRight,
  IconLayoutRows,
  IconPencil,
  IconPlus,
  IconSearch,
  IconSortAscending,
  IconSortDescending,
  IconTrash,
} from "@tabler/icons-react"
import { format } from "date-fns"
import { id } from "date-fns/locale"

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
import { useJobsQuery, useDeleteJobMutation } from "@/hooks/use-jobs-query"
import { useIsMobile } from "@/hooks/use-mobile"
import { toast } from "@/lib/toast"
import { cn } from "@/lib/utils"
import type { JobItem, JobsListParams, JobStatus, EmploymentType } from "@/types/jobs"

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100]

const JOB_FILTER_TRIGGER_CLASS =
  "h-9 w-full min-w-0 cursor-pointer shadow-none sm:min-h-0"

/** DRF ordering — LowonganKerjaViewSet.ordering_fields */
const SORT_FIELD = {
  judul: "title",
  diposting: "posted_at",
  deadline: "deadline",
} as const

interface JobTableProps {
  basePath: string
  readOnly?: boolean
}

function formatDate(value: string | null) {
  if (!value) return "—"
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

function SortableColumnHead({
  field,
  label,
  ordering,
  onSort,
  className,
}: {
  field: string
  label: string
  ordering?: string
  onSort: (field: string) => void
  className?: string
}) {
  const asc = field
  const desc = `-${field}`
  const isAsc = ordering === asc
  const isDesc = ordering === desc
  const isActive = isAsc || isDesc

  return (
    <button
      type="button"
      className={cn(
        "-mx-1 inline-flex max-w-full min-w-0 items-center gap-2 rounded-lg px-1.5 py-1 text-left text-sm font-semibold transition-colors",
        "text-muted-foreground hover:bg-muted/80 hover:text-foreground",
        isActive && "text-foreground",
        className
      )}
      onClick={() => onSort(field)}
      title={`Urutkan: ${label}`}
      aria-sort={isAsc ? "ascending" : isDesc ? "descending" : "none"}
    >
      <span className="min-w-0 truncate">{label}</span>
      <span
        className={cn(
          "flex size-7 shrink-0 items-center justify-center rounded-md border shadow-sm transition-colors",
          isActive
            ? "border-primary/30 bg-primary/10 text-primary"
            : "border-border/50 bg-background/80 text-muted-foreground/80"
        )}
        aria-hidden
      >
        {isAsc ? (
          <IconSortAscending className="size-3.5" stroke={2} />
        ) : isDesc ? (
          <IconSortDescending className="size-3.5" stroke={2} />
        ) : (
          <IconArrowsSort className="size-3.5 opacity-75" stroke={1.75} />
        )}
      </span>
    </button>
  )
}

function jobTableHeadClass(columnId: string) {
  return cn(
    "h-11 border-border/50 px-3 py-2 text-left align-middle first:pl-4 last:pr-4 sm:first:pl-5 sm:last:pr-5",
    columnId === "actions" && "w-[1%] whitespace-nowrap",
    (columnId === "diposting" || columnId === "deadline") && "tabular-nums"
  )
}

function jobTableCellClass(columnId: string) {
  return cn(
    "border-border/40 px-3 py-2.5 align-middle first:pl-4 last:pr-4 sm:first:pl-5 sm:last:pr-5",
    columnId === "judul" && "max-w-[min(24rem,36vw)] whitespace-normal",
    (columnId === "diposting" || columnId === "deadline") &&
      "text-muted-foreground tabular-nums text-sm",
    columnId === "actions" && "text-right"
  )
}

export function JobTable({ basePath, readOnly = false }: JobTableProps) {
  const navigate = useNavigate()
  const isMobile = useIsMobile()
  const [params, setParams] = useState<JobsListParams>({
    page: 1,
    page_size: 20,
    ordering: "-posted_at",
  })
  const [searchInput, setSearchInput] = useState("")

  const { data, isLoading, isError, error } = useJobsQuery(params)
  const deleteMutation = useDeleteJobMutation()

  const handleSearch = useCallback(() => {
    setParams((p) => ({
      ...p,
      search: searchInput.trim() || undefined,
      page: 1,
    }))
  }, [searchInput])

  const handleFilterChange = useCallback(
    <K extends keyof JobsListParams>(key: K, value: JobsListParams[K]) => {
      setParams((p) => ({ ...p, [key]: value, page: 1 }))
    },
    []
  )

  const handlePageChange = (page: number) => {
    setParams((p) => ({ ...p, page }))
  }

  const handleSortColumn = useCallback((field: string) => {
    setParams((p) => {
      const cur = p.ordering
      const asc = field
      const desc = `-${field}`
      const next = cur === asc ? desc : cur === desc ? asc : asc
      return { ...p, ordering: next, page: 1 }
    })
  }, [])

  const handleDelete = useCallback(
    async (item: JobItem) => {
      if (
        !window.confirm(
          `Hapus lowongan "${item.title}"? Tindakan ini tidak dapat dibatalkan.`
        )
      ) {
        return
      }
      try {
        await deleteMutation.mutateAsync(item.id)
        toast.success("Lowongan dihapus", "Data lowongan berhasil dihapus")
      } catch {
        toast.error("Gagal menghapus", "Coba lagi nanti")
      }
    },
    [deleteMutation]
  )

  const columns = useMemo<ColumnDef<JobItem>[]>(
    () => {
      const cols: ColumnDef<JobItem>[] = [
        {
          id: "judul",
          accessorKey: "title",
          header: () => (
            <SortableColumnHead
              field={SORT_FIELD.judul}
              label="Judul"
              ordering={params.ordering}
              onSort={handleSortColumn}
            />
          ),
          cell: ({ row }) => (
            <div className="flex items-start gap-2">
              <IconBriefcase className="text-muted-foreground mt-0.5 size-4 shrink-0" />
              <div className="min-w-0 flex flex-col gap-0.5">
                <span className="font-medium leading-snug">{row.original.title}</span>
                {row.original.company_name ? (
                  <span className="text-muted-foreground text-xs">
                    {row.original.company_name}
                  </span>
                ) : null}
              </div>
            </div>
          ),
        },
        {
          id: "employment_type",
          accessorKey: "employment_type",
          header: "Tipe",
          cell: ({ row }) => (
            <Badge variant="outline" className="border-border/80 shadow-sm">
              {employmentLabel(row.original.employment_type)}
            </Badge>
          ),
        },
        {
          id: "location",
          accessorKey: "location",
          header: "Lokasi",
          cell: ({ row }) => {
            const { location_city, location_country } = row.original
            if (!location_city && !location_country) return "—"
            if (!location_city) return location_country
            if (!location_country) return location_city
            return `${location_city}, ${location_country}`
          },
        },
        {
          id: "status",
          accessorKey: "status",
          header: "Status",
          cell: ({ row }) => {
            const status = row.original.status
            let variant: "default" | "secondary" | "outline" = "outline"
            if (status === "OPEN") variant = "default"
            if (status === "DRAFT") variant = "secondary"
            return (
              <Badge variant={variant} className="shadow-sm">
                {statusLabel(status)}
              </Badge>
            )
          },
        },
        {
          id: "diposting",
          accessorKey: "posted_at",
          header: () => (
            <SortableColumnHead
              field={SORT_FIELD.diposting}
              label="Diposting"
              ordering={params.ordering}
              onSort={handleSortColumn}
            />
          ),
          cell: ({ row }) => formatDate(row.original.posted_at),
        },
        {
          id: "deadline",
          accessorKey: "deadline",
          header: () => (
            <SortableColumnHead
              field={SORT_FIELD.deadline}
              label="Batas akhir"
              ordering={params.ordering}
              onSort={handleSortColumn}
            />
          ),
          cell: ({ row }) => formatDate(row.original.deadline),
        },
      ]
      if (!readOnly) {
        cols.push({
          id: "actions",
          header: "",
          cell: ({ row }) => {
            const item = row.original
            return (
              <div className="flex items-center justify-end gap-1">
                <Button
                  variant="outline"
                  size="icon"
                  className="size-8 cursor-pointer rounded-lg border-border/80 bg-background/80 shadow-sm hover:bg-muted/60"
                  onClick={(e) => {
                    e.stopPropagation()
                    navigate(`${basePath}/${item.id}/edit`)
                  }}
                  title="Edit"
                >
                  <IconPencil className="size-4" />
                  <span className="sr-only">Edit</span>
                </Button>
                <Button
                  variant="outline"
                  size="icon"
                  className="size-8 cursor-pointer rounded-lg border-border/80 bg-background/80 text-destructive shadow-sm hover:bg-destructive/10 hover:text-destructive"
                  onClick={(e) => {
                    e.stopPropagation()
                    handleDelete(item)
                  }}
                  title="Hapus"
                >
                  <IconTrash className="size-4" />
                  <span className="sr-only">Hapus</span>
                </Button>
              </div>
            )
          },
        })
      }
      return cols
    },
    [basePath, navigate, params.ordering, handleSortColumn, handleDelete, readOnly]
  )

  const table = useReactTable({
    data: data?.results ?? [],
    columns,
    getCoreRowModel: getCoreRowModel(),
    manualPagination: true,
    pageCount: data ? Math.ceil(data.count / (params.page_size ?? 20)) : 0,
  })

  const pageCount = data ? Math.ceil(data.count / (params.page_size ?? 20)) : 0
  const currentPage = params.page ?? 1
  const pageSize = params.page_size ?? 20
  const paginationFooter =
    data && data.count > 0
      ? {
          rangeStart: (currentPage - 1) * pageSize + 1,
          rangeEnd: Math.min(currentPage * pageSize, data.count),
          totalPages: pageCount || 1,
          totalCount: data.count,
        }
      : null

  if (isError) {
    return (
      <div className="rounded-xl border border-destructive/50 bg-destructive/5 p-4 text-center shadow-sm">
        <p className="text-destructive text-sm">
          Gagal memuat data: {(error as Error).message}
        </p>
      </div>
    )
  }

  const goDetail = (id: number) => navigate(`${basePath}/${id}`)

  return (
    <div className="flex flex-col gap-4">
      <section
        aria-label="Pencarian dan filter lowongan"
        className="overflow-hidden rounded-xl border bg-card text-card-foreground shadow-sm"
      >
        <div className="border-b bg-muted/30 px-4 py-3 sm:px-5 sm:py-3.5 dark:bg-muted/15">
          <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between lg:gap-4">
            <div className="flex min-w-0 flex-1 flex-col gap-2 sm:flex-row sm:items-center sm:gap-2">
              <div className="relative min-w-0 flex-1">
                <IconSearch className="text-muted-foreground pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2" />
                <Input
                  type="search"
                  enterKeyHint="search"
                  autoComplete="off"
                  placeholder="Cari judul, perusahaan, atau lokasi…"
                  value={searchInput}
                  onChange={(e) => setSearchInput(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && handleSearch()}
                  className="h-9 border-border/80 bg-background pl-9 shadow-sm focus-visible:ring-1"
                />
              </div>
              <Button
                type="button"
                onClick={handleSearch}
                variant="secondary"
                className="h-9 shrink-0 cursor-pointer px-5 sm:w-auto"
              >
                Cari
              </Button>
            </div>
            {!readOnly && (
              <div className="flex flex-col gap-2 sm:flex-row sm:justify-end lg:shrink-0">
                <Button asChild className="h-9 cursor-pointer shadow-sm sm:w-auto">
                  <Link to={`${basePath}/new`} className="cursor-pointer">
                    <IconPlus className="mr-2 size-4 shrink-0" />
                    {isMobile ? "Tambah" : "Tambah Lowongan"}
                  </Link>
                </Button>
              </div>
            )}
          </div>
        </div>

        <div className="px-4 py-3 sm:px-5 sm:py-4">
          <p className="text-muted-foreground sr-only">Filter daftar lowongan</p>
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-12 xl:gap-2">
            <div className="min-w-0 sm:col-span-1 xl:col-span-6">
              <Select
                value={params.status ?? "ALL"}
                onValueChange={(v) =>
                  handleFilterChange(
                    "status",
                    v === "ALL" ? "ALL" : (v as JobStatus)
                  )
                }
              >
                <SelectTrigger className={JOB_FILTER_TRIGGER_CLASS}>
                  <SelectValue placeholder="Status lowongan" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="ALL">Semua status</SelectItem>
                  <SelectItem value="DRAFT">Draf</SelectItem>
                  <SelectItem value="OPEN">Dibuka</SelectItem>
                  <SelectItem value="CLOSED">Ditutup</SelectItem>
                  <SelectItem value="ARCHIVED">Diarsipkan</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="min-w-0 sm:col-span-1 xl:col-span-6">
              <Select
                value={params.employment_type ?? "ALL"}
                onValueChange={(v) =>
                  handleFilterChange(
                    "employment_type",
                    v === "ALL" ? "ALL" : (v as EmploymentType)
                  )
                }
              >
                <SelectTrigger className={JOB_FILTER_TRIGGER_CLASS}>
                  <SelectValue placeholder="Jenis pekerjaan" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="ALL">Semua jenis</SelectItem>
                  <SelectItem value="FULL_TIME">Penuh waktu</SelectItem>
                  <SelectItem value="PART_TIME">Paruh waktu</SelectItem>
                  <SelectItem value="CONTRACT">Kontrak</SelectItem>
                  <SelectItem value="INTERNSHIP">Magang</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        </div>
      </section>

      {isMobile ? (
        <div className="flex flex-col gap-3">
          {isLoading ? (
            <div className="flex min-h-[12rem] items-center justify-center rounded-xl border border-border/60 bg-muted/10 shadow-sm">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : data?.results && data.results.length > 0 ? (
            data.results.map((job) => (
              <article
                key={job.id}
                role="button"
                tabIndex={0}
                className="rounded-xl border border-border/60 bg-card p-4 text-left shadow-sm transition-colors hover:border-border hover:bg-muted/15"
                onClick={() => goDetail(job.id)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" || e.key === " ") {
                    e.preventDefault()
                    goDetail(job.id)
                  }
                }}
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0 flex-1 space-y-3">
                    <div className="flex items-start gap-2.5">
                      <IconBriefcase className="text-muted-foreground mt-0.5 size-5 shrink-0" />
                      <div className="min-w-0">
                        <p className="font-medium leading-snug">{job.title}</p>
                        {job.company_name ? (
                          <p className="text-muted-foreground mt-0.5 text-sm">
                            {job.company_name}
                          </p>
                        ) : null}
                      </div>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      <Badge variant="outline" className="text-xs">
                        {employmentLabel(job.employment_type)}
                      </Badge>
                      {(() => {
                        const status = job.status
                        let variant: "default" | "secondary" | "outline" = "outline"
                        if (status === "OPEN") variant = "default"
                        if (status === "DRAFT") variant = "secondary"
                        return (
                          <Badge variant={variant} className="text-xs">
                            {statusLabel(status)}
                          </Badge>
                        )
                      })()}
                    </div>
                    <p className="text-muted-foreground text-sm">
                      {(() => {
                        const { location_city, location_country } = job
                        if (!location_city && !location_country) return "—"
                        if (!location_city) return location_country
                        if (!location_country) return location_city
                        return `${location_city}, ${location_country}`
                      })()}
                    </p>
                    <div className="grid grid-cols-2 gap-2 border-t border-border/50 pt-3 text-xs">
                      <div>
                        <span className="text-muted-foreground font-medium">Diposting</span>
                        <p className="tabular-nums">{formatDate(job.posted_at)}</p>
                      </div>
                      <div>
                        <span className="text-muted-foreground font-medium">Batas akhir</span>
                        <p className="tabular-nums">{formatDate(job.deadline)}</p>
                      </div>
                    </div>
                  </div>
                  {!readOnly && (
                    <div
                      className="flex shrink-0 flex-col gap-1.5"
                      onClick={(e) => e.stopPropagation()}
                    >
                      <Button
                        variant="outline"
                        size="icon"
                        className="size-9 cursor-pointer rounded-lg border-border/80 bg-background/80 shadow-sm"
                        onClick={() => navigate(`${basePath}/${job.id}/edit`)}
                        title="Edit"
                      >
                        <IconPencil className="size-4" />
                      </Button>
                      <Button
                        variant="outline"
                        size="icon"
                        className="size-9 cursor-pointer rounded-lg border-border/80 text-destructive shadow-sm hover:bg-destructive/10"
                        onClick={() => handleDelete(job)}
                        title="Hapus"
                      >
                        <IconTrash className="size-4" />
                      </Button>
                    </div>
                  )}
                </div>
              </article>
            ))
          ) : (
            <div className="rounded-xl border border-border/60 border-dashed bg-muted/10 p-10 text-center shadow-sm">
              <p className="text-muted-foreground text-sm">Tidak ada data lowongan.</p>
            </div>
          )}
        </div>
      ) : (
        <div className="overflow-hidden rounded-xl border border-border/60 bg-card text-card-foreground shadow-sm">
          {isLoading ? (
            <div className="flex min-h-[14rem] items-center justify-center">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : (
            <Table className="border-collapse">
              <TableHeader>
                {table.getHeaderGroups().map((headerGroup) => (
                  <TableRow
                    key={headerGroup.id}
                    className="border-border/60 bg-muted/35 hover:bg-muted/35"
                  >
                    {headerGroup.headers.map((header) => (
                      <TableHead
                        key={header.id}
                        className={jobTableHeadClass(header.column.id)}
                      >
                        {header.isPlaceholder
                          ? null
                          : flexRender(
                              header.column.columnDef.header,
                              header.getContext()
                            )}
                      </TableHead>
                    ))}
                  </TableRow>
                ))}
              </TableHeader>
              <TableBody>
                {table.getRowModel().rows?.length ? (
                  table.getRowModel().rows.map((row) => (
                    <TableRow
                      key={row.id}
                      className="group cursor-pointer border-border/40 transition-colors hover:bg-muted/40"
                      onClick={() => goDetail(row.original.id)}
                    >
                      {row.getVisibleCells().map((cell) => (
                        <TableCell
                          key={cell.id}
                          className={jobTableCellClass(cell.column.id)}
                          onClick={
                            cell.column.id === "actions"
                              ? (e) => e.stopPropagation()
                              : undefined
                          }
                        >
                          {flexRender(
                            cell.column.columnDef.cell,
                            cell.getContext()
                          )}
                        </TableCell>
                      ))}
                    </TableRow>
                  ))
                ) : (
                  <TableRow className="hover:bg-transparent">
                    <TableCell
                      colSpan={columns.length}
                      className="text-muted-foreground h-28 border-0 px-4 text-center text-sm"
                    >
                      Tidak ada data lowongan.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          )}
        </div>
      )}

      {paginationFooter && (
        <nav
          aria-label="Paginasi daftar lowongan"
          className="rounded-xl border border-border/60 bg-muted/15 px-4 py-3 shadow-sm sm:px-5 dark:bg-muted/10"
        >
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between sm:gap-4">
            <div className="flex flex-col items-center gap-2 sm:flex-row sm:items-center sm:gap-6">
              <p className="text-muted-foreground text-center text-sm tabular-nums sm:text-left">
                Menampilkan{" "}
                <span className="font-medium text-foreground">
                  {paginationFooter.rangeStart}–{paginationFooter.rangeEnd}
                </span>{" "}
                dari{" "}
                <span className="font-medium text-foreground">
                  {paginationFooter.totalCount}
                </span>{" "}
                lowongan
              </p>
              <div className="flex items-center gap-2">
                <Label
                  htmlFor="job-page-size"
                  className="text-muted-foreground flex shrink-0 items-center gap-1.5 text-xs font-medium whitespace-nowrap sm:text-sm"
                >
                  <IconLayoutRows className="size-3.5 opacity-70" aria-hidden />
                  Per halaman
                </Label>
                <Select
                  value={String(pageSize)}
                  onValueChange={(v) =>
                    handleFilterChange("page_size", Number(v))
                  }
                >
                  <SelectTrigger
                    id="job-page-size"
                    className="h-9 w-[4.5rem] cursor-pointer border-border/80 bg-background shadow-sm"
                  >
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {PAGE_SIZE_OPTIONS.map((n) => (
                      <SelectItem key={n} value={String(n)}>
                        {n}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="flex items-center justify-center gap-1 sm:justify-end">
              <Button
                type="button"
                variant="outline"
                size="icon"
                className="size-9 shrink-0 cursor-pointer rounded-lg border-border/80 shadow-sm disabled:opacity-40"
                onClick={() => handlePageChange(currentPage - 1)}
                disabled={currentPage <= 1}
                aria-label="Halaman sebelumnya"
              >
                <IconChevronLeft className="size-5" stroke={2} />
              </Button>
              <div className="text-muted-foreground flex min-w-[5.5rem] items-center justify-center gap-1 px-2 text-sm tabular-nums">
                <span className="text-foreground font-semibold tabular-nums">
                  {currentPage}
                </span>
                <span className="text-muted-foreground/80" aria-hidden>
                  /
                </span>
                <span className="tabular-nums">{paginationFooter.totalPages}</span>
              </div>
              <Button
                type="button"
                variant="outline"
                size="icon"
                className="size-9 shrink-0 cursor-pointer rounded-lg border-border/80 shadow-sm disabled:opacity-40"
                onClick={() => handlePageChange(currentPage + 1)}
                disabled={currentPage >= paginationFooter.totalPages}
                aria-label="Halaman berikutnya"
              >
                <IconChevronRight className="size-5" stroke={2} />
              </Button>
            </div>
          </div>
        </nav>
      )}
    </div>
  )
}
