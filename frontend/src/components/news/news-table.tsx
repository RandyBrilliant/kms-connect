/**
 * News table with server-side pagination, search, and filters.
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
  IconChevronLeft,
  IconChevronRight,
  IconLayoutRows,
  IconNews,
  IconPencil,
  IconPinned,
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
import { useNewsQuery, useDeleteNewsMutation } from "@/hooks/use-news-query"
import { useIsMobile } from "@/hooks/use-mobile"
import { toast } from "@/lib/toast"
import { cn } from "@/lib/utils"
import type { NewsItem, NewsListParams, NewsStatus } from "@/types/news"

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100]

const NEWS_FILTER_TRIGGER_CLASS =
  "h-9 w-full min-w-0 cursor-pointer shadow-none sm:min-h-0"

/** DRF ordering — NewsViewSet.ordering_fields */
const SORT_FIELD = {
  judul: "title",
  diterbitkan: "published_at",
  diperbarui: "updated_at",
} as const

interface NewsTableProps {
  basePath: string
}

function formatDate(value: string | null) {
  if (!value) return "—"
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

function newsTableHeadClass(columnId: string) {
  return cn(
    "h-11 border-border/50 px-3 py-2 text-left align-middle first:pl-4 last:pr-4 sm:first:pl-5 sm:last:pr-5",
    columnId === "actions" && "w-[1%] whitespace-nowrap",
    (columnId === "diterbitkan" || columnId === "diperbarui") && "tabular-nums"
  )
}

function newsTableCellClass(columnId: string) {
  return cn(
    "border-border/40 px-3 py-2.5 align-middle first:pl-4 last:pr-4 sm:first:pl-5 sm:last:pr-5",
    columnId === "judul" && "max-w-[min(28rem,40vw)] whitespace-normal",
    (columnId === "diterbitkan" || columnId === "diperbarui") &&
      "text-muted-foreground tabular-nums text-sm",
    columnId === "actions" && "text-right"
  )
}

export function NewsTable({ basePath }: NewsTableProps) {
  const navigate = useNavigate()
  const isMobile = useIsMobile()
  const [params, setParams] = useState<NewsListParams>({
    page: 1,
    page_size: 20,
    ordering: "-published_at",
  })
  const [searchInput, setSearchInput] = useState("")

  const { data, isLoading, isError, error } = useNewsQuery(params)
  const deleteMutation = useDeleteNewsMutation()

  const handleSearch = useCallback(() => {
    setParams((p) => ({
      ...p,
      search: searchInput.trim() || undefined,
      page: 1,
    }))
  }, [searchInput])

  const handleFilterChange = useCallback(
    <K extends keyof NewsListParams>(key: K, value: NewsListParams[K]) => {
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
    async (item: NewsItem) => {
      if (
        !window.confirm(
          `Hapus berita "${item.title}"? Tindakan ini tidak dapat dibatalkan.`
        )
      ) {
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
            {row.original.is_pinned ? (
              <IconPinned className="mt-0.5 size-4 shrink-0 text-amber-500" aria-hidden />
            ) : null}
            <span className="min-w-0 font-medium leading-snug">{row.original.title}</span>
          </div>
        ),
      },
      {
        id: "status",
        accessorKey: "status",
        header: "Status",
        cell: ({ row }) => {
          const status = row.original.status
          let variant: "default" | "secondary" | "outline" = "outline"
          if (status === "PUBLISHED") variant = "default"
          if (status === "DRAFT") variant = "secondary"
          return (
            <Badge variant={variant} className="shadow-sm">
              {statusLabel(status)}
            </Badge>
          )
        },
      },
      {
        id: "diterbitkan",
        accessorKey: "published_at",
        header: () => (
          <SortableColumnHead
            field={SORT_FIELD.diterbitkan}
            label="Diterbitkan"
            ordering={params.ordering}
            onSort={handleSortColumn}
          />
        ),
        cell: ({ row }) => formatDate(row.original.published_at),
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
        cell: ({ row }) => formatDate(row.original.updated_at),
      },
      {
        id: "is_pinned",
        accessorKey: "is_pinned",
        header: "Disematkan",
        cell: ({ row }) =>
          row.original.is_pinned ? (
            <Badge variant="outline" className="border-border/80 shadow-sm">
              Ya
            </Badge>
          ) : (
            <Badge variant="outline" className="border-border/80 text-muted-foreground">
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
      },
    ],
    [basePath, navigate, params.ordering, handleSortColumn, handleDelete]
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

  const goEdit = (id: number) => navigate(`${basePath}/${id}/edit`)

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
        aria-label="Pencarian dan filter berita"
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
                  placeholder="Cari judul atau konten…"
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
                <Link to={`${basePath}/new`} className="cursor-pointer">
                  <IconPlus className="mr-2 size-4 shrink-0" />
                  {isMobile ? "Tambah" : "Tambah Berita"}
                </Link>
              </Button>
            </div>
          </div>
        </div>

        <div className="px-4 py-3 sm:px-5 sm:py-4">
          <p className="text-muted-foreground sr-only">Filter daftar berita</p>
          <div className="grid grid-cols-1 gap-2 xl:grid-cols-12 xl:gap-2">
            <div className="min-w-0 xl:col-span-12">
              <Select
                value={params.status ?? "ALL"}
                onValueChange={(v) =>
                  handleFilterChange(
                    "status",
                    v === "ALL" ? "ALL" : (v as NewsStatus)
                  )
                }
              >
                <SelectTrigger className={NEWS_FILTER_TRIGGER_CLASS}>
                  <SelectValue placeholder="Status berita" />
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
        </div>
      </section>

      {isMobile ? (
        <div className="flex flex-col gap-3">
          {isLoading ? (
            <div className="flex min-h-[12rem] items-center justify-center rounded-xl border border-border/60 bg-muted/10 shadow-sm">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : data?.results && data.results.length > 0 ? (
            data.results.map((news) => (
              <article
                key={news.id}
                role="button"
                tabIndex={0}
                className="rounded-xl border border-border/60 bg-card p-4 text-left shadow-sm transition-colors hover:border-border hover:bg-muted/15"
                onClick={() => goEdit(news.id)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" || e.key === " ") {
                    e.preventDefault()
                    goEdit(news.id)
                  }
                }}
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0 flex-1 space-y-3">
                    <div className="flex items-start gap-2.5">
                      <IconNews className="text-muted-foreground mt-0.5 size-5 shrink-0" />
                      <div className="min-w-0">
                        <p className="flex items-start gap-1.5 font-medium leading-snug">
                          {news.is_pinned ? (
                            <IconPinned className="mt-0.5 size-4 shrink-0 text-amber-500" />
                          ) : null}
                          <span>{news.title}</span>
                        </p>
                      </div>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      {(() => {
                        const status = news.status
                        let variant: "default" | "secondary" | "outline" = "outline"
                        if (status === "PUBLISHED") variant = "default"
                        if (status === "DRAFT") variant = "secondary"
                        return (
                          <Badge variant={variant} className="text-xs">
                            {statusLabel(status)}
                          </Badge>
                        )
                      })()}
                      {news.is_pinned ? (
                        <Badge variant="outline" className="text-xs">
                          Disematkan
                        </Badge>
                      ) : null}
                    </div>
                    <div className="grid grid-cols-1 gap-1 border-t border-border/50 pt-3 text-xs">
                      <p className="text-muted-foreground">
                        Diterbitkan: {formatDate(news.published_at)}
                      </p>
                      <p className="text-muted-foreground">
                        Diperbarui: {formatDate(news.updated_at)}
                      </p>
                    </div>
                  </div>
                  <div
                    className="flex shrink-0 flex-col gap-1.5"
                    onClick={(e) => e.stopPropagation()}
                  >
                    <Button
                      variant="outline"
                      size="icon"
                      className="size-9 cursor-pointer rounded-lg border-border/80 shadow-sm"
                      onClick={() => navigate(`${basePath}/${news.id}/edit`)}
                      title="Edit"
                    >
                      <IconPencil className="size-4" />
                    </Button>
                    <Button
                      variant="outline"
                      size="icon"
                      className="size-9 cursor-pointer rounded-lg border-border/80 text-destructive shadow-sm hover:bg-destructive/10"
                      onClick={() => handleDelete(news)}
                      title="Hapus"
                    >
                      <IconTrash className="size-4" />
                    </Button>
                  </div>
                </div>
              </article>
            ))
          ) : (
            <div className="rounded-xl border border-border/60 border-dashed bg-muted/10 p-10 text-center shadow-sm">
              <p className="text-muted-foreground text-sm">Tidak ada data berita.</p>
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
                        className={newsTableHeadClass(header.column.id)}
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
                      onClick={() => goEdit(row.original.id)}
                    >
                      {row.getVisibleCells().map((cell) => (
                        <TableCell
                          key={cell.id}
                          className={newsTableCellClass(cell.column.id)}
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
                      Tidak ada data berita.
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
          aria-label="Paginasi daftar berita"
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
                berita
              </p>
              <div className="flex items-center gap-2">
                <Label
                  htmlFor="news-page-size"
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
                    id="news-page-size"
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
