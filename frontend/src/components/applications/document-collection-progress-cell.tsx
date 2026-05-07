import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"

import type { JobApplication } from "@/types/job-applications"

function formatDateTime(value: string | null | undefined) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy HH:mm", { locale: idLocale })
}

/** Inline batch-style pengumpulan dokumen summary for admin tables (DITERIMA tab). */
export function DocumentCollectionProgressCell({ app }: { app: JobApplication }) {
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
