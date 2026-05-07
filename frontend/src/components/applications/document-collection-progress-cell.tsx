import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import { IconCircleCheck, IconCircleDashed } from "@tabler/icons-react"

import type { DocumentCollectionStepCode, JobApplication } from "@/types/job-applications"

function formatDateTime(value: string | null | undefined) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy HH:mm", { locale: idLocale })
}

interface Props {
  app: JobApplication
  /**
   * When provided, shows the confirmation status for this specific step
   * (used in the DITERIMA sub-step tab view to surface per-step pelamar
   * confirmation prominently).
   */
  highlightStep?: DocumentCollectionStepCode
}

/** Confirmation-focused cell for DITERIMA admin table. */
export function DocumentCollectionProgressCell({ app, highlightStep }: Props) {
  if (highlightStep) {
    // Per-step confirmation view used inside DITERIMA sub-step tabs.
    const stepItems = app.document_collection_progress?.items ?? []
    const stepItem = stepItems.find((i) => i.code === highlightStep)
    const confirmedAt = app.diterima_step_confirmations?.[highlightStep]

    return (
      <div className="flex flex-col gap-0.5">
        {confirmedAt ? (
          <span className="inline-flex items-center gap-1 text-xs text-green-600">
            <IconCircleCheck className="size-3.5 shrink-0" />
            Dikonfirmasi
          </span>
        ) : (
          <span className="inline-flex items-center gap-1 text-xs text-amber-600">
            <IconCircleDashed className="size-3.5 shrink-0" />
            Belum dikonfirmasi
          </span>
        )}
        {confirmedAt && (
          <span className="text-[11px] text-muted-foreground">
            {formatDateTime(confirmedAt)}
          </span>
        )}
        {stepItem && !stepItem.done && (
          <span className="text-[11px] text-muted-foreground">Data belum dilengkapi</span>
        )}
      </div>
    )
  }

  return app.pengumpulan_dokumen_confirmed_at ? (
    <div className="flex flex-col gap-0.5">
      <span className="inline-flex items-center gap-1 text-xs text-green-600">
        <IconCircleCheck className="size-3.5 shrink-0" />
        Dikonfirmasi
      </span>
      <span className="text-[11px] text-muted-foreground">
        {formatDateTime(app.pengumpulan_dokumen_confirmed_at)}
      </span>
    </div>
  ) : (
    <span className="inline-flex items-center gap-1 text-xs text-amber-600">
      <IconCircleDashed className="size-3.5 shrink-0" />
      Belum dikonfirmasi
    </span>
  )
}
