/**
 * Shared table helpers for the admin job detail page and its lazy tabs.
 */

import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import { IconChevronLeft, IconChevronRight } from "@tabler/icons-react"

import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"
import type { JobApplication } from "@/types/job-applications"

export const EMPTY_APPLICATION_RESULTS: JobApplication[] = []

export function formatDate(v: string | null | undefined) {
  if (!v) return "-"
  return format(new Date(v), "dd MMM yyyy", { locale: idLocale })
}

export function formatDateTime(v: string | null | undefined) {
  if (!v) return "-"
  return format(new Date(v), "dd MMM yyyy HH:mm", { locale: idLocale })
}

export const MASTER_TAHAPAN_PAGE_SIZE = 20
export const APPLICATIONS_TAB_PAGE_SIZE = 20

/** Matches pelamar / admin list tables: card shell + dense header/body cells */
export const JOB_DETAIL_TABLE_SHELL =
  "overflow-hidden rounded-xl border border-border/60 bg-card text-card-foreground shadow-sm"
export const JD_HEADER_ROW = "border-border/60 bg-muted/35 hover:bg-muted/35"
export const JD_BODY_ROW =
  "border-border/40 transition-colors hover:bg-muted/40 data-[state=selected]:bg-primary/[0.06]"
export const jdTh = (extra?: string) =>
  cn(
    "h-11 border-border/50 px-3 py-2 text-left align-middle text-sm font-semibold text-muted-foreground first:pl-4 last:pr-4 sm:first:pl-5 sm:last:pr-5",
    extra
  )
export const jdTd = (extra?: string) =>
  cn(
    "border-border/40 px-3 py-2.5 align-middle first:pl-4 last:pr-4 sm:first:pl-5 sm:last:pr-5",
    extra
  )

export function JobDetailPagination({
  pageSize,
  currentPage,
  pageCount,
  totalCount,
  isFetching,
  itemLabel,
  onPrev,
  onNext,
}: {
  pageSize: number
  currentPage: number
  pageCount: number
  totalCount: number
  isFetching: boolean
  itemLabel: string
  onPrev: () => void
  onNext: () => void
}) {
  if (pageCount <= 1) return null
  const rangeStart = totalCount > 0 ? (currentPage - 1) * pageSize + 1 : 0
  const rangeEnd = Math.min(currentPage * pageSize, totalCount)
  return (
    <nav
      aria-label="Paginasi tabel"
      className="rounded-xl border border-border/60 bg-muted/15 px-4 py-3 shadow-sm sm:px-5 dark:bg-muted/10"
    >
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between sm:gap-4">
        <p className="text-muted-foreground text-center text-sm tabular-nums sm:text-left">
          Menampilkan{" "}
          <span className="font-medium text-foreground">
            {rangeStart}–{rangeEnd}
          </span>{" "}
          dari <span className="font-medium text-foreground">{totalCount}</span> {itemLabel}
          {isFetching ? (
            <span className="text-muted-foreground/80 ml-2 text-xs">(memuat…)</span>
          ) : null}
        </p>
        <div className="flex items-center justify-center gap-1 sm:justify-end">
          <Button
            type="button"
            variant="outline"
            size="icon"
            className="size-9 shrink-0 cursor-pointer rounded-lg border-border/80 shadow-sm disabled:opacity-40"
            disabled={currentPage <= 1 || isFetching}
            onClick={onPrev}
            aria-label="Halaman sebelumnya"
            title="Sebelumnya"
          >
            <IconChevronLeft className="size-5" stroke={2} />
          </Button>
          <div className="text-muted-foreground flex min-w-[5.5rem] items-center justify-center gap-1 px-2 text-sm tabular-nums">
            <span className="font-semibold text-foreground tabular-nums">{currentPage}</span>
            <span className="text-muted-foreground/80" aria-hidden>
              /
            </span>
            <span className="tabular-nums">{pageCount}</span>
          </div>
          <Button
            type="button"
            variant="outline"
            size="icon"
            className="size-9 shrink-0 cursor-pointer rounded-lg border-border/80 shadow-sm disabled:opacity-40"
            disabled={currentPage >= pageCount || isFetching}
            onClick={onNext}
            aria-label="Halaman berikutnya"
            title="Berikutnya"
          >
            <IconChevronRight className="size-5" stroke={2} />
          </Button>
        </div>
      </div>
    </nav>
  )
}
