/**
 * Applications table — server-side pagination, search, and filters.
 * Mirrors job-table.tsx conventions exactly.
 */

import { useState, useMemo } from "react"
import { Link, useNavigate } from "react-router-dom"
import {
  flexRender,
  getCoreRowModel,
  useReactTable,
  type ColumnDef,
} from "@tanstack/react-table"
import {
  IconClipboardList,
  IconEye,
  IconMessage,
  IconSearch,
  IconUserPlus,
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
import { useApplicationsQuery } from "@/hooks/use-applications-query"
import { ApplicationStatusBadge } from "@/components/applications/application-status-badge"
import {
  APPLICATION_STATUS_LABELS,
  type ApplicationStatus,
  type ApplicationsListParams,
  type JobApplication,
} from "@/types/job-applications"

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100]

const ALL_STATUSES: ApplicationStatus[] = [
  "PRA_SELEKSI",
  "INTERVIEW",
  "DITERIMA",
  "DITOLAK",
  "BERANGKAT",
  "SELESAI",
]

interface ApplicationTableProps {
  /** Base path used to build detail route, e.g. "/lamaran" */
  basePath: string
  /** Pre-filter by job when embedded in a job detail page. */
  jobId?: number
}

function formatDate(value: string | null) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy", { locale: id })
}

