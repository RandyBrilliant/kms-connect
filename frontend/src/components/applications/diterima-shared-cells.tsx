/**
 * Shared cells for DITERIMA sub-tahapan tables (job detail + cohort interview detail).
 */

import { useNavigate } from "react-router-dom"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import { IconExternalLink } from "@tabler/icons-react"

import { Badge } from "@/components/ui/badge"
import {
  DOCUMENT_COLLECTION_STEP_LABELS,
  type JobApplication,
} from "@/types/job-applications"

export function formatDiterimaDate(v: string | null | undefined) {
  if (!v) return "-"
  return format(new Date(v), "dd MMM yyyy", { locale: idLocale })
}

/** Hasil medical badge for DITERIMA / Medical table */
export function MedicalHasilPill({ value }: { value: string | null | undefined }) {
  const v = (value || "").trim().toUpperCase()
  if (!v) {
    return <span className="text-muted-foreground text-xs">—</span>
  }
  if (v === "FIT") {
    return (
      <Badge variant="default" className="font-normal">
        FIT
      </Badge>
    )
  }
  if (v === "UNFIT") {
    return (
      <Badge variant="destructive" className="font-normal">
        UNFIT
      </Badge>
    )
  }
  return (
    <Badge variant="secondary" className="max-w-[140px] truncate font-normal">
      {value}
    </Badge>
  )
}

/** Pelamar name/email + batch link + tahapan diterima + sesi interview (muted). */
export function PelamarTahapanSesiCell({
  app,
  batchBase,
  cohortBase,
}: {
  app: JobApplication
  batchBase: string
  cohortBase: string
}) {
  const navigate = useNavigate()
  return (
    <div className="flex min-w-0 flex-col gap-1">
      <span className="font-medium leading-tight">{app.applicant_name}</span>
      <span className="text-xs text-muted-foreground">{app.applicant_email}</span>
      <div className="text-sm text-muted-foreground">
        {app.batch ? (
          <button
            type="button"
            className="inline-flex max-w-full cursor-pointer items-center gap-1 text-left text-primary underline-offset-2 hover:underline"
            onClick={() => navigate(`${batchBase}/${app.batch}`)}
          >
            <span className="truncate">
              {app.batch_tahap_label ?? app.batch_name ?? `Batch #${app.batch}`}
            </span>
            <IconExternalLink className="size-3 shrink-0" />
          </button>
        ) : (
          <span>—</span>
        )}
      </div>
      {app.diterima_current_step ? (
        <p className="text-[11px] leading-snug text-muted-foreground">
          Tahapan diterima:{" "}
          <span className="text-foreground/90">
            {DOCUMENT_COLLECTION_STEP_LABELS[app.diterima_current_step]}
          </span>
        </p>
      ) : null}
      <div className="text-[11px] leading-snug text-muted-foreground">
        {app.interview_cohort != null ? (
          <button
            type="button"
            className="inline-flex max-w-full cursor-pointer items-start gap-1 text-left text-muted-foreground underline-offset-2 hover:text-foreground hover:underline"
            onClick={() => navigate(`${cohortBase}/${app.interview_cohort}`)}
          >
            <span className="break-words">
              Sesi interview:{" "}
              {app.interview_cohort_name ?? `Sesi #${app.interview_cohort}`}
            </span>
            <IconExternalLink className="mt-0.5 size-3 shrink-0 opacity-70" />
          </button>
        ) : (
          <span>Sesi interview: —</span>
        )}
      </div>
    </div>
  )
}

export function PassportBerkasLink({ url }: { url: string | null | undefined }) {
  const u = (url || "").trim()
  if (!u) {
    return <span className="text-muted-foreground text-xs">Belum ada berkas</span>
  }
  return (
    <a
      href={u}
      target="_blank"
      rel="noopener noreferrer"
      className="inline-flex items-center gap-1 text-sm font-medium text-primary underline-offset-4 hover:underline"
    >
      Lihat file
      <IconExternalLink className="size-3.5 shrink-0" />
    </a>
  )
}

/** Ringkasan field paspor dari halaman profil pelamar. */
export function PassportDetailBlock({ app }: { app: JobApplication }) {
  const rows: { label: string; value: string }[] = []
  if (app.has_passport != null) {
    rows.push({
      label: "Memiliki paspor",
      value: app.has_passport ? "Ya" : "Tidak",
    })
  }
  const num = (app.passport_number || "").trim()
  if (num) rows.push({ label: "Nomor", value: num })
  if (app.passport_issue_date) {
    rows.push({
      label: "Tgl. terbit",
      value: formatDiterimaDate(app.passport_issue_date),
    })
  }
  if (app.passport_expiry_date) {
    rows.push({
      label: "Tgl. kadaluarsa",
      value: formatDiterimaDate(app.passport_expiry_date),
    })
  }
  const place = (app.passport_issue_place || "").trim()
  if (place) rows.push({ label: "Tempat terbit", value: place })

  if (!rows.length) {
    return (
      <span className="text-xs text-muted-foreground">Detail paspor belum diisi di profil</span>
    )
  }
  return (
    <div className="flex max-w-[16rem] flex-col gap-1 text-xs">
      {rows.map((r) => (
        <div key={r.label} className="leading-snug">
          <span className="text-muted-foreground">{r.label}: </span>
          <span className="text-foreground">{r.value}</span>
        </div>
      ))}
    </div>
  )
}
