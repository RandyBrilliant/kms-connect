/**
 * LamaranBatch API — create, list, assign, schedule, transition.
 * Backend: /api/batches/
 *
 * Workflow:
 *  1. Admin creates a batch for an OPEN job (POST /api/batches/)
 *  2. Admin opens batch detail and searches eligible applicants
 *     (GET /api/batches/{id}/eligible-applicants/?q=...)
 *  3. Admin optionally dry-runs eligibility for selected IDs
 *     (POST /api/batches/{id}/check-eligibility/)
 *  4. Admin bulk-assigns selected applicants
 *     (POST /api/batches/{id}/assign/)
 *  5. Admin schedules pra-seleksi / interview (date + location)
 *     (PATCH /api/batches/{id}/schedule/)
 *  6. Admin bulk-transitions the whole batch
 *     (POST /api/batches/{id}/bulk-transition/)
 */

import { api } from "@/lib/api"
import type { PaginatedResponse } from "@/types/admin"
import type {
  LamaranBatch,
  ApplicantSearchRow,
  BatchAnnouncement,
  BatchListParams,
  CreateAnnouncementInput,
  CreateBatchInput,
  EligibleApplicantsParams,
  GroupAssignInput,
  GroupAssignResponse,
  CheckEligibilityInput,
  EligibilityCheckResult,
  ScheduleBatchStageInput,
  BulkTransitionInput,
  BulkTransitionResponse,
} from "@/types/lamaran-batch"

// ---------------------------------------------------------------------------
// CRUD
// ---------------------------------------------------------------------------

/** GET /api/batches/ */
export async function getBatches(
  params: BatchListParams = {}
): Promise<PaginatedResponse<LamaranBatch>> {
  const search = new URLSearchParams()
  if (params.page != null) search.set("page", String(params.page))
  if (params.page_size != null) search.set("page_size", String(params.page_size))
  if (params.search) search.set("search", params.search)
  if (params.job != null) search.set("job", String(params.job))
  if (params.ordering) search.set("ordering", params.ordering)
  const qs = search.toString()
  const { data } = await api.get<PaginatedResponse<LamaranBatch>>(
    `/api/batches/${qs ? `?${qs}` : ""}`
  )
  return data
}

/** GET /api/batches/:id/ */
export async function getBatch(id: number): Promise<LamaranBatch> {
  const { data } = await api.get<LamaranBatch>(`/api/batches/${id}/`)
  return data
}

/** POST /api/batches/ — admin creates a batch */
export async function createBatch(input: CreateBatchInput): Promise<LamaranBatch> {
  const { data } = await api.post<{ data: LamaranBatch }>("/api/batches/", input)
  return data.data
}

/** PATCH /api/batches/:id/ — update name / notes */
export async function patchBatch(
  id: number,
  input: Partial<Pick<LamaranBatch, "name" | "notes">>
): Promise<LamaranBatch> {
  const { data } = await api.patch<LamaranBatch>(`/api/batches/${id}/`, input)
  return data
}

/** DELETE /api/batches/:id/ */
export async function deleteBatch(id: number): Promise<void> {
  await api.delete(`/api/batches/${id}/`)
}

// ---------------------------------------------------------------------------
// Applicant search table
// ---------------------------------------------------------------------------

/**
 * GET /api/batches/{id}/eligible-applicants/?q=...
 * Returns a paginated table of applicant rows with is_eligible pre-computed.
 * Admin uses this to search and select who to add to the batch.
 */
export async function getEligibleApplicants(
  batchId: number,
  params: EligibleApplicantsParams = {}
): Promise<PaginatedResponse<ApplicantSearchRow>> {
  const search = new URLSearchParams()
  if (params.q) search.set("q", params.q)
  if (params.page != null) search.set("page", String(params.page))
  if (params.page_size != null) search.set("page_size", String(params.page_size))
  const qs = search.toString()
  const { data } = await api.get<PaginatedResponse<ApplicantSearchRow>>(
    `/api/batches/${batchId}/eligible-applicants/${qs ? `?${qs}` : ""}`
  )
  return data
}

