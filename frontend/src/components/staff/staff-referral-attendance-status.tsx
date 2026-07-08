import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import { IconCircleCheck, IconCircleDashed } from "@tabler/icons-react"

import type { StaffReferralApplicationSummary } from "@/types/applicant"
import {
  APPLICATION_STATUS_LABELS,
  type ApplicationStatus,
} from "@/types/job-applications"

/** Tahapan yang menampilkan konfirmasi kehadiran pelamar di portal staff. */
const STAFF_ATTENDANCE_STAGES: ApplicationStatus[] = [
  "PRA_SELEKSI",
  "INTERVIEW",
  "DITERIMA",
  "BERANGKAT",
  "SELESAI",
]

function formatDateTime(value: string | null | undefined) {
  if (!value) return null
  return format(new Date(value), "dd MMM yyyy, HH:mm", { locale: idLocale })
}

function stageAttendanceLabel(
  summary: StaffReferralApplicationSummary,
  stage: ApplicationStatus
): { text: string; confirmed: boolean } {
  const reached = summary.reached_stages?.includes(stage) ?? summary.status === stage
  if (!reached) {
    return { text: "Belum mencapai tahapan", confirmed: false }
  }

  if (stage === "SELESAI") {
    return { text: "Selesai", confirmed: true }
  }

  const markedAt = summary.attendance_marked_at_by_stage?.[stage] ?? null
  if (markedAt) {
    const when = formatDateTime(markedAt)
    return { text: when ? `Hadir (${when})` : "Hadir", confirmed: true }
  }

  return { text: "Belum konfirmasi", confirmed: false }
}

function AttendanceBadge({ confirmed, text }: { confirmed: boolean; text: string }) {
  if (confirmed) {
    return (
      <span className="inline-flex items-center gap-1 text-green-600">
        <IconCircleCheck className="size-3.5 shrink-0" />
        {text}
      </span>
    )
  }
  return (
    <span className="inline-flex items-center gap-1 text-amber-600">
      <IconCircleDashed className="size-3.5 shrink-0" />
      {text}
    </span>
  )
}

/**
 * Konfirmasi kehadiran pelamar per tahapan — untuk tampilan staff rujukan.
 */
export function StaffReferralAttendanceStatus({
  summary,
  compact = false,
  className,
}: {
  summary: StaffReferralApplicationSummary
  compact?: boolean
  className?: string
}) {
  const reachedAttendanceStages = STAFF_ATTENDANCE_STAGES.filter(
    (stage) =>
      summary.reached_stages?.includes(stage) || summary.status === stage
  )

  const diterimaItems =
    summary.reached_stages?.includes("DITERIMA") ||
    summary.status === "DITERIMA"
      ? summary.document_collection_progress?.items ?? []
      : []

  const pendingStages = reachedAttendanceStages.filter((stage) => {
    if (stage === "SELESAI") return false
    if (stage === "DITERIMA") {
      return !summary.attendance_marked_at_by_stage?.DITERIMA
    }
    return !summary.attendance_marked_at_by_stage?.[stage]
  })

  const pendingDiterimaSteps = diterimaItems.filter((item) => !item.confirmed)

  if (!reachedAttendanceStages.length && !diterimaItems.length) {
    return (
      <span className={`text-muted-foreground text-xs ${className ?? ""}`}>
        Belum ada tahapan dengan konfirmasi kehadiran
      </span>
    )
  }

  if (compact) {
    const parts: string[] = []
    for (const stage of ["PRA_SELEKSI", "INTERVIEW"] as ApplicationStatus[]) {
      if (!summary.reached_stages?.includes(stage) && summary.status !== stage) continue
      const { confirmed } = stageAttendanceLabel(summary, stage)
      parts.push(
        `${APPLICATION_STATUS_LABELS[stage]}: ${confirmed ? "Hadir" : "Belum"}`
      )
    }
    if (summary.reached_stages?.includes("DITERIMA") || summary.status === "DITERIMA") {
      const confirmedCount = diterimaItems.filter((i) => i.confirmed).length
      if (diterimaItems.length) {
        parts.push(`Diterima: ${confirmedCount}/${diterimaItems.length} sub-tahap`)
      }
    }
    if (parts.length === 0 && pendingStages.length === 0 && pendingDiterimaSteps.length === 0) {
      return (
        <span className={`text-muted-foreground text-xs ${className ?? ""}`}>
          —
        </span>
      )
    }
    return (
      <div className={`flex flex-col gap-0.5 text-xs ${className ?? ""}`}>
        {parts.map((line) => (
          <span key={line} className="text-muted-foreground">
            {line}
          </span>
        ))}
        {(pendingStages.length > 0 || pendingDiterimaSteps.length > 0) && (
          <span className="font-medium text-amber-600">
            Menunggu konfirmasi pelamar
          </span>
        )}
      </div>
    )
  }

  return (
    <div className={`space-y-3 ${className ?? ""}`}>
      <dl className="space-y-2">
        {STAFF_ATTENDANCE_STAGES.map((stage) => {
          const reached =
            summary.reached_stages?.includes(stage) || summary.status === stage
          if (!reached) return null
          const { text, confirmed } = stageAttendanceLabel(summary, stage)
          return (
            <div
              key={stage}
              className="flex flex-col gap-0.5 border-b pb-2 last:border-0 last:pb-0"
            >
              <dt className="text-muted-foreground text-xs">
                {APPLICATION_STATUS_LABELS[stage]}
              </dt>
              <dd className="text-sm">
                <AttendanceBadge confirmed={confirmed} text={text} />
              </dd>
            </div>
          )
        })}
      </dl>

      {diterimaItems.length > 0 ? (
        <div className="space-y-2">
          <p className="text-muted-foreground text-xs font-medium">
            Konfirmasi sub-tahapan Diterima
          </p>
          <ul className="space-y-1.5">
            {diterimaItems.map((item) => (
              <li
                key={item.code}
                className="flex flex-col gap-0.5 text-xs sm:flex-row sm:items-center sm:justify-between"
              >
                <span className="text-foreground">{item.label}</span>
                <AttendanceBadge
                  confirmed={item.confirmed}
                  text={
                    item.confirmed && item.confirmed_at
                      ? formatDateTime(item.confirmed_at) ?? "Dikonfirmasi"
                      : "Belum dikonfirmasi"
                  }
                />
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </div>
  )
}
