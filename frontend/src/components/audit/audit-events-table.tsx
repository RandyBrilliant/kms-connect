/**
 * Audit events table — read-only, cursor pagination, Master Admin only.
 */

import { useMemo, useState } from "react"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import {
  IconChevronLeft,
  IconChevronRight,
  IconSearch,
  IconHistory,
} from "@tabler/icons-react"

import { cursorFromUrl } from "@/api/audit"
import { useAuditEventsQuery } from "@/hooks/use-audit-query"
import { useDebounce } from "@/hooks/use-debounce"
import { Badge } from "@/components/ui/badge"
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
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Card, CardContent } from "@/components/ui/card"
import { cn } from "@/lib/utils"
import {
  AUDIT_ACTION_LABELS,
  AUDIT_RESOURCE_LABELS,
  type AuditAction,
  type AuditEvent,
  type AuditEventsListParams,
  type AuditResourceType,
} from "@/types/audit"

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100]

const ACTION_OPTIONS = Object.entries(AUDIT_ACTION_LABELS) as [AuditAction, string][]
const RESOURCE_OPTIONS = Object.entries(AUDIT_RESOURCE_LABELS) as [
  AuditResourceType,
  string,
][]

function formatWhen(iso: string) {
  try {
    return format(new Date(iso), "dd MMM yyyy HH:mm:ss", { locale: idLocale })
  } catch {
    return "—"
  }
}

function actionVariant(
  action: AuditAction
): "default" | "secondary" | "destructive" | "outline" {
  if (action === "LOGIN_FAILED" || action === "DELETE" || action === "REJECT") {
    return "destructive"
  }
  if (action === "LOGIN" || action === "CREATE" || action === "APPROVE" || action === "ACTIVATE") {
    return "default"
  }
  if (action === "EXPORT" || action === "STATUS_CHANGE") {
    return "secondary"
  }
  return "outline"
}

