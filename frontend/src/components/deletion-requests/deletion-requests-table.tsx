/**
 * Account deletion requests — filter card, table, and server-side pagination.
 * Layout aligned with NewsTable / AdminTable / ApplicantTable.
 */

import { useState, useMemo, useCallback, useEffect } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import {
  flexRender,
  getCoreRowModel,
  useReactTable,
  type ColumnDef,
} from "@tanstack/react-table"
import {
  IconCheck,
  IconChevronLeft,
  IconChevronRight,
  IconLayoutRows,
  IconSearch,
  IconTrash,
  IconUserOff,
  IconX,
} from "@tabler/icons-react"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"

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
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Textarea } from "@/components/ui/textarea"
import { Badge } from "@/components/ui/badge"
import { useIsMobile } from "@/hooks/use-mobile"
import { toast } from "@/lib/toast"
import { cn } from "@/lib/utils"
import {
  getDeletionRequests,
  approveDeletionRequest,
  rejectDeletionRequest,
} from "@/api/account-deletion"
import type {
  AccountDeletionRequest,
  DeletionRequestStatus,
  DeletionRequestsListParams,
} from "@/types/account-deletion"

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100]

const FILTER_TRIGGER_CLASS =
  "h-9 w-full min-w-0 cursor-pointer shadow-none sm:min-h-0"

const STATUS_LABELS: Record<DeletionRequestStatus, string> = {
  PENDING: "Menunggu",
  APPROVED: "Disetujui",
  REJECTED: "Ditolak",
  CANCELLED: "Dibatalkan",
}

const STATUS_VARIANTS: Record<
  DeletionRequestStatus,
  "default" | "secondary" | "destructive" | "outline"
> = {
  PENDING: "default",
  APPROVED: "destructive",
  REJECTED: "secondary",
  CANCELLED: "outline",
}

function formatRequestedAt(iso: string) {
  try {
    return format(new Date(iso), "dd MMM yyyy HH:mm", { locale: idLocale })
  } catch {
    return "—"
  }
}

function deletionTableHeadClass(columnId: string) {
  return cn(
    "h-11 border-border/50 px-3 py-2 text-left align-middle first:pl-4 last:pr-4 sm:first:pl-5 sm:last:pr-5",
    columnId === "actions" && "w-[1%] whitespace-nowrap",
    columnId === "tanggal" && "tabular-nums"
  )
}

function deletionTableCellClass(columnId: string) {
  return cn(
    "border-border/40 px-3 py-2.5 align-middle first:pl-4 last:pr-4 sm:first:pl-5 sm:last:pr-5",
    columnId === "pengguna" && "max-w-[min(22rem,36vw)] whitespace-normal",
    columnId === "alasan" && "max-w-[min(18rem,30vw)] whitespace-normal",
    columnId === "catatan" && "max-w-[min(14rem,24vw)] whitespace-normal text-xs",
    columnId === "tanggal" && "text-muted-foreground tabular-nums text-sm",
    columnId === "actions" && "text-right"
  )
}

