/**
 * Admin users table with server-side pagination, search, and filters.
 * Uses TanStack Table for display and TanStack Query for data.
 * Layout aligned with ApplicantTable / CompanyTable (filter card, table chrome, pagination).
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
  IconChevronLeft,
  IconChevronRight,
  IconCircleCheck,
  IconCircleX,
  IconLayoutRows,
  IconPencil,
  IconPlus,
  IconSearch,
  IconSortAscending,
  IconSortDescending,
  IconShield,
  IconUserCheck,
  IconUserOff,
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
import {
  useAdminsQuery,
  useDeactivateAdminMutation,
  useActivateAdminMutation,
} from "@/hooks/use-admins-query"
import { useIsMobile } from "@/hooks/use-mobile"
import { toast } from "@/lib/toast"
import { cn } from "@/lib/utils"
import type { AdminUser } from "@/types/admin"
import type { AdminsListParams } from "@/types/admin"
import type { UserRole } from "@/types/auth"
import { isMasterAdmin } from "@/types/auth"

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100]

const ADMIN_FILTER_TRIGGER_CLASS =
  "h-9 w-full min-w-0 cursor-pointer shadow-none sm:min-h-0"

/** DRF `ordering` — backend AdminUserViewSet.ordering_fields */
const SORT_FIELD = {
  nama: "full_name",
  email: "email",
  bergabung: "date_joined",
  diperbarui: "updated_at",
} as const

function adminRoleLabel(role: UserRole): string {
  switch (role) {
    case "MASTER_ADMIN":
      return "Admin Utama"
    case "ADMIN":
      return "Admin operator"
    default:
      return role
  }
}

