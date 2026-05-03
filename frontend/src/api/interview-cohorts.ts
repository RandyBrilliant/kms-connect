/**
 * InterviewCohort API — admin operations for INTERVIEW → SELESAI lifecycle.
 * Backend: /api/interview-cohorts/
 *
 * Workflow:
 *  1. Admin creates a cohort for a job (POST /api/interview-cohorts/).
 *  2. Admin schedules date/location (PATCH .../schedule/).
 *  3. Admin routes pra-seleksi survivors into the cohort using
 *     POST /api/batches/{id}/advance-to-interview/ (see batches.ts) —
 *     the routed applicants now appear in this cohort.
 *  4. Admin runs cohort-scoped bulk transitions:
 *       INTERVIEW  → DITERIMA  (POST .../bulk-transition/)
 *       DITERIMA   → BERANGKAT
 *       BERANGKAT  → SELESAI
 *       (or DITOLAK at any of the above)
 *  5. Admin can broadcast announcements scoped to the cohort.
 *  6. Admin can move applicants between cohorts (.../move-applicants/).
 */

import { api } from "@/lib/api"
import type { PaginatedResponse } from "@/types/admin"
import type { ApplicationStatus } from "@/types/job-applications"
import type {
  CohortBulkTransitionInput,
  CohortBulkTransitionResponse,
  CohortListParams,
  CreateCohortAnnouncementInput,
  CreateInterviewCohortInput,
  InterviewCohort,
  InterviewCohortAnnouncement,
  MoveApplicationsToCohortInput,
  ScheduleCohortInput,
  UpdateInterviewCohortInput,
} from "@/types/interview-cohort"
import type { BatchAnnouncementRecipientConfig } from "@/types/lamaran-batch"

function unwrap<T>(raw: unknown): T {
  if (
    raw &&
    typeof raw === "object" &&
    "data" in raw &&
    (raw as { data?: unknown }).data !== undefined
  ) {
    return (raw as { data: T }).data
  }
  return raw as T
}

function unwrapPaginated<T>(raw: unknown): PaginatedResponse<T> {
  if (
    raw &&
    typeof raw === "object" &&
    "data" in raw &&
    (raw as { data?: unknown }).data != null &&
    typeof (raw as { data: unknown }).data === "object" &&
    "results" in ((raw as { data: object }).data as object)
  ) {
    return (raw as { data: PaginatedResponse<T> }).data
  }
  return raw as PaginatedResponse<T>
}

// ---------------------------------------------------------------------------
// CRUD
// ---------------------------------------------------------------------------

/** GET /api/interview-cohorts/ */
export async function getInterviewCohorts(
  params: CohortListParams = {}
): Promise<PaginatedResponse<InterviewCohort>> {
  const search = new URLSearchParams()
  if (params.page != null) search.set("page", String(params.page))
  if (params.page_size != null) search.set("page_size", String(params.page_size))
  if (params.search) search.set("search", params.search)
  if (params.job != null) search.set("job", String(params.job))
  if (params.is_active != null) search.set("is_active", params.is_active ? "true" : "false")
  if (params.ordering) search.set("ordering", params.ordering)
  const qs = search.toString()
  const { data } = await api.get<unknown>(
    `/api/interview-cohorts/${qs ? `?${qs}` : ""}`
  )
  return unwrapPaginated<InterviewCohort>(data)
}

/** GET /api/interview-cohorts/:id/ */
export async function getInterviewCohort(id: number): Promise<InterviewCohort> {
  const { data } = await api.get<unknown>(`/api/interview-cohorts/${id}/`)
  return unwrap<InterviewCohort>(data)
}

/** POST /api/interview-cohorts/ */
export async function createInterviewCohort(
  input: CreateInterviewCohortInput
): Promise<InterviewCohort> {
  const { data } = await api.post<unknown>("/api/interview-cohorts/", input)
  return unwrap<InterviewCohort>(data)
}

/** PATCH /api/interview-cohorts/:id/ */
export async function patchInterviewCohort(
  id: number,
  input: UpdateInterviewCohortInput
): Promise<InterviewCohort> {
  const { data } = await api.patch<unknown>(`/api/interview-cohorts/${id}/`, input)
  return unwrap<InterviewCohort>(data)
}

/** DELETE /api/interview-cohorts/:id/ */
export async function deleteInterviewCohort(id: number): Promise<void> {
  await api.delete(`/api/interview-cohorts/${id}/`)
}