export function DeletionRequestsTable() {
  const queryClient = useQueryClient()
  const isMobile = useIsMobile()

  const [params, setParams] = useState<DeletionRequestsListParams>({
    page: 1,
    page_size: 20,
  })
  const [searchInput, setSearchInput] = useState("")
  const [statusFilter, setStatusFilter] = useState<DeletionRequestStatus | "ALL">("ALL")

  const listParams = useMemo<DeletionRequestsListParams>(
    () => ({
      page: params.page,
      page_size: params.page_size,
      search: params.search,
      ...(statusFilter !== "ALL" ? { status: statusFilter } : {}),
    }),
    [params.page, params.page_size, params.search, statusFilter]
  )

  const [selectedRequest, setSelectedRequest] = useState<AccountDeletionRequest | null>(null)
  const [action, setAction] = useState<"approve" | "reject" | null>(null)
  const [adminNotes, setAdminNotes] = useState("")

  const { data, isLoading, isError, error } = useQuery({
    queryKey: ["deletion-requests", listParams],
    queryFn: () => getDeletionRequests(listParams),
  })

  const rows = data?.results ?? []
  const totalCount = data?.count ?? 0
  const pageSize = params.page_size ?? 20
  const currentPage = params.page ?? 1

  const handleSearch = useCallback(() => {
    setParams((p) => ({
      ...p,
      page: 1,
      search: searchInput.trim() || undefined,
    }))
  }, [searchInput])

  const handlePageChange = useCallback((next: number) => {
    setParams((p) => ({ ...p, page: next }))
  }, [])

  const handleFilterChange = useCallback(
    <K extends keyof DeletionRequestsListParams>(key: K, value: DeletionRequestsListParams[K]) => {
      setParams((p) => ({ ...p, [key]: value, page: 1 }))
    },
    []
  )

  useEffect(() => {
    if (isLoading || data === undefined) return
    const maxPage = Math.max(1, Math.ceil(totalCount / pageSize))
    if (currentPage > maxPage) {
      setParams((p) => ({ ...p, page: maxPage }))
    }
  }, [isLoading, data, totalCount, pageSize, currentPage])

  const approveMutation = useMutation({
    mutationFn: (id: number) => approveDeletionRequest(id, { admin_notes: adminNotes }),
    onSuccess: () => {
      toast.success(
        "Permintaan disetujui",
        "Login pengguna dinonaktifkan; pemberitahuan dikirim ke email pengguna (jika aktif)."
      )
      queryClient.invalidateQueries({ queryKey: ["deletion-requests"] })
      closeDialog()
    },
  })

  const rejectMutation = useMutation({
    mutationFn: (id: number) => rejectDeletionRequest(id, { admin_notes: adminNotes }),
    onSuccess: () => {
      toast.success(
        "Permintaan ditolak",
        "Pengguna akan menerima email dan notifikasi di aplikasi."
      )
      queryClient.invalidateQueries({ queryKey: ["deletion-requests"] })
      closeDialog()
    },
  })

  function openDialog(req: AccountDeletionRequest, act: "approve" | "reject") {
    setSelectedRequest(req)
    setAction(act)
    setAdminNotes("")
  }

  function closeDialog() {
    setSelectedRequest(null)
    setAction(null)
    setAdminNotes("")
  }

  function handleConfirm() {
    if (!selectedRequest) return
    if (action === "approve") approveMutation.mutate(selectedRequest.id)
    else if (action === "reject") rejectMutation.mutate(selectedRequest.id)
  }

  const isPending = approveMutation.isPending || rejectMutation.isPending

  const columns = useMemo<ColumnDef<AccountDeletionRequest>[]>(
    () => [
      {
        id: "pengguna",
        accessorFn: (row) => row.user_full_name || row.user_email,
        header: "Pengguna",
        cell: ({ row }) => (
          <div className="min-w-0">
            <div className="font-medium leading-snug">
              {row.original.user_full_name || "—"}
            </div>
            <div className="text-muted-foreground text-xs">{row.original.user_email}</div>
          </div>
        ),
      },
      {
        id: "peran",
        accessorKey: "user_role",
        header: "Peran",
        cell: ({ row }) => (
          <span className="text-muted-foreground capitalize">
            {row.original.user_role.toLowerCase()}
          </span>
        ),
      },
      {
        id: "alasan",
        accessorKey: "reason",
        header: "Alasan",
        cell: ({ row }) => (
          <span className="text-muted-foreground line-clamp-2 text-sm">
            {row.original.reason || (
              <em className="text-muted-foreground/80">Tidak ada alasan</em>
            )}
          </span>
        ),
      },
      {
        id: "status",
        accessorKey: "status",
        header: "Status",
        cell: ({ row }) => {
          const s = row.original.status
          return (
            <Badge variant={STATUS_VARIANTS[s]} className="shadow-sm">
              {STATUS_LABELS[s]}
            </Badge>
          )
        },
      },
      {
        id: "login",
        accessorKey: "user_is_active",
        header: "Login",
        cell: ({ row }) =>
          row.original.user_is_active ? (
            <Badge variant="outline" className="border-border/80 shadow-sm">
              Aktif
            </Badge>
          ) : (
            <Badge variant="secondary" className="gap-1 shadow-sm">
              <IconUserOff className="size-3" aria-hidden />
              Nonaktif
            </Badge>
          ),
      },
      {
        id: "tanggal",
        accessorKey: "requested_at",
        header: "Diajukan",
        cell: ({ row }) => formatRequestedAt(row.original.requested_at),
      },
      {
        id: "catatan",
        accessorKey: "admin_notes",
        header: "Catatan admin",
        cell: ({ row }) => (
          <span className="text-muted-foreground line-clamp-2">
            {row.original.admin_notes || "—"}
          </span>
        ),
      },
      {
        id: "actions",
        header: "",
        cell: ({ row }) => {
          const req = row.original
          if (req.status !== "PENDING") {
            return <span className="text-muted-foreground text-xs">—</span>
          }
          return (
            <div className="flex flex-wrap items-center justify-end gap-1.5">
              <Button
                size="sm"
                variant="destructive"
                className="h-8 cursor-pointer gap-1 px-2.5 shadow-sm"
                onClick={(e) => {
                  e.stopPropagation()
                  openDialog(req, "approve")
                }}
              >
                <IconCheck className="size-3.5" />
                Setujui
              </Button>
              <Button
                size="sm"
                variant="outline"
                className="h-8 cursor-pointer gap-1 px-2.5 border-border/80 shadow-sm"
                onClick={(e) => {
                  e.stopPropagation()
                  openDialog(req, "reject")
                }}
              >
                <IconX className="size-3.5" />
                Tolak
              </Button>
            </div>
          )
        },
      },
    ],
    []
  )

  const pageCountForTable = data ? Math.ceil(totalCount / pageSize) : 0

  const table = useReactTable({
    data: rows,
    columns,
    getCoreRowModel: getCoreRowModel(),
    manualPagination: true,
    pageCount: pageCountForTable,
  })

  const paginationFooter =
    totalCount > 0
      ? {
          rangeStart: (currentPage - 1) * pageSize + 1,
          rangeEnd: Math.min(currentPage * pageSize, totalCount),
          totalPages: pageCountForTable || 1,
          totalCount,
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
        aria-label="Pencarian dan filter permintaan hapus akun"
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
          </div>
        </div>

        <div className="px-4 py-3 sm:px-5 sm:py-4">
          <p className="sr-only text-muted-foreground">Filter status permintaan</p>
          <div className="grid grid-cols-1 gap-2 xl:grid-cols-12 xl:gap-2">
            <div className="min-w-0 xl:col-span-12">
              <Select
                value={statusFilter}
                onValueChange={(v) => {
                  setStatusFilter(v as DeletionRequestStatus | "ALL")
                  setParams((p) => ({ ...p, page: 1 }))
                }}
              >
                <SelectTrigger className={FILTER_TRIGGER_CLASS}>
                  <SelectValue placeholder="Semua status" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="ALL">Semua status</SelectItem>
                  <SelectItem value="PENDING">Menunggu</SelectItem>
                  <SelectItem value="APPROVED">Disetujui</SelectItem>
                  <SelectItem value="REJECTED">Ditolak</SelectItem>
                  <SelectItem value="CANCELLED">Dibatalkan</SelectItem>
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
          ) : rows.length > 0 ? (
            rows.map((req) => (
              <article
                key={req.id}
                className="rounded-xl border border-border/60 bg-card p-4 text-left shadow-sm"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0 flex-1 space-y-2">
                    <div className="flex items-start gap-2">
                      <IconTrash className="text-muted-foreground mt-0.5 size-5 shrink-0 opacity-60" />
                      <div className="min-w-0">
                        <p className="font-medium leading-snug">
                          {req.user_full_name || "—"}
                        </p>
                        <p className="text-muted-foreground text-xs">{req.user_email}</p>
                      </div>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      <Badge variant={STATUS_VARIANTS[req.status]} className="text-xs shadow-sm">
                        {STATUS_LABELS[req.status]}
                      </Badge>
                      {req.user_is_active ? (
                        <Badge variant="outline" className="text-xs">
                          Login aktif
                        </Badge>
                      ) : (
                        <Badge variant="secondary" className="gap-1 text-xs">
                          <IconUserOff className="size-3" />
                          Login nonaktif
                        </Badge>
                      )}
                    </div>
                    <p className="text-muted-foreground border-t border-border/50 pt-2 text-xs leading-relaxed">
                      {req.reason ? (
                        req.reason
                      ) : (
                        <em className="text-muted-foreground/80">Tidak ada alasan</em>
                      )}
                    </p>
                    <p className="text-muted-foreground text-xs tabular-nums">
                      Diajukan: {formatRequestedAt(req.requested_at)}
                    </p>
                  </div>
                </div>
                {req.status === "PENDING" ? (
                  <div className="mt-4 flex flex-wrap gap-2 border-t border-border/40 pt-3">
                    <Button
                      size="sm"
                      variant="destructive"
                      className="flex-1 cursor-pointer gap-1 sm:flex-none"
                      onClick={() => openDialog(req, "approve")}
                    >
                      <IconCheck className="size-3.5" />
                      Setujui
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      className="flex-1 cursor-pointer gap-1 sm:flex-none"
                      onClick={() => openDialog(req, "reject")}
                    >
                      <IconX className="size-3.5" />
                      Tolak
                    </Button>
                  </div>
                ) : null}
              </article>
            ))
          ) : (
            <div className="rounded-xl border border-border/60 border-dashed bg-muted/10 p-10 text-center shadow-sm">
              <IconTrash className="mx-auto mb-2 size-10 text-muted-foreground opacity-40" />
              <p className="text-muted-foreground text-sm">
                Tidak ada permintaan penghapusan akun.
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
                        className={deletionTableHeadClass(header.column.id)}
                      >
                        {header.isPlaceholder
                          ? null
                          : flexRender(header.column.columnDef.header, header.getContext())}
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
                      className="border-border/40 transition-colors hover:bg-muted/40"
                    >
                      {row.getVisibleCells().map((cell) => (
                        <TableCell
                          key={cell.id}
                          className={deletionTableCellClass(cell.column.id)}
                          onClick={
                            cell.column.id === "actions"
                              ? (e) => e.stopPropagation()
                              : undefined
                          }
                        >
                          {flexRender(cell.column.columnDef.cell, cell.getContext())}
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
                      <div className="flex flex-col items-center gap-2">
                        <IconTrash className="size-8 opacity-30" />
                        Tidak ada permintaan penghapusan akun.
                      </div>
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
          aria-label="Paginasi permintaan hapus akun"
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
                permintaan
              </p>
              <div className="flex items-center gap-2">
                <Label
                  htmlFor="deletion-page-size"
                  className="text-muted-foreground flex shrink-0 items-center gap-1.5 text-xs font-medium whitespace-nowrap sm:text-sm"
                >
                  <IconLayoutRows className="size-3.5 opacity-70" aria-hidden />
                  Per halaman
                </Label>
                <Select
                  value={String(pageSize)}
                  onValueChange={(v) => handleFilterChange("page_size", Number(v))}
                >
                  <SelectTrigger
                    id="deletion-page-size"
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
                <span className="text-foreground font-semibold tabular-nums">{currentPage}</span>
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

      <Dialog open={!!selectedRequest} onOpenChange={(open) => !open && closeDialog()}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {action === "approve"
                ? "Setujui Penghapusan Akun"
                : "Tolak Permintaan Penghapusan"}
            </DialogTitle>
            <DialogDescription>
              {action === "approve" ? (
                <>
                  Login untuk <strong>{selectedRequest?.user_email}</strong> akan{" "}
                  <strong>dinonaktifkan</strong>. Pengguna menerima pemberitahuan bahwa permintaan
                  penghapusan telah diproses (penutupan dari layanan aktif). Data tetap tersimpan
                  untuk keperluan perusahaan; tindakan ini tidak dapat dibatalkan melalui layanan ini.
                </>
              ) : (
                <>
                  Permintaan penghapusan akun dari{" "}
                  <strong>{selectedRequest?.user_email}</strong> akan ditolak. Akun tetap aktif.
                </>
              )}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-2">
            <Label htmlFor="admin-notes-deletion">
              Catatan Admin{action === "reject" && " (opsional)"}
            </Label>
            <Textarea
              id="admin-notes-deletion"
              placeholder={
                action === "approve"
                  ? "Catatan internal (opsional)..."
                  : "Alasan penolakan (opsional)..."
              }
              value={adminNotes}
              onChange={(e) => setAdminNotes(e.target.value)}
              rows={3}
            />
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={closeDialog} disabled={isPending}>
              Batal
            </Button>
            <Button
              variant={action === "approve" ? "destructive" : "default"}
              onClick={handleConfirm}
              disabled={isPending}
            >
              {isPending
                ? "Memproses..."
                : action === "approve"
                  ? "Ya, Setujui & Nonaktifkan Login"
                  : "Tolak Permintaan"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
