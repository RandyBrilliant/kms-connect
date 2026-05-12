import type { StaffReferralApplicationSummary } from "@/types/applicant"

/**
 * Tahapan lamaran + sub-tahapan Diterima (bila ada) untuk tampilan staff rujukan.
 */
export function StaffReferralLamaranProgress({
  applicationsSummary,
  className,
}: {
  applicationsSummary: StaffReferralApplicationSummary[] | undefined | null
  className?: string
}) {
  if (!applicationsSummary?.length) {
    return (
      <span className={`text-muted-foreground text-xs ${className ?? ""}`}>
        Belum ada lamaran
      </span>
    )
  }

  const app = applicationsSummary[0]
  const jobLine = [app.job_title?.trim() || "Tanpa lowongan"]
  if (app.batch_name?.trim()) jobLine.push(app.batch_name.trim())
  const cohort = app.interview_cohort_name?.trim()

  return (
    <div className={`flex flex-col gap-0.5 text-xs ${className ?? ""}`}>
      <span className="text-foreground font-medium">
        {app.status_label || app.status || "—"}
      </span>
      {app.status === "DITERIMA" && app.diterima_sub_stage_label ? (
        <span className="text-muted-foreground">
          Sub-tahapan: {app.diterima_sub_stage_label}
        </span>
      ) : null}
      <span className="text-muted-foreground">{jobLine.join(" · ")}</span>
      {cohort ? (
        <span className="text-muted-foreground">Sesi interview: {cohort}</span>
      ) : null}
    </div>
  )
}