// ---------------------------------------------------------------------------
// Schedule
// ---------------------------------------------------------------------------

/** PATCH /api/interview-cohorts/:id/schedule/ */
export async function scheduleCohort(
  id: number,
  input: ScheduleCohortInput
): Promise<InterviewCohort> {
  const { data } = await api.patch<unknown>(
    `/api/interview-cohorts/${id}/schedule/`,
    input
  )
  return unwrap<InterviewCohort>(data)
}

// ---------------------------------------------------------------------------
// Bulk transition
// ---------------------------------------------------------------------------

/**
 * POST /api/interview-cohorts/:id/bulk-transition/
 * Move all eligible applicants in the cohort to the chosen status.
 * Allowed targets: DITERIMA, BERANGKAT, SELESAI, DITOLAK.
 */
export async function bulkTransitionCohort(
  cohortId: number,
  input: CohortBulkTransitionInput
): Promise<CohortBulkTransitionResponse> {
  const { data } = await api.post<{ data: CohortBulkTransitionResponse }>(
    `/api/interview-cohorts/${cohortId}/bulk-transition/`,
    input
  )
  return data.data
}

/** POST /api/interview-cohorts/:id/move-applicants/ — re-cohort applicants */
export async function moveApplicationsToCohort(
  cohortId: number,
  input: MoveApplicationsToCohortInput
): Promise<{ moved_count: number; target_cohort: number }> {
  const { data } = await api.post<{
    data: { moved_count: number; target_cohort: number }
  }>(`/api/interview-cohorts/${cohortId}/move-applicants/`, input)
  return data.data
}

// ---------------------------------------------------------------------------
// Announcements
// ---------------------------------------------------------------------------

/** GET /api/interview-cohorts/:id/announcements/ */
export async function getCohortAnnouncements(
  cohortId: number
): Promise<InterviewCohortAnnouncement[]> {
  const { data } = await api.get<{ data: InterviewCohortAnnouncement[] }>(
    `/api/interview-cohorts/${cohortId}/announcements/`
  )
  return data.data
}

/** POST /api/interview-cohorts/:id/announcements/ */
export async function createCohortAnnouncement(
  cohortId: number,
  input: CreateCohortAnnouncementInput
): Promise<{ announcement: InterviewCohortAnnouncement; detail?: string }> {
  const { data } = await api.post<{
    data: InterviewCohortAnnouncement
    detail?: string
  }>(`/api/interview-cohorts/${cohortId}/announcements/`, input)
  return { announcement: data.data, detail: data.detail }
}

/** POST /api/interview-cohorts/:id/announcements/preview-recipients/ */
export async function previewCohortAnnouncementRecipients(
  cohortId: number,
  recipientConfig: BatchAnnouncementRecipientConfig
): Promise<{ recipient_count: number }> {
  const { data } = await api.post<unknown>(
    `/api/interview-cohorts/${cohortId}/announcements/preview-recipients/`,
    { recipient_config: recipientConfig }
  )
  if (
    data &&
    typeof data === "object" &&
    "data" in data &&
    (data as { data?: { recipient_count?: number } }).data &&
    typeof (data as { data: { recipient_count?: number } }).data.recipient_count ===
      "number"
  ) {
    return {
      recipient_count: (data as { data: { recipient_count: number } }).data
        .recipient_count,
    }
  }
  return data as { recipient_count: number }
}

// ---------------------------------------------------------------------------
// Excel export
// ---------------------------------------------------------------------------

/**
 * GET /api/interview-cohorts/:id/export-excel/
 * Triggers a browser file download with applicants in this cohort.
 */
export async function exportCohortExcel(
  cohortId: number,
  cohortName: string,
  statuses?: ApplicationStatus[]
): Promise<void> {
  const search = new URLSearchParams()
  if (statuses?.length) {
    for (const s of statuses) search.append("status", s)
  }
  const qs = search.toString()
  const response = await api.get(
    `/api/interview-cohorts/${cohortId}/export-excel/${qs ? `?${qs}` : ""}`,
    { responseType: "blob" }
  )
  const blob = new Blob([response.data], {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  })
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  const safeName = cohortName.replace(/[^a-zA-Z0-9\s_-]/g, "").trim().replace(/\s+/g, "_")
  const stagePart =
    statuses?.length === 1
      ? `_${statuses[0]}`
      : statuses?.length
        ? `_tahapan_${statuses.length}`
        : ""
  a.href = url
  a.download = `interview_${safeName}${stagePart}.xlsx`
  a.style.display = "none"
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}