export function AuditEventsTable() {
  const [pageSize, setPageSize] = useState(20)
  const [cursor, setCursor] = useState<string | null>(null)
  const [searchInput, setSearchInput] = useState("")
  const [actionFilter, setActionFilter] = useState<AuditAction | "ALL">("ALL")
  const [resourceFilter, setResourceFilter] = useState<AuditResourceType | "ALL">(
    "ALL"
  )
  const [selected, setSelected] = useState<AuditEvent | null>(null)

  const debouncedSearch = useDebounce(searchInput.trim(), 300)

  const listParams = useMemo<AuditEventsListParams>(
    () => ({
      page_size: pageSize,
      cursor,
      search: debouncedSearch || undefined,
      ...(actionFilter !== "ALL" ? { action: actionFilter } : {}),
      ...(resourceFilter !== "ALL" ? { resource_type: resourceFilter } : {}),
    }),
    [pageSize, cursor, debouncedSearch, actionFilter, resourceFilter]
  )

  const { data, isLoading, isError, error, isFetching } =
    useAuditEventsQuery(listParams)

  const rows = data?.results ?? []
  const nextCursor = cursorFromUrl(data?.next)
  const prevCursor = cursorFromUrl(data?.previous)

  function resetCursorAnd(update: () => void) {
    setCursor(null)
    update()
  }

  return (
    <div className="flex flex-col gap-4">
      <Card>
        <CardContent className="flex flex-col gap-3 pt-6 sm:flex-row sm:flex-wrap sm:items-end">
          <div className="min-w-[12rem] flex-1 space-y-1.5">
            <Label htmlFor="audit-search">Cari</Label>
            <div className="relative">
              <IconSearch className="text-muted-foreground absolute top-1/2 left-2.5 size-4 -translate-y-1/2" />
              <Input
                id="audit-search"
                className="pl-8"
                placeholder="Ringkasan, email, label…"
                value={searchInput}
                onChange={(e) =>
                  resetCursorAnd(() => setSearchInput(e.target.value))
                }
              />
            </div>
          </div>
          <div className="w-full space-y-1.5 sm:w-44">
            <Label>Aksi</Label>
            <Select
              value={actionFilter}
              onValueChange={(v) =>
                resetCursorAnd(() =>
                  setActionFilter(v as AuditAction | "ALL")
                )
              }
            >
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Semua aksi" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="ALL">Semua aksi</SelectItem>
                {ACTION_OPTIONS.map(([value, label]) => (
                  <SelectItem key={value} value={value}>
                    {label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="w-full space-y-1.5 sm:w-44">
            <Label>Resource</Label>
            <Select
              value={resourceFilter}
              onValueChange={(v) =>
                resetCursorAnd(() =>
                  setResourceFilter(v as AuditResourceType | "ALL")
                )
              }
            >
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Semua resource" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="ALL">Semua resource</SelectItem>
                {RESOURCE_OPTIONS.map(([value, label]) => (
                  <SelectItem key={value} value={value}>
                    {label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="w-full space-y-1.5 sm:w-28">
            <Label>Per halaman</Label>
            <Select
              value={String(pageSize)}
              onValueChange={(v) =>
                resetCursorAnd(() => setPageSize(Number(v)))
              }
            >
              <SelectTrigger className="w-full">
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
        </CardContent>
      </Card>

      <div className="overflow-hidden rounded-lg border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="w-[11rem]">Waktu</TableHead>
              <TableHead>Aktor</TableHead>
              <TableHead className="w-[8rem]">Aksi</TableHead>
              <TableHead>Resource</TableHead>
              <TableHead>Ringkasan</TableHead>
              <TableHead className="w-[8rem]">IP</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              <TableRow>
                <TableCell colSpan={6} className="text-muted-foreground h-24 text-center">
                  Memuat log audit…
                </TableCell>
              </TableRow>
            ) : isError ? (
              <TableRow>
                <TableCell colSpan={6} className="text-destructive h-24 text-center">
                  {(error as Error)?.message || "Gagal memuat log audit."}
                </TableCell>
              </TableRow>
            ) : rows.length === 0 ? (
              <TableRow>
                <TableCell colSpan={6} className="text-muted-foreground h-24 text-center">
                  <div className="flex flex-col items-center gap-2">
                    <IconHistory className="size-8 opacity-40" />
                    Belum ada event audit.
                  </div>
                </TableCell>
              </TableRow>
            ) : (
              rows.map((row) => (
                <TableRow
                  key={row.id}
                  className={cn(
                    "cursor-pointer",
                    isFetching && "opacity-70"
                  )}
                  onClick={() => setSelected(row)}
                >
                  <TableCell className="text-muted-foreground tabular-nums text-sm whitespace-nowrap">
                    {formatWhen(row.created_at)}
                  </TableCell>
                  <TableCell>
                    <div className="flex flex-col">
                      <span className="font-medium">
                        {row.actor_name || row.actor_email || "—"}
                      </span>
                      {row.actor_email && row.actor_name ? (
                        <span className="text-muted-foreground text-xs">
                          {row.actor_email}
                        </span>
                      ) : null}
                      {row.actor_role ? (
                        <span className="text-muted-foreground text-xs">
                          {row.actor_role}
                        </span>
                      ) : null}
                    </div>
                  </TableCell>
                  <TableCell>
                    <Badge variant={actionVariant(row.action)}>
                      {row.action_display || AUDIT_ACTION_LABELS[row.action]}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <div className="flex flex-col">
                      <span className="text-sm">
                        {row.resource_type_display ||
                          AUDIT_RESOURCE_LABELS[row.resource_type]}
                      </span>
                      <span className="text-muted-foreground text-xs truncate max-w-[14rem]">
                        {row.resource_label || row.resource_id || "—"}
                      </span>
                    </div>
                  </TableCell>
                  <TableCell className="max-w-[20rem] whitespace-normal text-sm">
                    {row.summary}
                  </TableCell>
                  <TableCell className="text-muted-foreground font-mono text-xs">
                    {row.ip_address || "—"}
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      <div className="flex items-center justify-between gap-2">
        <p className="text-muted-foreground text-sm">
          Menampilkan {rows.length} event
          {isFetching ? " (memuat…)" : ""}
        </p>
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="sm"
            disabled={!data?.previous}
            onClick={() => setCursor(prevCursor)}
          >
            <IconChevronLeft className="size-4" />
            Sebelumnya
          </Button>
          <Button
            variant="outline"
            size="sm"
            disabled={!data?.next}
            onClick={() => setCursor(nextCursor)}
          >
            Berikutnya
            <IconChevronRight className="size-4" />
          </Button>
        </div>
      </div>

      <Sheet open={!!selected} onOpenChange={(open) => !open && setSelected(null)}>
        <SheetContent className="sm:max-w-lg overflow-y-auto">
          <SheetHeader>
            <SheetTitle>Detail event audit</SheetTitle>
            <SheetDescription>
              Catatan append-only. Tidak dapat diubah atau dihapus.
            </SheetDescription>
          </SheetHeader>
          {selected ? (
            <div className="mt-6 space-y-4 text-sm">
              <DetailRow label="Waktu" value={formatWhen(selected.created_at)} />
              <DetailRow
                label="Aktor"
                value={
                  [selected.actor_name, selected.actor_email, selected.actor_role]
                    .filter(Boolean)
                    .join(" · ") || "—"
                }
              />
              <DetailRow
                label="Aksi"
                value={
                  selected.action_display || AUDIT_ACTION_LABELS[selected.action]
                }
              />
              <DetailRow
                label="Resource"
                value={`${
                  selected.resource_type_display ||
                  AUDIT_RESOURCE_LABELS[selected.resource_type]
                } · ${selected.resource_label || selected.resource_id || "—"}`}
              />
              <DetailRow label="Ringkasan" value={selected.summary} />
              <DetailRow label="IP" value={selected.ip_address || "—"} />
              <DetailRow
                label="User agent"
                value={selected.user_agent || "—"}
              />
              <div>
                <p className="text-muted-foreground mb-1 text-xs font-medium uppercase tracking-wide">
                  Metadata
                </p>
                <pre className="bg-muted max-h-64 overflow-auto rounded-md p-3 text-xs whitespace-pre-wrap break-all">
                  {Object.keys(selected.metadata || {}).length
                    ? JSON.stringify(selected.metadata, null, 2)
                    : "—"}
                </pre>
              </div>
            </div>
          ) : null}
        </SheetContent>
      </Sheet>
    </div>
  )
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-muted-foreground mb-0.5 text-xs font-medium uppercase tracking-wide">
        {label}
      </p>
      <p className="break-words">{value}</p>
    </div>
  )
}
