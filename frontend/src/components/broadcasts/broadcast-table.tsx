/**
 * Broadcast table with server-side pagination, search, and filters.
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
  IconBroadcast,
  IconChevronLeft,
  IconChevronRight,
  IconLayoutRows,
  IconLoader,
  IconPencil,
  IconPlus,
  IconSearch,
  IconSend,
  IconSortAscending,
  IconSortDescending,
  IconCheck,
  IconClock,
  IconAlertCircle,
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
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { Badge } from "@/components/ui/badge"
import { useBroadcastsQuery, useSendBroadcastMutation } from "@/hooks/use-broadcasts-query"
import { useIsMobile } from "@/hooks/use-mobile"
import { toast } from "@/lib/toast"
import { cn } from "@/lib/utils"
import type {
  Broadcast,
  BroadcastsListParams,
  NotificationType,
  NotificationPriority,
} from "@/types/notification"

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100]

const BROADCAST_FILTER_TRIGGER_CLASS =
  "h-9 w-full min-w-0 cursor-pointer shadow-none sm:min-h-0"

/** DRF ordering — BroadcastViewSet.ordering_fields */
const SORT_FIELD = {
  dibuat: "created_at",
  penerima: "total_recipients",
} as const

interface BroadcastTableProps {
  basePath: string
}

function formatDate(value: string | null) {
  if (!value) return "—"
  try {
    return format(new Date(value), "dd MMM yyyy HH:mm", { locale: idLocale })
  } catch {
    return "—"
  }
}

function getNotificationTypeBadge(type: string) {
  const config: Record<
    string,
    { variant: "default" | "secondary" | "destructive" | "outline"; label: string }
  > = {
    INFO: { variant: "default", label: "Info" },
    SUCCESS: { variant: "secondary", label: "Success" },
    WARNING: { variant: "outline", label: "Warning" },
    ERROR: { variant: "destructive", label: "Error" },
    BROADCAST: { variant: "default", label: "Broadcast" },
  }
  const { variant, label } = config[type] || {
    variant: "default" as const,
    label: type,
  }
  return (
    <Badge variant={variant} className="text-xs shadow-sm">
      {label}
    </Badge>
  )
}

function getPriorityBadge(priority: string) {
  const config: Record<string, { className: string; label: string }> = {
    LOW: { className: "bg-gray-100 text-gray-800", label: "Rendah" },
    NORMAL: { className: "bg-blue-100 text-blue-800", label: "Normal" },
    HIGH: { className: "bg-orange-100 text-orange-800", label: "Tinggi" },
    URGENT: { className: "bg-red-100 text-red-800", label: "Urgent" },
  }
  const { className, label } = config[priority] || {
    className: "bg-gray-100 text-gray-800",
    label: priority,
  }
  return (
    <Badge variant="outline" className={cn(className, "text-xs")}>
      {label}
    </Badge>
  )
}

