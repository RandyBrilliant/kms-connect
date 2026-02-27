/**
 * Job Applications types — matches backend main.JobApplicationSerializer (v2).
 * Full FSM: APPLIED → ... → COMPLETED / REJECTED / WITHDRAWN
 */

export type ApplicationStatus =
  | "APPLIED"
  | "UNDER_REVIEW"
  | "SHORTLISTED"
  | "OFFERED"
  | "OFFER_ACCEPTED"
  | "OFFER_DECLINED"
  | "PLACED"
  | "COMPLETED"
  | "REJECTED"
  | "WITHDRAWN"

export type ApplicationSource = "SELF_APPLIED" | "ADMIN_ASSIGN"

export interface ApplicationStatusHistoryEntry {
  id: number
  from_status: string
  to_status: ApplicationStatus
  changed_by: number | null
  changed_by_name: string | null
  changed_at: string
  note: string
}

export interface JobApplication {
  id: number
  applicant: number
  applicant_name: string
  applicant_email: string
  job: number
  job_title: string
  company_name: string
  status: ApplicationStatus
  source: ApplicationSource
  applied_at: string
  reviewed_at: string | null
  placement_end_date: string | null
  cooldown_eligible_date: string | null
  reviewed_by: number | null
  reviewed_by_name: string | null
  assigned_by: number | null
  assigned_by_name: string | null
  notes: string
  status_history: ApplicationStatusHistoryEntry[]
  created_at: string
  updated_at: string
}

export interface ApplicationsListParams {
  page?: number
  page_size?: number
  search?: string
  status?: ApplicationStatus | "ALL"
  source?: ApplicationSource | "ALL"
  job?: number
  applicant?: number
  ordering?: string
}

/** POST /api/applications/assign/ */
export interface AssignApplicationInput {
  job: number
  applicant: number
  note?: string
}

/** PATCH /api/applications/{id}/transition/ */
export interface TransitionApplicationInput {
  status: ApplicationStatus
  note?: string
  placement_end_date?: string | null
}

export interface CompanyDashboardStats {
  total_jobs: number
  total_open_jobs: number
  total_applications: number
  total_applicants: number
  status_breakdown: Partial<Record<ApplicationStatus, number>>
  recent_applications: JobApplication[]
}

/** Human-readable label for each status */
export const APPLICATION_STATUS_LABELS: Record<ApplicationStatus, string> = {
  APPLIED: "Dilamar",
  UNDER_REVIEW: "Dalam Review",
  SHORTLISTED: "Shortlist",
  OFFERED: "Ditawarkan",
  OFFER_ACCEPTED: "Tawaran Diterima",
  OFFER_DECLINED: "Tawaran Ditolak",
  PLACED: "Ditempatkan",
  COMPLETED: "Selesai Bekerja",
  REJECTED: "Ditolak",
  WITHDRAWN: "Dicabut",
}

/** Badge variant mapping — follows the project's badge color convention */
export const APPLICATION_STATUS_VARIANTS: Record<
  ApplicationStatus,
  "default" | "secondary" | "destructive" | "outline"
> = {
  APPLIED: "secondary",
  UNDER_REVIEW: "secondary",
  SHORTLISTED: "default",
  OFFERED: "default",
  OFFER_ACCEPTED: "default",
  OFFER_DECLINED: "destructive",
  PLACED: "default",
  COMPLETED: "default",
  REJECTED: "destructive",
  WITHDRAWN: "outline",
}
