/**
 * Job Applications types — matches backend main.JobApplicationSerializer.
 *
 * FSM (admin-only transitions):
 *   PRA_SELEKSI → INTERVIEW | DITOLAK
 *   INTERVIEW   → DITERIMA  | DITOLAK
 *   DITERIMA    → BERANGKAT | DITOLAK
 *   BERANGKAT   → SELESAI
 *   DITOLAK / SELESAI = terminal
 *
 * Applicant actions:
 *   - PRA_SELEKSI: confirm attendance → pra_seleksi_confirmed_at
 *   - INTERVIEW:   confirm attendance → interview_confirmed_at
 */

export type ApplicationStatus =
  | "PRA_SELEKSI"
  | "INTERVIEW"
  | "DITERIMA"
  | "DITOLAK"
  | "BERANGKAT"
  | "SELESAI"

/** Statuses that block re-assignment to another job */
export const ACTIVE_APPLICATION_STATUSES: ApplicationStatus[] = [
  "PRA_SELEKSI",
  "INTERVIEW",
  "DITERIMA",
  "BERANGKAT",
]

export const TERMINAL_APPLICATION_STATUSES: ApplicationStatus[] = [
  "DITOLAK",
  "SELESAI",
]

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
  /** CustomUser id for PATCH /api/applicants/:id/ (admin pelamar) */
  applicant_user?: number | null
  applicant_name: string
  applicant_email: string
  /** NIK from applicant profile — for admin search/display in batch tahapan tables */
  applicant_nik: string
  /** Staff rujukan display label (same logic as daftar pelamar) */
  referrer_display_name: string
  /** Referrer referral code when set */
  referrer_code: string
  job: number
  job_title: string
  company_name: string
  /** ID of the LamaranBatch this application belongs to */
  batch: number | null
  batch_name: string | null
  status: ApplicationStatus
  pra_seleksi_confirmed_at: string | null
  interview_confirmed_at: string | null
  applied_at: string
  placement_end_date: string | null
  cooldown_eligible_date: string | null
  assigned_by: number | null
  assigned_by_name: string | null
  notes: string
  status_history: ApplicationStatusHistoryEntry[]
  attendance_by_stage?: Partial<Record<ApplicationStatus, boolean>>
  attendance_marked_at_by_stage?: Partial<Record<ApplicationStatus, string | null>>
  reached_stages?: ApplicationStatus[]
  document_collection_progress?: {
    items: Array<{ code: string; label: string; done: boolean }>
    done_count: number
    total_count: number
    is_complete: boolean
  }
  pengumpulan_dokumen_complete?: boolean
  pengumpulan_dokumen_confirmed_at?: string | null
  pengumpulan_dokumen_ready_for_departure?: boolean
  pengumpulan_dokumen_pending_items?: Array<{ code: string; label: string }>
  pengumpulan_dokumen_pending_labels?: string[]
  created_at: string
  updated_at: string
}

export interface ApplicationsListParams {
  page?: number
  page_size?: number
  search?: string
  status?: ApplicationStatus | "ALL"
  job?: number
  applicant?: number
  batch?: number
  ordering?: string
}

/** POST /api/applications/ — admin assigns an applicant to a job */
export interface AssignApplicationInput {
  job: number
  applicant: number
  note?: string
}

/** PATCH /api/applications/{id}/transition/ */
export interface TransitionApplicationInput {
  status: ApplicationStatus
  note?: string
  /** Only required when transitioning to SELESAI */
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
  PRA_SELEKSI: "Pra-Seleksi",
  INTERVIEW: "Interview",
  DITERIMA: "Diterima",
  DITOLAK: "Ditolak",
  BERANGKAT: "Berangkat",
  SELESAI: "Selesai",
}

/** Badge variant mapping — follows the project's badge color convention */
export const APPLICATION_STATUS_VARIANTS: Record<
  ApplicationStatus,
  "default" | "secondary" | "destructive" | "outline"
> = {
  PRA_SELEKSI: "secondary",
  INTERVIEW: "secondary",
  DITERIMA: "default",
  DITOLAK: "destructive",
  BERANGKAT: "default",
  SELESAI: "outline",
}
