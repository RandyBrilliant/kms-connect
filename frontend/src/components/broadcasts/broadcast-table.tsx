/**
 * Broadcast table with server-side pagination, search, and filters.
 * Follows the same pattern as NewsTable and AdminTable.
 */

import { useState, useMemo, useCallback } from "react"
import { useNavigate } from "react-router-dom"
import {
  flexRender,
  getCoreRowModel,
  useReactTable,
  type ColumnDef,
} from "@tanstack/react-table"
import {
  IconPencil,
  IconPlus,
  IconSearch,
  IconSend,
  IconLoader,
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
import { toast } from "@/lib/toast"
import type { Broadcast, BroadcastsListParams, NotificationType, NotificationPriority } from "@/types/notification"

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100]

interface BroadcastTableProps {
  basePath: string
}

function formatDate(value: string | null) {
  if (!value) return "-"
  try {
    return format(new Date(value), "dd MMM yyyy HH:mm", { locale: idLocale })
  } catch {
    return "-"
  }
}

/**
 * Get badge for notification type
 */
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
  const { variant, label } = config[type] || { variant: "default" as const, label: type }
  return (
    <Badge variant={variant} className="text-xs">
      {label}
    </Badge>
  )
}

/**
 * Get badge for priority
 */
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
    <Badge variant="outline" className={className + " text-xs"}>
      {label}
    </Badge>
  )
}

/**
 * Get status badge with icon
 */
