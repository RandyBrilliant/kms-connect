/**
 * InterviewCohort types — matches backend main.InterviewCohortSerializer.
 *
 * A cohort is the operational unit for INTERVIEW → SELESAI lifecycle.
 * Multiple cohorts can exist per job. Multiple pra-seleksi batches can route
 * survivors into the same cohort, or split into different cohorts (per the
 * admin's choice when transitioning).
 */

import type {
  ApplicationStatus,
  TransitionApplicationInput,
} from "@/types/job-applications"

// ---------------------------------------------------------------------------
// Core model
// ---------------------------------------------------------------------------

export interface InterviewCohort {
  id: number
  job: number
  job_title: string
  name: string
  notes: string

  /** ISO datetime, null when not yet scheduled */
  interview_date: string | null
  interview_location: string
  interview_notes: string

  is_active: boolean

  // Counts (computed by serializer)
  applicant_count: number
  interview_count: number
  cadangan_count: number
  diterima_count: number
  berangkat_count: number
  selesai_count: number
  ditolak_count: number
  confirmed_interview_count: number
  pengumpulan_dokumen_confirmed_count: number

  created_by: number | null
  created_by_name: string | null
  created_at: string
  updated_at: string
}

// ---------------------------------------------------------------------------
// Input types
// ---------------------------------------------------------------------------

/** POST /api/interview-cohorts/ */
export interface CreateInterviewCohortInput {
  job: number
  name: string
  notes?: string
  interview_date?: string | null
  interview_location?: string
  interview_notes?: string
}

/** PATCH /api/interview-cohorts/{id}/ */
export interface UpdateInterviewCohortInput {
  name?: string
  notes?: string
  interview_date?: string | null
  interview_location?: string
  interview_notes?: string
  is_active?: boolean
}

/** PATCH /api/interview-cohorts/{id}/schedule/ */
export interface ScheduleCohortInput {
  interview_date?: string | null
  interview_location?: string
  interview_notes?: string
}

/** POST /api/interview-cohorts/{id}/bulk-transition/ */
export interface CohortBulkTransitionInput {
  status: Extract<
    ApplicationStatus,
    "CADANGAN" | "DITERIMA" | "BERANGKAT" | "SELESAI" | "DITOLAK"
  >
  note?: string
  placement_end_date?: string | null
}

export interface CohortBulkTransitionResponse {
  updated_count: number
}

/** POST /api/interview-cohorts/{id}/move-applicants/ */
export interface MoveApplicationsToCohortInput {
  target_cohort: number
  application_ids: number[]
  note?: string
}

// ---------------------------------------------------------------------------
// Cohort announcements
// ---------------------------------------------------------------------------

import type { BatchAnnouncementRecipientConfig } from "@/types/lamaran-batch"

export interface InterviewCohortAnnouncement {
  id: number
  cohort: number
  title: string
  body: string
  recipient_config?: BatchAnnouncementRecipientConfig
  created_by: number | null
  created_by_name: string | null
  created_at: string
}

export interface CreateCohortAnnouncementInput {
  title: string
  body: string
  recipient_config?: BatchAnnouncementRecipientConfig
}

// ---------------------------------------------------------------------------
// List params
// ---------------------------------------------------------------------------

export interface CohortListParams {
  page?: number
  page_size?: number
  search?: string
  job?: number
  is_active?: boolean
  ordering?: string
}

// ---------------------------------------------------------------------------
// Helper transition input for "Advance batch survivors to interview cohort"
// (used by batch detail page when admin decides to route survivors)
// ---------------------------------------------------------------------------

export type TransitionToInterviewInput = TransitionApplicationInput & {
  interview_cohort: number
}

/** POST /api/batches/{id}/advance-to-interview/ */
export interface BatchAdvanceToCohortInput {
  interview_cohort: number
  application_ids?: number[]
  note?: string
}

export interface BatchAdvanceToCohortResponse {
  updated_count: number
  failed_count: number
  updated_ids: number[]
  failed: Array<{ application_id: number; reason: string }>
  interview_cohort: number
}
