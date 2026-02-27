/**
 * Displays the append-only audit trail for a JobApplication's status changes.
 */

import { format } from "date-fns"
import { id } from "date-fns/locale"
import { IconCircleCheck } from "@tabler/icons-react"

import { APPLICATION_STATUS_LABELS, type ApplicationStatusHistoryEntry } from "@/types/job-applications"
import { cn } from "@/lib/utils"

interface StatusHistoryTimelineProps {
  history: ApplicationStatusHistoryEntry[]
}

export function StatusHistoryTimeline({ history }: StatusHistoryTimelineProps) {
  if (!history.length) {
    return (
      <p className="text-muted-foreground text-sm">Belum ada riwayat status.</p>
    )
  }

  return (
    <ol className="relative ml-2 border-l border-border">
      {history.map((entry, idx) => {
        const isLast = idx === history.length - 1
        return (
          <li key={entry.id} className="mb-6 ml-4 last:mb-0">
            <span
              className={cn(
                "absolute -left-[9px] flex size-[18px] items-center justify-center rounded-full ring-2 ring-background",
                isLast
                  ? "bg-primary text-primary-foreground"
                  : "bg-muted text-muted-foreground"
              )}
            >
              <IconCircleCheck className="size-3" />
            </span>
            <div className="flex flex-col gap-0.5">
              <p className="text-sm font-medium leading-none">
                {APPLICATION_STATUS_LABELS[entry.to_status] ?? entry.to_status}
              </p>
              {entry.from_status && (
                <p className="text-muted-foreground text-xs">
                  Dari:{" "}
                  {APPLICATION_STATUS_LABELS[entry.from_status as keyof typeof APPLICATION_STATUS_LABELS] ??
                    entry.from_status}
                </p>
              )}
              <time className="text-muted-foreground text-xs">
                {format(new Date(entry.changed_at), "dd MMM yyyy, HH:mm", {
                  locale: id,
                })}
              </time>
              {entry.changed_by_name && (
                <p className="text-muted-foreground text-xs">
                  oleh {entry.changed_by_name}
                </p>
              )}
              {entry.note && (
                <p className="mt-1 rounded-md bg-muted px-2 py-1 text-xs text-foreground">
                  {entry.note}
                </p>
              )}
            </div>
          </li>
        )
      })}
    </ol>
  )
}