// ---------------------------------------------------------------------------
// Eligibility dry-run
// ---------------------------------------------------------------------------

/**
 * POST /api/batches/{id}/check-eligibility/
 * Dry-run for a set of already-selected applicant IDs.
 * Returns eligibility per ID — no applications are created.
 */
export async function checkEligibility(
  batchId: number,
  input: CheckEligibilityInput
): Promise<EligibilityCheckResult[]> {
  const { data } = await api.post<{ data: EligibilityCheckResult[] }>(
    `/api/batches/${batchId}/check-eligibility/`,
    input
  )
  return data.data
}

// ---------------------------------------------------------------------------
// Bulk assign
// ---------------------------------------------------------------------------

/**
 * POST /api/batches/{id}/assign/
 * Bulk-assign selected applicant IDs to this batch.
 * Returns how many were assigned and which were skipped (with reasons).
 */
export async function assignToBatch(
  batchId: number,
  input: GroupAssignInput
): Promise<GroupAssignResponse> {
  const { data } = await api.post<{ data: GroupAssignResponse }>(
    `/api/batches/${batchId}/assign/`,
    input
  )
  return data.data
}

// ---------------------------------------------------------------------------
// Stage scheduling
// ---------------------------------------------------------------------------

/**
 * PATCH /api/batches/{id}/schedule/
 * Set date, location, and notes for pra_seleksi or interview stage.
 */
export async function scheduleBatchStage(
  batchId: number,
  input: ScheduleBatchStageInput
): Promise<LamaranBatch> {
  const { data } = await api.patch<{ data: LamaranBatch }>(
    `/api/batches/${batchId}/schedule/`,
    input
  )
  return data.data
}

// ---------------------------------------------------------------------------
// Bulk transition
// ---------------------------------------------------------------------------

/**
 * POST /api/batches/{id}/bulk-transition/
 * Advance all eligible applications in the batch to the next status at once.
 */
export async function bulkTransitionBatch(
  batchId: number,
  input: BulkTransitionInput
): Promise<BulkTransitionResponse> {
  const { data } = await api.post<{ data: BulkTransitionResponse }>(
    `/api/batches/${batchId}/bulk-transition/`,
    input
  )
  return data.data
}

// ---------------------------------------------------------------------------
// Announcements (batch-level broadcast for PRA_SELEKSI / INTERVIEW stages)
// ---------------------------------------------------------------------------

/**
 * GET /api/batches/{id}/announcements/
 * List all broadcast announcements for this batch, newest first.
 */
export async function getBatchAnnouncements(
  batchId: number
): Promise<BatchAnnouncement[]> {
  const { data } = await api.get<{ data: BatchAnnouncement[] }>(
    `/api/batches/${batchId}/announcements/`
  )
  return data.data
}

/**
 * POST /api/batches/{id}/announcements/
 * Admin creates a broadcast announcement for all applicants in this batch.
 */
export async function createBatchAnnouncement(
  batchId: number,
  input: CreateAnnouncementInput
): Promise<BatchAnnouncement> {
  const { data } = await api.post<{ data: BatchAnnouncement }>(
    `/api/batches/${batchId}/announcements/`,
    input
  )
  return data.data
}

// ---------------------------------------------------------------------------
// Excel export
// ---------------------------------------------------------------------------

/**
 * GET /api/batches/{id}/export-excel/
 * Downloads an .xlsx file with all applicant biodata for this batch.
 * Triggers a browser file download automatically.
 */
export async function exportBatchExcel(
  batchId: number,
  batchName: string
): Promise<void> {
  const response = await api.get(`/api/batches/${batchId}/export-excel/`, {
    responseType: "blob",
  })
  const blob = new Blob([response.data], {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  })
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  const safeName = batchName.replace(/[^a-zA-Z0-9\s_-]/g, "").trim().replace(/\s+/g, "_")
  a.href = url
  a.download = `pelamar_${safeName}.xlsx`
  a.style.display = "none"
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}