function getStatusBadge(broadcast: Broadcast) {
  if (broadcast.sent_at) {
    return (
      <Badge variant="secondary" className="gap-1 text-xs text-green-700">
        <IconCheck className="size-3" />
        Terkirim
      </Badge>
    )
  }
  if (broadcast.scheduled_at && new Date(broadcast.scheduled_at) > new Date()) {
    return (
      <Badge variant="outline" className="gap-1 text-xs text-blue-700">
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

export function BroadcastTable({ basePath }: BroadcastTableProps) {
  const navigate = useNavigate()
  const [params, setParams] = useState<BroadcastsListParams>({
    page: 1,
    page_size: 20,
    ordering: "-created_at",
  })
  const [searchInput, setSearchInput] = useState("")
  const [broadcastToSend, setBroadcastToSend] = useState<Broadcast | null>(null)

  const { data, isLoading, isError, error } = useBroadcastsQuery(params)
  const sendMutation = useSendBroadcastMutation()

  const handleSearch = () => {
    setParams((p) => ({
      ...p,
      search: searchInput.trim() || undefined,
      page: 1,
    }))
  }

  const handleFilterChange = <K extends keyof BroadcastsListParams>(
    key: K,
    value: BroadcastsListParams[K]
  ) => {
    setParams((p) => ({ ...p, [key]: value, page: 1 }))
  }

  const handlePageChange = (page: number) => {
    setParams((p) => ({ ...p, page }))
  }

  const handleSendBroadcast = useCallback(
    async (broadcast: Broadcast) => {
      try {
        await sendMutation.mutateAsync(broadcast.id)
        toast.success("Broadcast Terkirim", "Broadcast berhasil dikirim ke semua penerima")
        setBroadcastToSend(null)
      } catch (error: any) {
        const message = error?.response?.data?.message || "Gagal mengirim broadcast"
        toast.error("Gagal Mengirim", message)
      }
    },
    [sendMutation]
  )

  const columns = useMemo<ColumnDef<Broadcast>[]>(
    () => [
      {
        accessorKey: "title",
        header: "Judul",
        cell: ({ row }) => (
          <div className="max-w-xs">
            <p className="font-medium line-clamp-2">{row.original.title}</p>
            <p className="text-muted-foreground mt-0.5 text-xs line-clamp-1">
              {row.original.message}
            </p>
          </div>
        ),
      },
      {
        accessorKey: "notification_type",
        header: "Tipe",
        cell: ({ row }) => getNotificationTypeBadge(row.original.notification_type),
      },
      {
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
        accessorKey: "recipient_count",
        header: "Penerima",
        cell: ({ row }) => (
          <span className="text-sm">{row.original.recipient_count || 0} orang</span>
        ),
      },
      {
        accessorKey: "created_at",
        header: "Dibuat",
        cell: ({ row }) => (
          <div className="text-xs">
            <p>{formatDate(row.original.created_at)}</p>
            {row.original.sent_at && (
              <p className="text-muted-foreground mt-0.5">
                Dikirim: {formatDate(row.original.sent_at)}
              </p>
            )}
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
            <div className="flex items-center gap-1">
              {canEdit && (
                <Button
                  variant="ghost"
                  size="icon"
                  className="size-8 cursor-pointer"
                  onClick={() => navigate(`${basePath}/${broadcast.id}/edit`)}
                  title="Edit"
                >
                  <IconPencil className="size-4" />
                  <span className="sr-only">Edit</span>
                </Button>
              )}
              {canSend && (
                <Button
                  variant="ghost"
                  size="icon"
                  className="size-8 cursor-pointer text-primary hover:text-primary"
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
    [navigate, basePath, sendMutation.isPending]
  )

  const table = useReactTable({
    data: data?.results ?? [],
    columns,
    getCoreRowModel: getCoreRowModel(),
    manualPagination: true,
    pageCount: data ? Math.ceil(data.count / params.page_size!) : 0,
  })

  const totalPages = data ? Math.ceil(data.count / params.page_size!) : 0
  const currentPage = params.page ?? 1

  return (
    <>
      <div className="space-y-4">
        {/* Filters and Search */}
        <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div className="grid gap-4 md:grid-cols-3">
            {/* Search */}
            <div className="space-y-1.5">
              <Label htmlFor="search">Cari</Label>
              <div className="flex gap-2">
                <Input
                  id="search"
                  placeholder="Cari judul atau pesan..."
                  value={searchInput}
                  onChange={(e) => setSearchInput(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && handleSearch()}
                />
                <Button variant="outline" size="icon" onClick={handleSearch}>
                  <IconSearch className="size-4" />
                </Button>
              </div>
            </div>

            {/* Type Filter */}
            <div className="space-y-1.5">
              <Label htmlFor="type">Tipe</Label>
              <Select
                value={params.notification_type ?? "all"}
                onValueChange={(v) =>
                  handleFilterChange("notification_type", v === "all" ? undefined : v as NotificationType)
                }
              >
                <SelectTrigger id="type">
                  <SelectValue placeholder="Semua Tipe" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Semua Tipe</SelectItem>
                  <SelectItem value="INFO">Info</SelectItem>
                  <SelectItem value="SUCCESS">Success</SelectItem>
                  <SelectItem value="WARNING">Warning</SelectItem>
                  <SelectItem value="ERROR">Error</SelectItem>
                  <SelectItem value="BROADCAST">Broadcast</SelectItem>
                </SelectContent>
              </Select>
            </div>

            {/* Priority Filter */}
            <div className="space-y-1.5">
              <Label htmlFor="priority">Prioritas</Label>
              <Select
                value={params.priority ?? "all"}
                onValueChange={(v) =>
                  handleFilterChange("priority", v === "all" ? undefined : v as NotificationPriority)
                }
              >
                <SelectTrigger id="priority">
                  <SelectValue placeholder="Semua Prioritas" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Semua Prioritas</SelectItem>
                  <SelectItem value="LOW">Rendah</SelectItem>
                  <SelectItem value="NORMAL">Normal</SelectItem>
                  <SelectItem value="HIGH">Tinggi</SelectItem>
                  <SelectItem value="URGENT">Urgent</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* Create Button */}
          <Button onClick={() => navigate(`${basePath}/new`)} className="gap-2">
            <IconPlus className="size-4" />
            Buat Broadcast
          </Button>
        </div>

        {/* Table */}
        <div className="rounded-md border">
          <Table>
            <TableHeader>
              {table.getHeaderGroups().map((headerGroup) => (
                <TableRow key={headerGroup.id}>
                  {headerGroup.headers.map((header) => (
                    <TableHead key={header.id}>
                      {header.isPlaceholder
                        ? null
                        : flexRender(header.column.columnDef.header, header.getContext())}
                    </TableHead>
                  ))}
                </TableRow>
              ))}
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <TableRow>
                  <TableCell colSpan={columns.length} className="h-24 text-center">
                    <div className="flex items-center justify-center gap-2">
                      <IconLoader className="size-5 animate-spin" />
                      <span>Memuat data...</span>
                    </div>
                  </TableCell>
                </TableRow>
              ) : isError ? (
                <TableRow>
                  <TableCell colSpan={columns.length} className="h-24 text-center">
                    <div className="flex flex-col items-center gap-2 text-destructive">
                      <IconAlertCircle className="size-8" />
                      <p className="font-medium">Gagal memuat data</p>
                      <p className="text-muted-foreground text-sm">
                        {error instanceof Error ? error.message : "Terjadi kesalahan"}
                      </p>
                    </div>
                  </TableCell>
                </TableRow>
              ) : table.getRowModel().rows.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={columns.length} className="h-24 text-center">
                    <p className="text-muted-foreground">Tidak ada data broadcast</p>
                  </TableCell>
                </TableRow>
              ) : (
                table.getRowModel().rows.map((row) => (
                  <TableRow key={row.id} data-state={row.getIsSelected() && "selected"}>
                    {row.getVisibleCells().map((cell) => (
                      <TableCell key={cell.id}>
                        {flexRender(cell.column.columnDef.cell, cell.getContext())}
                      </TableCell>
                    ))}
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </div>

        {/* Pagination */}
        {data && totalPages > 1 && (
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Label htmlFor="pageSize" className="text-sm">
                Tampilkan
              </Label>
              <Select
                value={String(params.page_size)}
                onValueChange={(v) => handleFilterChange("page_size", Number(v))}
              >
                <SelectTrigger id="pageSize" className="w-20">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {PAGE_SIZE_OPTIONS.map((size) => (
                    <SelectItem key={size} value={String(size)}>
                      {size}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <span className="text-muted-foreground text-sm">
                dari {data.count} broadcast
              </span>
            </div>

            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => handlePageChange(currentPage - 1)}
                disabled={currentPage <= 1}
              >
                Sebelumnya
              </Button>
              <span className="text-sm">
                Halaman {currentPage} dari {totalPages}
              </span>
              <Button
                variant="outline"
                size="sm"
                onClick={() => handlePageChange(currentPage + 1)}
                disabled={currentPage >= totalPages}
              >
                Selanjutnya
              </Button>
            </div>
          </div>
        )}
      </div>

      {/* Send Confirmation Dialog */}
      <AlertDialog open={broadcastToSend !== null} onOpenChange={() => setBroadcastToSend(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Kirim Broadcast?</AlertDialogTitle>
            <AlertDialogDescription>
              Broadcast "{broadcastToSend?.title}" akan dikirim ke{" "}
              <strong>{broadcastToSend?.recipient_count || 0} penerima</strong>.
              <br />
              <br />
              Tindakan ini tidak dapat dibatalkan. Pastikan data sudah benar.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Batal</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => broadcastToSend && handleSendBroadcast(broadcastToSend)}
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
