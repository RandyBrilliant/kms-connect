/**
 * LamaranBatch types — matches backend main.LamaranBatchSerializer.
 *
 * A batch is the unit of group assignment.
 * Admin creates a batch for a job, searches/selects eligible applicants,
 * and bulk-assigns them. Then admin schedules Pra-Seleksi and Interview
 * stages (date + location) for the whole batch.
 */

// ---------------------------------------------------------------------------
// Core model
// ---------------------------------------------------------------------------

export interface LamaranBatch {
  id: number
  job: number
  job_title: string
  name: string
  notes: string

  // Pra-seleksi schedule (null = not yet scheduled)
  pra_seleksi_date: string | null
  pra_seleksi_location: string
  pra_seleksi_notes: string

  // Interview schedule (null = not yet scheduled)
  interview_date: string | null
  interview_location: string
  interview_notes: string

  // Counts (computed by the serializer)
  applicant_count: number
  confirmed_pra_seleksi_count: number
  confirmed_interview_count: number

  created_by: number | null
  created_by_name: string | null
  created_at: string
  updated_at: string
}

// ---------------------------------------------------------------------------
// Applicant row in the batch-assignment search table
// ---------------------------------------------------------------------------

export interface ApplicantSearchRow {
  id: number
  nik: string
  full_name: string
  email: string
  phone: string
  domicile: string
  referrer_display_name: string
  referrer_code: string
  is_eligible: boolean
  /** Filled when is_eligible=false so admin knows why */
  ineligible_reason: string | null
  /** Raw codes / nullable biodata for batch assignment table */
  gender?: string
  religion?: string
  education_level?: string
  marital_status?: string
  writing_hand?: string
  height_cm?: number | null
  weight_kg?: number | null
  birth_date?: string | null
  wears_glasses?: boolean | null
  has_passport?: boolean | null
}

/** UI + API payload for eligible-applicants filters (batch assign dialog). */
export interface EligibleApplicantsFilterState {
  ordering: string
  height_cm_min: string
  height_cm_max: string
  weight_kg_min: string
  weight_kg_max: string
  birth_date_from: string
  birth_date_to: string
  religion: string
  gender: string
  education_level: string
  marital_status: string
  writing_hand: string
  /** Empty = semua; API sends boolean only when set */
  wears_glasses: "" | "true" | "false"
  has_passport: "" | "true" | "false"
}

/** Initial filter form / committed filter for batch assign dialog. */
export const DEFAULT_ELIGIBLE_APPLICANTS_FILTER: EligibleApplicantsFilterState = {
  ordering: "name",
  height_cm_min: "",
  height_cm_max: "",
  weight_kg_min: "",
  weight_kg_max: "",
  birth_date_from: "",
  birth_date_to: "",
  religion: "",
  gender: "",
  education_level: "",
  marital_status: "",
  writing_hand: "",
  wears_glasses: "",
  has_passport: "",
}

// ---------------------------------------------------------------------------
// Input types
// ---------------------------------------------------------------------------

/** POST /api/batches/ */
export interface CreateBatchInput {
  job: number
  name: string
  notes?: string
}

/** POST /api/batches/{id}/assign/ */
export interface GroupAssignInput {
  applicant_ids: number[]
  note?: string
}

/** POST /api/batches/{id}/check-eligibility/ */
export interface CheckEligibilityInput {
  applicant_ids: number[]
}

export interface EligibilityCheckResult {
  applicant_id: number
  eligible: boolean
  reason: string | null
}

export interface CheckEligibilityResponse {
  results: EligibilityCheckResult[]
}

/** PATCH /api/batches/{id}/schedule/ */
export type BatchStage = "pra_seleksi" | "interview"

export interface ScheduleBatchStageInput {
  stage: BatchStage
  date: string   // ISO datetime string
  location: string
  notes?: string
}

/** Response after assign */
export interface GroupAssignResponse {
  assigned_count: number
  skipped_count: number
  skipped: Array<{ applicant_id: number; reason: string | null }>
}

/** POST /api/batches/{id}/bulk-transition/ */
export interface BulkTransitionInput {
  status: string
  note?: string
  placement_end_date?: string | null
}

export interface BulkTransitionResponse {
  updated_count: number
}

// ---------------------------------------------------------------------------
// List / filter params
// ---------------------------------------------------------------------------

export interface BatchListParams {
  page?: number
  page_size?: number
  search?: string
  job?: number
  ordering?: string
}

export interface EligibleApplicantsParams {
  q?: string
  page?: number
  page_size?: number
  ordering?: string
  height_cm_min?: number
  height_cm_max?: number
  weight_kg_min?: number
  weight_kg_max?: number
  birth_date_from?: string
  birth_date_to?: string
  religion?: string
  gender?: string
  education_level?: string
  marital_status?: string
  writing_hand?: string
  wears_glasses?: boolean
  has_passport?: boolean
}

// ---------------------------------------------------------------------------
// BatchAnnouncement — broadcast pesan admin ke seluruh batch
// ---------------------------------------------------------------------------

import type { ApplicationStatus } from "@/types/job-applications"

/**
 * Admin broadcast announcement for all applicants in a batch.
 * Used for early-stage communication (PRA_SELEKSI / INTERVIEW)
 * instead of individual chat threads.
 */
export type BatchAnnouncementRecipientSelection = "all_active" | "statuses"

export interface BatchAnnouncementRecipientConfig {
  selection_type: BatchAnnouncementRecipientSelection
  /** Required when selection_type is "statuses" */
  statuses?: ApplicationStatus[]
}

export interface BatchAnnouncement {
  id: number
  batch: number
  title: string
  body: string
  /** Present after backend migration; default to all_active when missing. */
  recipient_config?: BatchAnnouncementRecipientConfig
  created_by: number | null
  created_by_name: string | null
  created_at: string
}

/** POST /api/batches/{id}/announcements/ */
export interface CreateAnnouncementInput {
  title: string
  body: string
  recipient_config?: BatchAnnouncementRecipientConfig
}
