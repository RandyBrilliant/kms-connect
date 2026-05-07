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

/** Inline batch-style pengumpulan dokumen summary for admin tables (DITERIMA tab). */
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

  if (!app.document_collection_progress) {
    return <span className="text-muted-foreground">-</span>
  }

  const p = app.document_collection_progress

  return (
    <div className="flex flex-col gap-1">
      <span className="font-medium">
        {p.done_count}/{p.total_count}
      </span>
      <span
        className={
          p.is_complete ? "text-xs text-green-600" : "text-xs text-muted-foreground"
        }
      >
        {p.is_complete ? "Lengkap" : "Belum lengkap"}
      </span>
      {app.pengumpulan_dokumen_confirmed_at ? (
        <span className="text-xs text-green-600">
          Dikonfirmasi: {formatDateTime(app.pengumpulan_dokumen_confirmed_at)}
        </span>
      ) : p.is_complete ? (
        <span className="text-xs text-amber-600">Menunggu konfirmasi pelamar</span>
      ) : null}
      {app.pengumpulan_dokumen_pending_labels?.length ? (
        <div className="mt-0.5">
          <p className="text-[11px] font-medium text-muted-foreground">
            Belum terpenuhi:
          </p>
          <ul className="list-disc pl-4 text-[11px] text-muted-foreground space-y-0.5">
            {app.pengumpulan_dokumen_pending_labels.slice(0, 3).map((label) => (
              <li key={label}>{label}</li>
            ))}
            {app.pengumpulan_dokumen_pending_labels.length > 3 ? (
              <li>
                +{app.pengumpulan_dokumen_pending_labels.length - 3} item lainnya
              </li>
            ) : null}
          </ul>
        </div>
      ) : null}
      <span className="text-[11px] text-muted-foreground">
        Detail sub-tahapan tersedia di tab filter Diterima.
      </span>
    </div>
  )
}
