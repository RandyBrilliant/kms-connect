/**
 * News table with server-side pagination, search, and filters.
 * Mirrors AdminTable style and UX.
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
  IconPencil,
  IconPlus,
  IconSearch,
  IconPinned,
  IconPinnedOff,
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
import { useNewsQuery, useDeleteNewsMutation } from "@/hooks/use-news-query"
import { toast } from "@/lib/toast"
import type { NewsItem, NewsListParams, NewsStatus } from "@/types/news"

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100]

interface NewsTableProps {
  basePath: string
}

function formatDate(value: string | null) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy HH:mm", { locale: id })
}

function statusLabel(status: NewsStatus) {
  switch (status) {
    case "DRAFT":
      return "Draf"
    case "PUBLISHED":
      return "Dipublikasikan"
    case "ARCHIVED":
      return "Diarsipkan"
    default:
      return status
  }
}

export function NewsTable({ basePath }: NewsTableProps) {
  const navigate = useNavigate()
  const [params, setParams] = useState<NewsListParams>({
    page: 1,
    page_size: 20,
    search: "",
    ordering: "-published_at",
  })
  const [searchInput, setSearchInput] = useState("")

  const { data, isLoading, isError, error } = useNewsQuery(params)
  const deleteMutation = useDeleteNewsMutation()

  const handleSearch = () => {
    setParams((p) => ({
      ...p,
      search: searchInput.trim() || undefined,
      page: 1,
    }))
  }

  const handleFilterChange = <K extends keyof NewsListParams>(
    key: K,
    value: NewsListParams[K]
  ) => {
    setParams((p) => ({ ...p, [key]: value, page: 1 }))
  }

  const handlePageChange = (page: number) => {
    setParams((p) => ({ ...p, page }))
  }

  const handleDelete = useCallback(
    async (item: NewsItem) => {
      if (!window.confirm(`Hapus berita "${item.title}"? Tindakan ini tidak dapat dibatalkan.`)) {
        return
      }
      try {
        await deleteMutation.mutateAsync(item.id)
        toast.success("Berita dihapus", "Data berita berhasil dihapus")
      } catch {
        toast.error("Gagal menghapus", "Coba lagi nanti")
      }
    },
    [deleteMutation]
  )

  const columns = useMemo<ColumnDef<NewsItem>[]>(
    () => [
      {
        accessorKey: "title",
        header: "Judul",
        cell: ({ row }) => (
          <div className="flex items-center gap-1">
            {row.original.is_pinned && (
              <IconPinned className="text-amber-500 size-4" aria-hidden />
            )}
            <span className="font-medium line-clamp-2">{row.original.title}</span>
          </div>
        ),
      },
      {
        accessorKey: "status",
        header: "Status",
        cell: ({ row }) => {
          const status = row.original.status
          let variant: "default" | "secondary" | "outline" = "outline"
          if (status === "PUBLISHED") variant = "default"
          if (status === "DRAFT") variant = "secondary"
          return (
            <Badge variant={variant} className="gap-1">
              {status === "PUBLISHED" ? <IconPinnedOff className="size-3" /> : null}
              {statusLabel(status)}
            </Badge>
          )
        },
      },
      {
        accessorKey: "published_at",
        header: "Diterbitkan",
        cell: ({ row }) => formatDate(row.original.published_at),
      },
      {
        accessorKey: "updated_at",
        header: "Diperbarui",
        cell: ({ row }) => formatDate(row.original.updated_at),
      },
      {
        accessorKey: "is_pinned",
        header: "Disematkan",
        cell: ({ row }) =>
          row.original.is_pinned ? (
            <Badge variant="outline">Ya</Badge>
          ) : (
            <Badge variant="outline" className="text-muted-foreground">
              Tidak
            </Badge>
          ),
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
                onClick={() => navigate(`${basePath}/${item.id}/edit`)}
                title="Edit"
              >
                <IconPencil className="size-4" />
                <span className="sr-only">Edit</span>
              </Button>
              <Button
                variant="ghost"
                size="icon"
                className="size-8 cursor-pointer text-destructive hover:text-destructive"
                onClick={() => handleDelete(item)}
                title="Hapus"
              >
                <IconTrash className="size-4" />
                <span className="sr-only">Hapus</span>
              </Button>
            </div>
          )
        },
      },
    ],
    [basePath, navigate, handleDelete]
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
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex flex-1 flex-col gap-2 sm:flex-row sm:items-center">
          <div className="relative flex-1">
            <IconSearch className="text-muted-foreground absolute left-3 top-1/2 size-4 -translate-y-1/2" />
            <Input
              placeholder="Cari judul atau konten..."
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
          <div className="flex gap-2">
            <Select
              value={params.status ?? "ALL"}
              onValueChange={(v) =>
                handleFilterChange("status", v === "ALL" ? "ALL" : (v as NewsStatus))
              }
            >
              <SelectTrigger className="w-[150px] cursor-pointer">
                <SelectValue placeholder="Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="ALL">Semua status</SelectItem>
                <SelectItem value="DRAFT">Draf</SelectItem>
                <SelectItem value="PUBLISHED">Dipublikasikan</SelectItem>
                <SelectItem value="ARCHIVED">Diarsipkan</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>
        <Button asChild className="cursor-pointer">
          <Link to={`${basePath}/new`} className="cursor-pointer">
            <IconPlus className="mr-2 size-4" />
            Tambah Berita
          </Link>
        </Button>
      </div>

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
                  <TableRow key={row.id}>
                    {row.getVisibleCells().map((cell) => (
                      <TableCell key={cell.id}>
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
                    Tidak ada data berita.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        )}
      </div>

      {data && data.count > 0 && (
        <div className="flex flex-col items-center justify-between gap-4 sm:flex-row">
          <div className="text-muted-foreground text-sm">
            Menampilkan {(currentPage - 1) * (params.page_size ?? 20) + 1} -{" "}
            {Math.min(
              currentPage * (params.page_size ?? 20),
              data.count
            )}{" "}
            dari {data.count} berita
          </div>
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <Label htmlFor="page-size" className="text-sm">
                Per halaman
              </Label>
              <Select
                value={String(params.page_size ?? 20)}
                onValueChange={(v) =>
                  handleFilterChange("page_size", Number(v))
                }
              >
                <SelectTrigger id="page-size" className="w-20 cursor-pointer">
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

