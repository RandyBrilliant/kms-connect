/**
 * Reusable form control for picking an `InterviewCohort` of a specific job.
 *
 * Used by:
 *  - transition-application-dialog (when target status = INTERVIEW)
 *  - batch detail "Advance to Interview Cohort" dialog
 *
 * Optionally renders a "Create new cohort" link that opens the cohort form
 * in a new tab so admins don't lose their selection state.
 */

import { useQuery } from "@tanstack/react-query"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import { IconExternalLink } from "@tabler/icons-react"

import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Label } from "@/components/ui/label"
import { useAdminDashboard, joinAdminPath } from "@/contexts/admin-dashboard-context"
import { getInterviewCohorts } from "@/api/interview-cohorts"

export interface CohortSelectFieldProps {
  /** Job ID — only cohorts belonging to this job are shown. */
  jobId: number
  value: number | null
  onChange: (cohortId: number | null) => void
  /** Omit this cohort id (e.g. current session when moving applicants away). */
  excludeCohortId?: number
  /** Show only active cohorts (default: true). */
  activeOnly?: boolean
  /** Label above the select (default: "Sesi Interview"). */
  label?: string
  /** Helper text rendered below the select. */
  helperText?: string
  /** When true, hides the "Buat sesi baru" link. */
  hideCreateLink?: boolean
  disabled?: boolean
  required?: boolean
  /** Placeholder shown when no cohort is selected. */
  placeholder?: string
}

function formatCohortLabel(c: {
  name: string
  interview_date: string | null
  is_active: boolean
}): string {
  const date = c.interview_date
    ? format(new Date(c.interview_date), "dd MMM yyyy HH:mm", { locale: idLocale })
    : "Belum dijadwalkan"
  const inactive = c.is_active ? "" : " · Non-aktif"
  return `${c.name} · ${date}${inactive}`
}

export function CohortSelectField({
  jobId,
  value,
  onChange,
  excludeCohortId,
  activeOnly = true,
  label = "Sesi Interview",
  helperText,
  hideCreateLink = false,
  disabled = false,
  required = false,
  placeholder = "Pilih sesi interview...",
}: CohortSelectFieldProps) {
  const { basePath } = useAdminDashboard()

  const { data, isLoading } = useQuery({
    queryKey: ["interview-cohorts", { job: jobId, is_active: activeOnly }],
    queryFn: () =>
      getInterviewCohorts({
        job: jobId,
        ...(activeOnly ? { is_active: true } : {}),
        page_size: 200,
        ordering: "-interview_date,-created_at",
      }),
    enabled: Number.isFinite(jobId) && jobId > 0,
  })

  const cohorts = (data?.results ?? []).filter(
    (c) => c.id !== excludeCohortId
  )

  return (
    <div className="flex flex-col gap-1.5">
      <Label>
        {label} {required && <span className="text-destructive">*</span>}
      </Label>
      <Select
        value={value != null ? String(value) : ""}
        onValueChange={(v) => onChange(v ? Number(v) : null)}
        disabled={disabled || isLoading}
      >
        <SelectTrigger className="cursor-pointer">
          <SelectValue placeholder={isLoading ? "Memuat..." : placeholder} />
        </SelectTrigger>
        <SelectContent>
          {cohorts.length ? (
            <SelectGroup>
              <SelectLabel>Sesi yang tersedia</SelectLabel>
              {cohorts.map((c) => (
                <SelectItem key={c.id} value={String(c.id)}>
                  {formatCohortLabel(c)}
                </SelectItem>
              ))}
            </SelectGroup>
          ) : !isLoading ? (
            <div className="px-3 py-4 text-center text-xs text-muted-foreground">
              Belum ada sesi interview untuk lowongan ini.
            </div>
          ) : null}
        </SelectContent>
      </Select>
      <div className="flex items-center justify-between gap-2">
        <span className="text-muted-foreground text-xs">{helperText ?? ""}</span>
        {!hideCreateLink && (
          <a
            href={joinAdminPath(
              basePath,
              `/lowongan-kerja/${jobId}/sesi-interview/baru`
            )}
            target="_blank"
            rel="noreferrer"
            className="text-primary text-xs underline-offset-2 hover:underline inline-flex items-center gap-1"
          >
            Buat sesi baru
            <IconExternalLink className="size-3" />
          </a>
        )}
      </div>
    </div>
  )
}