function getStatusBadge(broadcast: Broadcast) {
  if (broadcast.sent_at) {
    return (
      <Badge variant="secondary" className="gap-1 text-xs text-green-800 dark:text-green-200">
        <IconCheck className="size-3" />
        Terkirim
      </Badge>
    )
  }
  if (broadcast.scheduled_at && new Date(broadcast.scheduled_at) > new Date()) {
    return (
      <Badge variant="outline" className="gap-1 text-xs text-blue-800 dark:text-blue-200">
        <IconClock className="size-3" />
        Terjadwal
      </Badge>
    )
  }
  return (
    <Badge variant="outline" className="gap-1 text-xs">
      <IconAlertCircle className="size-3" />
      Draft
    </Badge>
  )
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

function broadcastTableHeadClass(columnId: string) {
  return cn(
    "h-11 border-border/50 px-3 py-2 text-left align-middle first:pl-4 last:pr-4 sm:first:pl-5 sm:last:pr-5",
    columnId === "actions" && "w-[1%] whitespace-nowrap",
    columnId === "created_at" && "tabular-nums",
    columnId === "recipient_count" && "tabular-nums"
  )
}

function broadcastTableCellClass(columnId: string) {
  return cn(
    "border-border/40 px-3 py-2.5 align-middle first:pl-4 last:pr-4 sm:first:pl-5 sm:last:pr-5",
    columnId === "judul" && "max-w-[min(22rem,34vw)] whitespace-normal",
    columnId === "created_at" && "text-muted-foreground tabular-nums text-sm",
    columnId === "recipient_count" && "tabular-nums text-sm",
    columnId === "actions" && "text-right"
  )
}

export function BroadcastTable({ basePath }: BroadcastTableProps) {
  const navigate = useNavigate()
  const isMobile = useIsMobile()
  const [params, setParams] = useState<BroadcastsListParams>({
    page: 1,
    page_size: 20,
    ordering: "-created_at",
  })
  const [searchInput, setSearchInput] = useState("")
  const [broadcastToSend, setBroadcastToSend] = useState<Broadcast | null>(null)

  const { data, isLoading, isError, error } = useBroadcastsQuery(params)
  const sendMutation = useSendBroadcastMutation()

  const handleSearch = useCallback(() => {
    setParams((p) => ({
      ...p,
      search: searchInput.trim() || undefined,
      page: 1,
    }))
  }, [searchInput])

  const handleFilterChange = useCallback(
    <K extends keyof BroadcastsListParams>(
      key: K,
      value: BroadcastsListParams[K]
    ) => {
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

  const handleSendBroadcast = useCallback(
    async (broadcast: Broadcast) => {
      try {
        await sendMutation.mutateAsync(broadcast.id)
        toast.success(
          "Broadcast Terkirim",
          "Broadcast berhasil dikirim ke semua penerima"
        )
        setBroadcastToSend(null)
      } catch (error: unknown) {
        const message =
          error &&
          typeof error === "object" &&
          "response" in error &&
          error.response &&
          typeof error.response === "object" &&
          "data" in error.response &&
          error.response.data &&
          typeof error.response.data === "object" &&
          "message" in error.response.data
            ? String((error.response.data as { message?: string }).message)
            : "Gagal mengirim broadcast"
        toast.error("Gagal Mengirim", message)
      }
    },
    [sendMutation]
  )

  const columns = useMemo<ColumnDef<Broadcast>[]>(
    () => [
      {
        id: "judul",
        accessorKey: "title",
        header: "Judul",
        cell: ({ row }) => (
          <div className="max-w-md min-w-0">
            <p className="font-medium leading-snug">{row.original.title}</p>
            <p className="text-muted-foreground mt-0.5 line-clamp-2 text-xs">
              {row.original.message}
            </p>
          </div>
        ),
      },
      {
        id: "notification_type",
        accessorKey: "notification_type",
        header: "Tipe",
        cell: ({ row }) => getNotificationTypeBadge(row.original.notification_type),
      },
      {
        id: "priority",
        accessorKey: "priority",
        header: "Prioritas",
        cell: ({ row }) => getPriorityBadge(row.original.priority),
      },
      {
        id: "status",
        header: "Status",
        cell: ({ row }) => getStatusBadge(row.original),
      },
      {
        id: "recipient_count",
        accessorKey: "recipient_count",
        header: () => (
          <SortableColumnHead
            field={SORT_FIELD.penerima}
            label="Penerima"
            ordering={params.ordering}
            onSort={handleSortColumn}
          />
        ),
        cell: ({ row }) => (
          <span className="tabular-nums">
            {(row.original.recipient_count ?? row.original.total_recipients) || 0}{" "}
            orang
          </span>
        ),
      },
      {
        id: "created_at",
        accessorKey: "created_at",
        header: () => (
          <SortableColumnHead
            field={SORT_FIELD.dibuat}
            label="Dibuat / dikirim"
            ordering={params.ordering}
            onSort={handleSortColumn}
          />
        ),
        cell: ({ row }) => (
          <div className="text-xs leading-relaxed">
            <p>{formatDate(row.original.created_at)}</p>
            {row.original.sent_at ? (
              <p className="text-muted-foreground mt-0.5">
                Kirim: {formatDate(row.original.sent_at)}
              </p>
            ) : null}
          </div>
        ),
      },
      {
        id: "actions",
        header: "",
        cell: ({ row }) => {
          const broadcast = row.original
          const canEdit = !broadcast.sent_at
          const canSend = !broadcast.sent_at

          return (
            <div className="flex items-center justify-end gap-1">
              {canEdit && (
                <Button
                  variant="outline"
                  size="icon"
                  className="size-8 cursor-pointer rounded-lg border-border/80 bg-background/80 shadow-sm hover:bg-muted/60"
                  onClick={() => navigate(`${basePath}/${broadcast.id}/edit`)}
                  title="Edit"
                >
                  <IconPencil className="size-4" />
                  <span className="sr-only">Edit</span>
                </Button>
              )}
              {canSend && (
                <Button
                  variant="outline"
                  size="icon"
                  className="size-8 cursor-pointer rounded-lg border-border/80 text-primary shadow-sm hover:bg-primary/10"
                  onClick={() => setBroadcastToSend(broadcast)}
                  title="Kirim Sekarang"
                  disabled={sendMutation.isPending}
                >
                  {sendMutation.isPending ? (
                    <IconLoader className="size-4 animate-spin" />
                  ) : (
                    <IconSend className="size-4" />
                  )}
                  <span className="sr-only">Kirim</span>
                </Button>
              )}
            </div>
          )
        },
      },
    ],
    [navigate, basePath, params.ordering, handleSortColumn, sendMutation.isPending]
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
    <>
      <div className="flex flex-col gap-4">
        <section
          aria-label="Pencarian dan filter broadcast"
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
                    placeholder="Cari judul atau pesan…"
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
              <div className="flex flex-col gap-2 sm:flex-row sm:justify-end lg:shrink-0">
                <Button asChild className="h-9 cursor-pointer shadow-sm sm:w-auto">
                  <Link to={`${basePath}/new`} className="cursor-pointer gap-2">
                    <IconPlus className="size-4 shrink-0" />
                    {isMobile ? "Buat" : "Buat Broadcast"}
                  </Link>
                </Button>
              </div>
            </div>
          </div>

          <div className="px-4 py-3 sm:px-5 sm:py-4">
            <p className="text-muted-foreground sr-only">Filter broadcast</p>
            <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-12 xl:gap-2">
              <div className="min-w-0 sm:col-span-1 xl:col-span-6">
                <Select
                  value={params.notification_type ?? "all"}
                  onValueChange={(v) =>
                    handleFilterChange(
                      "notification_type",
                      v === "all" ? undefined : (v as NotificationType)
                    )
                  }
                >
                  <SelectTrigger className={BROADCAST_FILTER_TRIGGER_CLASS}>
                    <SelectValue placeholder="Tipe notifikasi" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">Semua tipe</SelectItem>
                    <SelectItem value="INFO">Info</SelectItem>
                    <SelectItem value="SUCCESS">Success</SelectItem>
                    <SelectItem value="WARNING">Warning</SelectItem>
                    <SelectItem value="ERROR">Error</SelectItem>
                    <SelectItem value="BROADCAST">Broadcast</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="min-w-0 sm:col-span-1 xl:col-span-6">
                <Select
                  value={params.priority ?? "all"}
                  onValueChange={(v) =>
                    handleFilterChange(
                      "priority",
                      v === "all" ? undefined : (v as NotificationPriority)
                    )
                  }
                >
                  <SelectTrigger className={BROADCAST_FILTER_TRIGGER_CLASS}>
                    <SelectValue placeholder="Prioritas" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">Semua prioritas</SelectItem>
                    <SelectItem value="LOW">Rendah</SelectItem>
                    <SelectItem value="NORMAL">Normal</SelectItem>
                    <SelectItem value="HIGH">Tinggi</SelectItem>
                    <SelectItem value="URGENT">Urgent</SelectItem>
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
              data.results.map((b) => (
                <article
                  key={b.id}
                  className="rounded-xl border border-border/60 bg-card p-4 shadow-sm"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0 flex-1 space-y-2">
                      <div className="flex items-start gap-2">
                        <IconBroadcast className="text-muted-foreground mt-0.5 size-5 shrink-0" />
                        <div className="min-w-0">
                          <p className="font-medium leading-snug">{b.title}</p>
                          <p className="text-muted-foreground mt-1 line-clamp-2 text-xs">
                            {b.message}
                          </p>
                        </div>
                      </div>
                      <div className="flex flex-wrap gap-2">
                        {getNotificationTypeBadge(b.notification_type)}
                        {getPriorityBadge(b.priority)}
                        {getStatusBadge(b)}
                      </div>
                      <p className="text-muted-foreground text-xs tabular-nums">
                        {(b.recipient_count ?? b.total_recipients) || 0} penerima ·{" "}
                        {formatDate(b.created_at)}
                      </p>
                    </div>
                    <div className="flex shrink-0 flex-col gap-1.5">
                      {!b.sent_at && (
                        <>
                          <Button
                            variant="outline"
                            size="icon"
                            className="size-9 cursor-pointer rounded-lg border-border/80 shadow-sm"
                            onClick={() => navigate(`${basePath}/${b.id}/edit`)}
                            title="Edit"
                          >
                            <IconPencil className="size-4" />
                          </Button>
                          <Button
                            variant="outline"
                            size="icon"
                            className="size-9 cursor-pointer rounded-lg border-border/80 text-primary shadow-sm"
                            onClick={() => setBroadcastToSend(b)}
                            disabled={sendMutation.isPending}
                            title="Kirim"
                          >
                            <IconSend className="size-4" />
                          </Button>
                        </>
                      )}
                    </div>
                  </div>
                </article>
              ))
            ) : (
              <div className="rounded-xl border border-border/60 border-dashed bg-muted/10 p-10 text-center shadow-sm">
                <p className="text-muted-foreground text-sm">
                  Tidak ada data broadcast.
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
                          className={broadcastTableHeadClass(header.column.id)}
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
                        className="border-border/40 transition-colors hover:bg-muted/40"
                      >
                        {row.getVisibleCells().map((cell) => (
                          <TableCell
                            key={cell.id}
                            className={broadcastTableCellClass(cell.column.id)}
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
                        Tidak ada data broadcast.
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
            aria-label="Paginasi broadcast"
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
                  broadcast
                </p>
                <div className="flex items-center gap-2">
                  <Label
                    htmlFor="broadcast-page-size"
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
                      id="broadcast-page-size"
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

      <AlertDialog
        open={broadcastToSend !== null}
        onOpenChange={() => setBroadcastToSend(null)}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Kirim Broadcast?</AlertDialogTitle>
            <AlertDialogDescription>
              Broadcast &quot;{broadcastToSend?.title}&quot; akan dikirim ke{" "}
              <strong>
                {broadcastToSend?.recipient_count ??
                  broadcastToSend?.total_recipients ??
                  0}{" "}
                penerima
              </strong>
              .
              <br />
              <br />
              Tindakan ini tidak dapat dibatalkan. Pastikan data sudah benar.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Batal</AlertDialogCancel>
            <AlertDialogAction
              onClick={() =>
                broadcastToSend && handleSendBroadcast(broadcastToSend)
              }
              disabled={sendMutation.isPending}
            >
              {sendMutation.isPending ? (
                <>
                  <IconLoader className="mr-2 size-4 animate-spin" />
                  Mengirim...
                </>
              ) : (
                <>
                  <IconSend className="mr-2 size-4" />
                  Ya, Kirim
                </>
              )}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  )
}