export function ApplicationTable({ basePath, jobId }: ApplicationTableProps) {
  const navigate = useNavigate()
  const [params, setParams] = useState<ApplicationsListParams>({
    page: 1,
    page_size: 20,
    search: "",
    ordering: "-applied_at",
    ...(jobId ? { job: jobId } : {}),
  })
  const [searchInput, setSearchInput] = useState("")

  const { data, isLoading, isError, error } = useApplicationsQuery(params)

  const handleSearch = () => {
    setParams((p) => ({
      ...p,
      search: searchInput.trim() || undefined,
      page: 1,
    }))
  }

  const handleFilterChange = <K extends keyof ApplicationsListParams>(
    key: K,
    value: ApplicationsListParams[K]
  ) => {
    setParams((p) => ({ ...p, [key]: value, page: 1 }))
  }

  const handlePageChange = (page: number) => {
    setParams((p) => ({ ...p, page }))
  }

  const columns = useMemo<ColumnDef<JobApplication>[]>(
    () => [
      {
        accessorKey: "applicant_name",
        header: "Pelamar",
        cell: ({ row }) => (
          <div className="flex items-center gap-2 min-w-0">
            <IconClipboardList className="text-muted-foreground size-4 shrink-0" />
            <div className="flex flex-col min-w-0">
              <span className="font-medium truncate">
                {row.original.applicant_name}
              </span>
              <span className="text-muted-foreground text-xs truncate">
                {row.original.applicant_email}
              </span>
            </div>
          </div>
        ),
      },
      {
        accessorKey: "job_title",
        header: "Lowongan",
        cell: ({ row }) => (
          <div className="flex flex-col min-w-0">
            <span className="truncate">{row.original.job_title}</span>
            {row.original.company_name && (
              <span className="text-muted-foreground text-xs truncate">
                {row.original.company_name}
              </span>
            )}
          </div>
        ),
      },
      {
        accessorKey: "status",
        header: "Status",
        cell: ({ row }) => (
          <ApplicationStatusBadge status={row.original.status} />
        ),
      },
      {
        accessorKey: "batch_name",
        header: "Batch",
        cell: ({ row }) => row.original.batch_name ?? "-",
      },
      {
        accessorKey: "applied_at",
        header: "Tanggal Lamar",
        cell: ({ row }) => formatDate(row.original.applied_at),
      },
      {
        id: "actions",
        header: "",
        cell: ({ row }) => {
          const item = row.original
          return (
            <div className="flex items-center gap-1">
              <Button
                variant="ghost"
                size="icon"
                className="size-8 cursor-pointer"
                onClick={() => navigate(`${basePath}/${item.id}`)}
                title="Lihat detail"
              >
                <IconEye className="size-4" />
                <span className="sr-only">Detail</span>
              </Button>
              <Button
                variant="ghost"
                size="icon"
                className="size-8 cursor-pointer"
                onClick={() => navigate(`${basePath}/${item.id}?tab=chat`)}
                title="Buka chat"
              >
                <IconMessage className="size-4" />
                <span className="sr-only">Chat</span>
              </Button>
            </div>
          )
        },
      },
    ],
    [basePath, navigate]
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

  if (isError) {
    return (
      <div className="rounded-lg border border-destructive/50 bg-destructive/5 p-4 text-center">
        <p className="text-destructive">
          Gagal memuat data: {(error as Error).message}
        </p>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-4">
      {/* Toolbar */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex flex-1 flex-col gap-2 sm:flex-row sm:items-center flex-wrap">
          <div className="relative flex-1 min-w-[200px]">
            <IconSearch className="text-muted-foreground absolute left-3 top-1/2 size-4 -translate-y-1/2" />
            <Input
              placeholder="Cari nama, email, atau lowongan..."
              value={searchInput}
              onChange={(e) => setSearchInput(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && handleSearch()}
              className="pl-9"
            />
          </div>
          <Button
            onClick={handleSearch}
            variant="secondary"
            className="cursor-pointer"
          >
            Cari
          </Button>
          <div className="flex flex-wrap gap-2">
            <Select
              value={params.status ?? "ALL"}
              onValueChange={(v) =>
                handleFilterChange(
                  "status",
                  v === "ALL" ? undefined : (v as ApplicationStatus)
                )
              }
            >
              <SelectTrigger className="w-[180px] cursor-pointer">
                <SelectValue placeholder="Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="ALL">Semua status</SelectItem>
                {ALL_STATUSES.map((s) => (
                  <SelectItem key={s} value={s}>
                    {APPLICATION_STATUS_LABELS[s]}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>
        <Button className="cursor-pointer shrink-0" asChild>
          <Link to="/batch">
            <IconUserPlus className="mr-2 size-4" />
            Kelola Batch
          </Link>
        </Button>
      </div>

      {/* Table */}
      <div className="overflow-hidden rounded-lg border">
        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          </div>
        ) : (
          <Table>
            <TableHeader>
              {table.getHeaderGroups().map((headerGroup) => (
                <TableRow key={headerGroup.id}>
                  {headerGroup.headers.map((header) => (
                    <TableHead key={header.id}>
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
                    className="cursor-pointer hover:bg-muted/50"
                    onClick={() => navigate(`${basePath}/${row.original.id}`)}
                  >
                    {row.getVisibleCells().map((cell) => (
                      <TableCell
                        key={cell.id}
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
                <TableRow>
                  <TableCell
                    colSpan={columns.length}
                    className="h-24 text-center"
                  >
                    Tidak ada data lamaran.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        )}
      </div>

      {/* Pagination */}
      {data && data.count > 0 && (
        <div className="flex flex-col items-center justify-between gap-4 sm:flex-row">
          <div className="text-muted-foreground text-sm">
            Menampilkan {(currentPage - 1) * pageSize + 1} –{" "}
            {Math.min(currentPage * pageSize, data.count)} dari {data.count}{" "}
            lamaran
          </div>
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <Label htmlFor="app-page-size" className="text-sm">
                Per halaman
              </Label>
              <Select
                value={String(pageSize)}
                onValueChange={(v) => handleFilterChange("page_size", Number(v))}
              >
                <SelectTrigger
                  id="app-page-size"
                  className="w-20 cursor-pointer"
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
            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                className="cursor-pointer"
                onClick={() => handlePageChange(currentPage - 1)}
                disabled={currentPage <= 1}
              >
                Sebelumnya
              </Button>
              <span className="text-sm">
                Halaman {currentPage} dari {pageCount || 1}
              </span>
              <Button
                variant="outline"
                size="sm"
                className="cursor-pointer"
                onClick={() => handlePageChange(currentPage + 1)}
                disabled={currentPage >= pageCount}
              >
                Selanjutnya
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
