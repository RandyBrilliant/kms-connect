/**
 * Job Applications types — matches backend main.JobApplicationSerializer.
 *
 * FSM (admin-only transitions):
 *   PRA_SELEKSI → INTERVIEW | DITOLAK
 *   INTERVIEW   → DITERIMA | CADANGAN | DITOLAK
 *   CADANGAN    → DITERIMA | DITOLAK
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
  | "CADANGAN"
  | "DITERIMA"
  | "DITOLAK"
  | "BERANGKAT"
  | "SELESAI"

/** Statuses that block re-assignment to another job */
export const ACTIVE_APPLICATION_STATUSES: ApplicationStatus[] = [
  "PRA_SELEKSI",
  "INTERVIEW",
  "CADANGAN",
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
  /** ID of the LamaranBatch (pra-seleksi tahapan) this application belongs to */
  batch: number | null
  batch_name: string | null
  /** tahap_order of the current batch (1, 2, 3, ...). null when no batch. */
  batch_tahap_order?: number | null
  /** Display label for current batch tahapan ("Pra-Seleksi 1: CV Screening"). */
  batch_tahap_label?: string | null
  /** ID of the InterviewCohort owning this app from INTERVIEW onwards */
  interview_cohort?: number | null
  interview_cohort_name?: string | null
  status: ApplicationStatus
  /**
   * Pra-seleksi schedule resolved from the application's batch.
   * Kept on this shape for backward compatibility with mobile clients.
   */
  pra_seleksi_date?: string | null
  pra_seleksi_location?: string
  pra_seleksi_notes?: string
  /**
   * Interview schedule resolved from the application's interview_cohort
   * (with fallback to the legacy batch.interview_* columns for old data).
   */
  interview_date?: string | null
  interview_location?: string
  interview_notes?: string
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
    items: Array<{
      code: string
      label: string
      done: boolean
      /** Whether the pelamar has explicitly confirmed this step */
      confirmed: boolean
      /** ISO-8601 timestamp when confirmed, or null */
      confirmed_at: string | null
    }>
    done_count: number
    total_count: number
    is_complete: boolean
  }
  pengumpulan_dokumen_complete?: boolean
  pengumpulan_dokumen_confirmed_at?: string | null
  pengumpulan_dokumen_ready_for_departure?: boolean
  pengumpulan_dokumen_pending_items?: Array<{ code: string; label: string }>
  pengumpulan_dokumen_pending_labels?: string[]
  /**
   * Per-step confirmation timestamps from pelamar for the 9 document-collection steps.
   * Keys are step codes (e.g. "MEDICAL", "BUAT_PASPOR").
   * Value is ISO-8601 timestamp when confirmed, or null if not yet confirmed.
   */
  diterima_step_confirmations?: Record<string, string | null>
  created_at: string
  updated_at: string
}

export type DocumentCollectionStepCode =
  | "MASUK_BERKAS_ASLI"
  | "MEDICAL"
  | "BUAT_ID_PEKERJA"
  | "BUAT_PASPOR"
  | "FWCMS"
  | "PSIKOLOGI_TEST"
  | "PAP_BP3MI"
  | "PDO_KILANG"
  | "PERSIAPAN_KEBERANGKATAN"

export const DOCUMENT_COLLECTION_STEP_LABELS: Record<DocumentCollectionStepCode, string> = {
  MASUK_BERKAS_ASLI: "Masuk Berkas Asli",
  MEDICAL: "Medical",
  BUAT_ID_PEKERJA: "Buat ID Pekerja",
  BUAT_PASPOR: "Buat Paspor",
  FWCMS: "FWCMS",
  PSIKOLOGI_TEST: "Psikologi Test",
  PAP_BP3MI: "PAP BP3MI",
  PDO_KILANG: "PDO Kilang",
  PERSIAPAN_KEBERANGKATAN: "Persiapan Keberangkatan",
}

export interface ApplicationsListParams {
  page?: number
  page_size?: number
  search?: string
  status?: ApplicationStatus | "ALL"
  /** Optional filter for DITERIMA document sub-steps (used by export/list tooling). */
  diterima_step?: DocumentCollectionStepCode
  job?: number
  applicant?: number
  batch?: number
  interview_cohort?: number
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
  /** Required when transitioning to INTERVIEW (admin must pick a cohort). */
  interview_cohort?: number | null
}

export interface BulkTransitionApplicationsInput extends TransitionApplicationInput {
  application_ids: number[]
}

export interface BulkTransitionApplicationsResponse {
  updated_count: number
  failed_count: number
  updated_ids: number[]
  failed: Array<{ application_id: number; reason: string }>
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
  CADANGAN: "Cadangan",
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
  CADANGAN: "outline",
  DITERIMA: "default",
  DITOLAK: "destructive",
  BERANGKAT: "default",
  SELESAI: "outline",
}