interface AdminTableProps {
  basePath: string
  readOnly?: boolean
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

function adminTableHeadClass(columnId: string) {
  return cn(
    "h-11 border-border/50 px-3 py-2 text-left align-middle first:pl-4 last:pr-4 sm:first:pl-5 sm:last:pr-5",
    columnId === "actions" && "w-[1%] whitespace-nowrap",
    (columnId === "bergabung" || columnId === "diperbarui") && "tabular-nums"
  )
}

function adminTableCellClass(columnId: string) {
  return cn(
    "border-border/40 px-3 py-2.5 align-middle first:pl-4 last:pr-4 sm:first:pl-5 sm:last:pr-5",
    columnId === "nama" && "max-w-[min(22rem,32vw)] whitespace-normal font-medium",
    columnId === "email" && "max-w-[min(20rem,30vw)] whitespace-normal",
    columnId === "role" && "whitespace-normal",
    (columnId === "bergabung" || columnId === "diperbarui") &&
      "text-muted-foreground tabular-nums text-sm",
    columnId === "actions" && "text-right"
  )
}

function formatJoined(iso: string) {
  return format(new Date(iso), "dd MMM yyyy HH:mm", { locale: id })
}

export function AdminTable({ basePath, readOnly = false }: AdminTableProps) {
  const navigate = useNavigate()
  const isMobile = useIsMobile()
  const [params, setParams] = useState<AdminsListParams>({
    page: 1,
    page_size: 20,
    ordering: "email",
  })
  const [searchInput, setSearchInput] = useState("")

  const { data, isLoading, isError, error } = useAdminsQuery(params)
  const deactivateMutation = useDeactivateAdminMutation()
  const activateMutation = useActivateAdminMutation()

  const handleSearch = useCallback(() => {
    setParams((p) => ({
      ...p,
      search: searchInput.trim() || undefined,
      page: 1,
    }))
  }, [searchInput])

  const handleFilterChange = useCallback(
    <K extends keyof AdminsListParams>(key: K, value: AdminsListParams[K]) => {
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

  const handleActivate = useCallback(
    async (admin: AdminUser) => {
      try {
        await activateMutation.mutateAsync(admin.id)
        toast.success("Admin diaktifkan", "Akun berhasil diaktifkan kembali")
      } catch {
        toast.error("Gagal mengaktifkan", "Coba lagi nanti")
      }
    },
    [activateMutation]
  )

  const handleDeactivate = useCallback(
    async (admin: AdminUser) => {
      try {
        await deactivateMutation.mutateAsync(admin.id)
        toast.success("Admin dinonaktifkan", "Akun berhasil dinonaktifkan")
      } catch {
        toast.error("Gagal menonaktifkan", "Coba lagi nanti")
      }
    },
    [deactivateMutation]
  )

  const columns = useMemo<ColumnDef<AdminUser>[]>(
    () => {
      const cols: ColumnDef<AdminUser>[] = [
        {
          id: "nama",
          accessorKey: "full_name",
          header: () => (
            <SortableColumnHead
              field={SORT_FIELD.nama}
              label="Nama"
              ordering={params.ordering}
              onSort={handleSortColumn}
            />
          ),
          cell: ({ row }) => (
            <span className="font-medium">{row.original.full_name || "—"}</span>
          ),
        },
        {
          id: "email",
          accessorKey: "email",
          header: () => (
            <SortableColumnHead
              field={SORT_FIELD.email}
              label="Email"
              ordering={params.ordering}
              onSort={handleSortColumn}
            />
          ),
          cell: ({ row }) => <span>{row.original.email}</span>,
        },
        {
          id: "role",
          accessorKey: "role",
          header: "Tipe",
          cell: ({ row }) => {
            const role = row.original.role
            const master = isMasterAdmin(role)
            return (
              <Badge
                variant={master ? "default" : "secondary"}
                className="font-normal shadow-sm"
                title={
                  master
                    ? "Akses penuh (master dashboard)"
                    : "Akses terbatas (portal admin operator)"
                }
              >
                {adminRoleLabel(role)}
              </Badge>
            )
          },
        },
        {
          id: "status",
          accessorKey: "is_active",
          header: "Status",
          cell: ({ row }) =>
            row.original.is_active ? (
              <Badge variant="default" className="gap-1 shadow-sm">
                <IconCircleCheck className="size-3" />
                Aktif
              </Badge>
            ) : (
              <Badge variant="secondary" className="gap-1">
                <IconCircleX className="size-3" />
                Nonaktif
              </Badge>
            ),
        },
        {
          id: "email_verified",
          accessorKey: "email_verified",
          header: "Email Terverifikasi",
          cell: ({ row }) =>
            row.original.email_verified ? (
              <Badge variant="outline" className="border-border/80 shadow-sm">
                Ya
              </Badge>
            ) : (
              <Badge
                variant="outline"
                className="border-border/80 text-muted-foreground"
              >
                Belum
              </Badge>
            ),
        },
        {
          id: "bergabung",
          accessorKey: "date_joined",
          header: () => (
            <SortableColumnHead
              field={SORT_FIELD.bergabung}
              label="Bergabung"
              ordering={params.ordering}
              onSort={handleSortColumn}
            />
          ),
          cell: ({ row }) => formatJoined(row.original.date_joined),
        },
        {
          id: "diperbarui",
          accessorKey: "updated_at",
          header: () => (
            <SortableColumnHead
              field={SORT_FIELD.diperbarui}
              label="Diperbarui"
              ordering={params.ordering}
              onSort={handleSortColumn}
            />
          ),
          cell: ({ row }) => formatJoined(row.original.updated_at),
        },
      ]
      if (!readOnly) {
        cols.push({
          id: "actions",
          header: "",
          cell: ({ row }) => {
            const admin = row.original
            return (
              <div className="flex items-center justify-end gap-1">
                <Button
                  variant="outline"
                  size="icon"
                  className="size-8 cursor-pointer rounded-lg border-border/80 bg-background/80 shadow-sm hover:bg-muted/60"
                  onClick={() => navigate(`${basePath}/${admin.id}/edit`)}
                  title="Edit"
                >
                  <IconPencil className="size-4" />
                  <span className="sr-only">Edit</span>
                </Button>
                {admin.is_active ? (
                  <Button
                    variant="outline"
                    size="icon"
                    className="size-8 cursor-pointer rounded-lg border-border/80 bg-background/80 text-destructive shadow-sm hover:bg-destructive/10 hover:text-destructive"
                    onClick={() => handleDeactivate(admin)}
                    title="Nonaktifkan"
                  >
                    <IconUserOff className="size-4" />
                    <span className="sr-only">Nonaktifkan</span>
                  </Button>
                ) : (
                  <Button
                    variant="outline"
                    size="icon"
                    className="size-8 cursor-pointer rounded-lg border-border/80 bg-background/80 shadow-sm hover:bg-muted/60"
                    onClick={() => handleActivate(admin)}
                    title="Aktifkan"
                  >
                    <IconUserCheck className="size-4" />
                    <span className="sr-only">Aktifkan</span>
                  </Button>
                )}
              </div>
            )
          },
        })
      }
      return cols
    },
    [
      basePath,
      navigate,
      params.ordering,
      handleSortColumn,
      handleActivate,
      handleDeactivate,
      readOnly,
    ]
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

  return (
    <div className="flex flex-col gap-4">
      <section
        aria-label="Pencarian dan filter admin"
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
                  placeholder="Cari email atau nama…"
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
                    {isMobile ? "Tambah" : "Tambah Admin"}
                  </Link>
                </Button>
              </div>
            )}
          </div>
        </div>

        <div className="px-4 py-3 sm:px-5 sm:py-4">
          <p className="text-muted-foreground sr-only">Filter daftar admin</p>
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-12 xl:gap-2">
            <div className="min-w-0 sm:col-span-1 xl:col-span-6">
              <Select
                value={
                  params.is_active === undefined ? "all" : String(params.is_active)
                }
                onValueChange={(v) =>
                  handleFilterChange(
                    "is_active",
                    v === "all" ? undefined : v === "true"
                  )
                }
              >
                <SelectTrigger className={ADMIN_FILTER_TRIGGER_CLASS}>
                  <SelectValue placeholder="Status akun" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Semua status</SelectItem>
                  <SelectItem value="true">Aktif</SelectItem>
                  <SelectItem value="false">Nonaktif</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="min-w-0 sm:col-span-1 xl:col-span-6">
              <Select
                value={
                  params.email_verified === undefined
                    ? "all"
                    : String(params.email_verified)
                }
                onValueChange={(v) =>
                  handleFilterChange(
                    "email_verified",
                    v === "all" ? undefined : v === "true"
                  )
                }
              >
                <SelectTrigger className={ADMIN_FILTER_TRIGGER_CLASS}>
                  <SelectValue placeholder="Verifikasi email" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Semua verifikasi</SelectItem>
                  <SelectItem value="true">Terverifikasi</SelectItem>
                  <SelectItem value="false">Belum</SelectItem>
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
            data.results.map((admin) => {
              const master = isMasterAdmin(admin.role)
              return (
                <article
                  key={admin.id}
                  className="rounded-xl border border-border/60 bg-card p-4 shadow-sm transition-colors hover:border-border hover:bg-muted/15"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0 flex-1 space-y-3">
                      <div className="flex items-start gap-2.5">
                        <IconShield className="text-muted-foreground mt-0.5 size-5 shrink-0" />
                        <div className="min-w-0 flex-1">
                          <p className="font-medium leading-snug">
                            {admin.full_name || "—"}
                          </p>
                          <p className="text-muted-foreground mt-0.5 truncate text-sm">
                            {admin.email}
                          </p>
                        </div>
                      </div>

                      <div className="flex flex-wrap gap-2 border-t border-border/50 pt-3">
                        <Badge
                          variant={master ? "default" : "secondary"}
                          className="font-normal"
                        >
                          {adminRoleLabel(admin.role)}
                        </Badge>
                      </div>

                      <div className="grid grid-cols-1 gap-2 border-t border-border/50 pt-3 text-sm">
                        <div>
                          <span className="text-muted-foreground text-xs font-medium">
                            Bergabung
                          </span>
                          <p className="text-muted-foreground mt-0.5 text-xs tabular-nums">
                            {formatJoined(admin.date_joined)}
                          </p>
                        </div>
                      </div>

                      <div className="flex flex-wrap items-center gap-2 pt-0.5">
                        {admin.is_active ? (
                          <Badge variant="default" className="gap-1 shadow-sm">
                            <IconCircleCheck className="size-3" />
                            Aktif
                          </Badge>
                        ) : (
                          <Badge variant="secondary" className="gap-1">
                            <IconCircleX className="size-3" />
                            Nonaktif
                          </Badge>
                        )}
                        {admin.email_verified ? (
                          <Badge
                            variant="outline"
                            className="border-border/80 text-xs shadow-sm"
                          >
                            Email terverifikasi
                          </Badge>
                        ) : (
                          <Badge
                            variant="outline"
                            className="border-border/80 text-muted-foreground text-xs"
                          >
                            Email belum
                          </Badge>
                        )}
                      </div>
                    </div>

                    {!readOnly && (
                      <div className="flex shrink-0 flex-col gap-1.5">
                        <Button
                          variant="outline"
                          size="icon"
                          className="size-9 cursor-pointer rounded-lg border-border/80 bg-background/80 shadow-sm hover:bg-muted/60"
                          onClick={() => navigate(`${basePath}/${admin.id}/edit`)}
                          title="Edit"
                        >
                          <IconPencil className="size-4" />
                          <span className="sr-only">Edit</span>
                        </Button>
                        {admin.is_active ? (
                          <Button
                            variant="outline"
                            size="icon"
                            className="size-9 cursor-pointer rounded-lg border-border/80 bg-background/80 text-destructive shadow-sm hover:bg-destructive/10"
                            onClick={() => handleDeactivate(admin)}
                            title="Nonaktifkan"
                          >
                            <IconUserOff className="size-4" />
                            <span className="sr-only">Nonaktifkan</span>
                          </Button>
                        ) : (
                          <Button
                            variant="outline"
                            size="icon"
                            className="size-9 cursor-pointer rounded-lg border-border/80 bg-background/80 shadow-sm hover:bg-muted/60"
                            onClick={() => handleActivate(admin)}
                            title="Aktifkan"
                          >
                            <IconUserCheck className="size-4" />
                            <span className="sr-only">Aktifkan</span>
                          </Button>
                        )}
                      </div>
                    )}
                  </div>
                </article>
              )
            })
          ) : (
            <div className="rounded-xl border border-border/60 border-dashed bg-muted/10 p-10 text-center shadow-sm">
              <p className="text-muted-foreground text-sm">
                Tidak ada data admin.
              </p>
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
                        className={adminTableHeadClass(header.column.id)}
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
                      className="group border-border/40 transition-colors hover:bg-muted/40"
                    >
                      {row.getVisibleCells().map((cell) => (
                        <TableCell
                          key={cell.id}
                          className={adminTableCellClass(cell.column.id)}
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
                      Tidak ada data admin.
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
          aria-label="Paginasi daftar admin"
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
                admin
              </p>
              <div className="flex items-center gap-2">
                <Label
                  htmlFor="admin-page-size"
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
                    id="admin-page-size"
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
                title="Sebelumnya"
              >
                <IconChevronLeft className="size-5" stroke={2} />
              </Button>
              <div className="text-muted-foreground flex min-w-[5.5rem] items-center justify-center gap-1 px-2 text-sm tabular-nums">
                <span className="sr-only">Halaman </span>
                <span className="text-foreground font-semibold tabular-nums">
                  {currentPage}
                </span>
                <span className="text-muted-foreground/80" aria-hidden>
                  /
                </span>
                <span className="tabular-nums">
                  {paginationFooter.totalPages}
                </span>
              </div>
              <Button
                type="button"
                variant="outline"
                size="icon"
                className="size-9 shrink-0 cursor-pointer rounded-lg border-border/80 shadow-sm disabled:opacity-40"
                onClick={() => handlePageChange(currentPage + 1)}
                disabled={currentPage >= paginationFooter.totalPages}
                aria-label="Halaman berikutnya"
                title="Selanjutnya"
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
