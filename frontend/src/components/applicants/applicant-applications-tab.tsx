/**
 * Lamaran tab on pelamar detail: quick-assign to batch + list of applications.
 */

import { Link } from "react-router-dom"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import {
  IconClipboardList,
  IconExternalLink,
  IconMessage,
  IconMicrophone2,
  IconStack2,
} from "@tabler/icons-react"

import { ApplicationStatusBadge } from "@/components/applications/application-status-badge"
import { ApplicantLamaranQuickAssign } from "@/components/applicants/applicant-lamaran-quick-assign"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { joinAdminPath } from "@/contexts/admin-dashboard-context"
import { useApplicationsQuery } from "@/hooks/use-applications-query"
import { cn } from "@/lib/utils"
import {
  APPLICATION_STATUS_LABELS,
  DOCUMENT_COLLECTION_STEP_LABELS,
  DOCUMENT_COLLECTION_STEP_ORDER,
  type JobApplication,
} from "@/types/job-applications"

export interface ApplicantApplicationsTabProps {
  profileId?: number
  lamaranBase: string
  basePath: string
}

function LamaranApplicationCard({
  app,
  lamaranBase,
  basePath,
}: {
  app: JobApplication
  lamaranBase: string
  basePath: string
}) {
  const batchHref =
    app.batch != null ? joinAdminPath(basePath, `/batch/${app.batch}`) : null
  const cohortHref =
    app.interview_cohort != null
      ? joinAdminPath(basePath, `/sesi-interview/${app.interview_cohort}`)
      : null

  const cohortTitle =
    app.interview_cohort_name?.trim() ||
    (app.interview_cohort != null ? `Sesi #${app.interview_cohort}` : null)

  const stepIdx = app.diterima_current_step
    ? DOCUMENT_COLLECTION_STEP_ORDER.indexOf(app.diterima_current_step)
    : -1
  const stepLabel =
    app.diterima_sub_stage_label?.trim() ||
    (app.diterima_current_step
      ? DOCUMENT_COLLECTION_STEP_LABELS[app.diterima_current_step]
      : null)

  const showDiterimaTrack = app.status === "DITERIMA"

  return (
    <Card className="overflow-hidden border-border/70 py-0 shadow-sm transition-shadow hover:shadow-md">
      <CardContent className="flex flex-col gap-0 p-0">
        {/* Header */}
        <div className="flex flex-col gap-3 border-b border-border/50 bg-muted/20 px-4 py-4 sm:flex-row sm:items-start sm:justify-between sm:gap-4 sm:px-5">
          <div className="min-w-0 flex-1 space-y-1">
            <div className="flex flex-wrap items-baseline gap-x-2 gap-y-1">
              <h4 className="text-base font-semibold leading-snug text-foreground">
                {app.job_title}
              </h4>
              {app.company_name ? (
                <span className="text-muted-foreground text-sm font-normal">
                  {app.company_name}
                </span>
              ) : null}
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <ApplicationStatusBadge status={app.status} />
              <Badge variant="outline" className="text-[11px] font-normal">
                {app.assigned_by != null ? "Ditugaskan admin" : "Mandiri"}
              </Badge>
              {app.applied_at ? (
                <span className="text-muted-foreground text-xs tabular-nums">
                  Dilamar{" "}
                  {format(new Date(app.applied_at), "dd MMM yyyy", {
                    locale: idLocale,
                  })}
                </span>
              ) : null}
            </div>
          </div>
          <div className="flex shrink-0 flex-wrap items-center gap-2 sm:justify-end">
            <Button
              asChild
              variant="outline"
              size="sm"
              className="cursor-pointer shadow-xs"
            >
              <Link to={`${lamaranBase}/${app.id}?tab=chat`}>
                <IconMessage className="mr-2 size-4" />
                Chat
              </Link>
            </Button>
            <Button asChild variant="default" size="sm" className="cursor-pointer shadow-xs">
              <Link to={`${lamaranBase}/${app.id}`}>
                <IconExternalLink className="mr-2 size-4" />
                Detail lamaran
              </Link>
            </Button>
          </div>
        </div>

        {/* Pipeline: batch + interview cohort */}
        <div className="grid gap-3 px-4 py-4 sm:grid-cols-2 sm:px-5">
          <div
            className={cn(
              "rounded-xl border px-3 py-3 transition-colors",
              batchHref
                ? "border-primary/25 bg-primary/[0.04] hover:border-primary/40"
                : "border-border/60 bg-muted/15"
            )}
          >
            <div className="mb-2 flex items-center gap-2 text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
              <IconStack2 className="size-3.5 shrink-0 text-primary/80" aria-hidden />
              Batch pra-seleksi
            </div>
            {batchHref && app.batch_name ? (
              <Link
                to={batchHref}
                className="group inline-flex items-start gap-1.5 text-sm font-medium text-primary underline-offset-4 hover:underline"
              >
                <span className="min-w-0 break-words leading-snug">
                  {app.batch_tahap_label ?? app.batch_name}
                </span>
                <IconExternalLink className="mt-0.5 size-3.5 shrink-0 opacity-70 transition-opacity group-hover:opacity-100" />
              </Link>
            ) : (
              <p className="text-muted-foreground text-sm">Belum terikat batch</p>
            )}
          </div>

          <div
            className={cn(
              "rounded-xl border px-3 py-3 transition-colors",
              cohortHref
                ? "border-violet-500/30 bg-violet-500/[0.06] hover:border-violet-500/45 dark:bg-violet-500/[0.08]"
                : "border-border/60 bg-muted/15"
            )}
          >
            <div className="mb-2 flex items-center gap-2 text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
              <IconMicrophone2 className="size-3.5 shrink-0 text-violet-600 dark:text-violet-400" aria-hidden />
              Grup sesi interview
            </div>
            {cohortHref && cohortTitle ? (
              <Link
                to={cohortHref}
                className="group inline-flex items-start gap-1.5 text-sm font-medium text-violet-700 underline-offset-4 hover:underline dark:text-violet-300"
              >
                <span className="min-w-0 break-words leading-snug">{cohortTitle}</span>
                <IconExternalLink className="mt-0.5 size-3.5 shrink-0 opacity-70 transition-opacity group-hover:opacity-100" />
              </Link>
            ) : (
              <p className="text-muted-foreground text-sm">
                Belum masuk grup interview
              </p>
            )}
          </div>
        </div>

        {/* Diterima sub-tahapan */}
        {showDiterimaTrack ? (
          <div className="border-t border-border/50 bg-gradient-to-br from-emerald-500/[0.07] via-transparent to-transparent px-4 py-4 dark:from-emerald-950/40 sm:px-5">
            <div className="mb-3 flex flex-wrap items-center gap-2">
              <span className="text-[11px] font-semibold uppercase tracking-wide text-emerald-800/90 dark:text-emerald-300/90">
                Sub-tahapan Diterima
              </span>
              <span className="text-muted-foreground hidden text-xs sm:inline">
                — posisi dokumen dan proses keberangkatan
              </span>
            </div>

            {stepLabel && stepIdx >= 0 ? (
              <>
                <div className="mb-3 flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between">
                  <div>
                    <p className="text-muted-foreground text-xs font-medium">
                      Sedang berada di
                    </p>
                    <p className="text-lg font-semibold leading-tight text-emerald-950 dark:text-emerald-50">
                      {stepLabel}
                    </p>
                  </div>
                  <p className="text-muted-foreground shrink-0 text-xs tabular-nums">
                    Langkah {stepIdx + 1} dari {DOCUMENT_COLLECTION_STEP_ORDER.length}
                  </p>
                </div>
                <div
                  className="flex h-2 gap-1"
                  role="progressbar"
                  aria-valuenow={stepIdx + 1}
                  aria-valuemin={1}
                  aria-valuemax={DOCUMENT_COLLECTION_STEP_ORDER.length}
                  aria-label="Progres sub-tahapan Diterima"
                >
                  {DOCUMENT_COLLECTION_STEP_ORDER.map((code, i) => {
                    const done = i < stepIdx
                    const current = i === stepIdx
                    return (
                      <div
                        key={code}
                        title={DOCUMENT_COLLECTION_STEP_LABELS[code]}
                        className={cn(
                          "min-h-2 min-w-0 flex-1 rounded-full transition-colors",
                          done && "bg-emerald-500/75 dark:bg-emerald-500/70",
                          current &&
                            "bg-emerald-600 shadow-[0_0_0_2px_rgba(16,185,129,0.35)] dark:bg-emerald-400",
                          !done && !current && "bg-muted-foreground/20"
                        )}
                      />
                    )
                  })}
                </div>
              </>
            ) : (
              <p className="text-muted-foreground text-sm">
                Sub-tahapan dokumen belum ditampilkan. Buka{" "}
                <Link
                  to={`${lamaranBase}/${app.id}`}
                  className="font-medium text-primary underline-offset-4 hover:underline"
                >
                  detail lamaran
                </Link>{" "}
                untuk informasi lengkap.
              </p>
            )}
          </div>
        ) : (
          <div className="border-t border-border/50 px-4 py-3 sm:px-5">
            <p className="text-muted-foreground text-xs leading-relaxed">
              <span className="font-medium text-foreground/90">
                Tahap utama saat ini: {APPLICATION_STATUS_LABELS[app.status]}
              </span>
              {app.status === "BERANGKAT" || app.status === "SELESAI" ? (
                <span className="block pt-1">
                  Pelamar telah melampaui tahap Diterima dokumen.
                </span>
              ) : app.status === "INTERVIEW" || app.status === "CADANGAN" ? (
                <span className="block pt-1">
                  Sub-tahapan dokumen akan terlihat setelah status menjadi Diterima.
                </span>
              ) : null}
            </p>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

export function ApplicantApplicationsTab({
  profileId,
  lamaranBase,
  basePath,
}: ApplicantApplicationsTabProps) {
  const { data, isLoading } = useApplicationsQuery(
    profileId ? { applicant: profileId, page_size: 50 } : {},
    !!profileId
  )

  if (!profileId) {
    return (
      <Card>
        <CardContent className="py-8 text-center text-sm text-muted-foreground">
          Profil pelamar belum tersedia.
        </CardContent>
      </Card>
    )
  }

  const applications = data?.results ?? []

  return (
    <div className="flex flex-col gap-6">
      <ApplicantLamaranQuickAssign
        applicantProfileId={profileId}
        applications={applications}
        basePath={basePath}
        disabled={isLoading}
      />

      <div className="flex flex-col gap-2">
        <h3 className="text-sm font-semibold">Daftar lamaran</h3>
        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <div className="h-7 w-7 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          </div>
        ) : applications.length === 0 ? (
          <Card>
            <CardContent className="py-8 text-center">
              <IconClipboardList className="mx-auto mb-3 size-8 text-muted-foreground/50" />
              <p className="text-sm text-muted-foreground">
                Pelamar belum memiliki lamaran. Gunakan formulir di atas untuk menambahkan ke
                batch.
              </p>
            </CardContent>
          </Card>
        ) : (
          <div className="flex flex-col gap-4">
            {applications.map((app) => (
              <LamaranApplicationCard
                key={app.id}
                app={app}
                lamaranBase={lamaranBase}
                basePath={basePath}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
