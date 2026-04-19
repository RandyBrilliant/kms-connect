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
import type {
  LamaranBatch,
  ApplicantSearchRow,
  BatchAnnouncement,
  BatchAnnouncementRecipientConfig,
  BatchListParams,
  CreateAnnouncementInput,
  CreateBatchInput,
  EligibleApplicantsParams,
  EligibleApplicantsFilterState,
  GroupAssignInput,
  GroupAssignResponse,
  CheckEligibilityInput,
  EligibilityCheckResult,
  ScheduleBatchStageInput,
  BulkTransitionInput,
  BulkTransitionResponse,
} from "@/types/lamaran-batch"
import type { ApplicationStatus } from "@/types/job-applications"

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
  const { data: body } = await api.post<
    { data: LamaranBatch } | (LamaranBatch & { data?: LamaranBatch })
  >("/api/batches/", input)
  if (body && typeof body === "object" && "data" in body && body.data != null) {
    return body.data
  }
  return body as LamaranBatch
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

/** Map batch-assign filter form → GET query params (omit unset fields). */
export function eligibleFilterStateToParams(
  f: EligibleApplicantsFilterState
): Omit<EligibleApplicantsParams, "q" | "page" | "page_size"> {
  const trimInt = (
    raw: string,
    min?: number,
    max?: number
  ): number | undefined => {
    const t = raw.trim()
    if (!t) return undefined
    const n = Number.parseInt(t, 10)
    if (!Number.isFinite(n)) return undefined
    if (min != null && n < min) return undefined
    if (max != null && n > max) return undefined
    return n
  }

  const out: Omit<EligibleApplicantsParams, "q" | "page" | "page_size"> = {}

  const ord = f.ordering.trim()
  if (ord) out.ordering = ord

  const hMin = trimInt(f.height_cm_min, 50, 300)
  const hMax = trimInt(f.height_cm_max, 50, 300)
  if (hMin !== undefined) out.height_cm_min = hMin
  if (hMax !== undefined) out.height_cm_max = hMax

  const wMin = trimInt(f.weight_kg_min, 15, 400)
  const wMax = trimInt(f.weight_kg_max, 15, 400)
  if (wMin !== undefined) out.weight_kg_min = wMin
  if (wMax !== undefined) out.weight_kg_max = wMax

  if (f.birth_date_from.trim()) out.birth_date_from = f.birth_date_from.trim()
  if (f.birth_date_to.trim()) out.birth_date_to = f.birth_date_to.trim()

  if (f.religion.trim()) out.religion = f.religion.trim()
  if (f.gender.trim()) out.gender = f.gender.trim()
  if (f.education_level.trim()) out.education_level = f.education_level.trim()
  if (f.marital_status.trim()) out.marital_status = f.marital_status.trim()
  if (f.writing_hand.trim()) out.writing_hand = f.writing_hand.trim()

  if (f.wears_glasses === "true") out.wears_glasses = true
  else if (f.wears_glasses === "false") out.wears_glasses = false

  if (f.has_passport === "true") out.has_passport = true
  else if (f.has_passport === "false") out.has_passport = false

  return out
}

function appendEligibleApplicantsParams(
  search: URLSearchParams,
  params: EligibleApplicantsParams
): void {
  const skipEmpty = (v: unknown): v is string | number =>
    v !== undefined &&
    v !== null &&
    (typeof v === "number" ||
      (typeof v === "string" && v.trim() !== ""))

  if (skipEmpty(params.q)) search.set("q", String(params.q))
  if (params.page != null) search.set("page", String(params.page))
  if (params.page_size != null) search.set("page_size", String(params.page_size))

  if (skipEmpty(params.ordering)) search.set("ordering", String(params.ordering))
  if (params.height_cm_min != null) search.set("height_cm_min", String(params.height_cm_min))
  if (params.height_cm_max != null) search.set("height_cm_max", String(params.height_cm_max))
  if (params.weight_kg_min != null) search.set("weight_kg_min", String(params.weight_kg_min))
  if (params.weight_kg_max != null) search.set("weight_kg_max", String(params.weight_kg_max))
  if (skipEmpty(params.birth_date_from))
    search.set("birth_date_from", String(params.birth_date_from))
  if (skipEmpty(params.birth_date_to))
    search.set("birth_date_to", String(params.birth_date_to))
  if (skipEmpty(params.religion)) search.set("religion", String(params.religion))
  if (skipEmpty(params.gender)) search.set("gender", String(params.gender))
  if (skipEmpty(params.education_level))
    search.set("education_level", String(params.education_level))
  if (skipEmpty(params.marital_status))
    search.set("marital_status", String(params.marital_status))
  if (skipEmpty(params.writing_hand))
    search.set("writing_hand", String(params.writing_hand))
  if (typeof params.wears_glasses === "boolean") {
    search.set("wears_glasses", params.wears_glasses ? "true" : "false")
  }
  if (typeof params.has_passport === "boolean") {
    search.set("has_passport", params.has_passport ? "true" : "false")
  }
}

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
  appendEligibleApplicantsParams(search, params)
  const qs = search.toString()
  const path = `/api/batches/${batchId}/eligible-applicants/${qs ? `?${qs}` : ""}`
  const { data } = await api.get<unknown>(path)
  return unwrapPaginated<ApplicantSearchRow>(data)
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
 * Admin creates a broadcast announcement for applicants in this batch (see recipient_config).
 */
export async function createBatchAnnouncement(
  batchId: number,
  input: CreateAnnouncementInput
): Promise<{ announcement: BatchAnnouncement; detail?: string }> {
  const { data } = await api.post<{
    data: BatchAnnouncement
    detail?: string
    code?: string
  }>(`/api/batches/${batchId}/announcements/`, input)
  return { announcement: data.data, detail: data.detail }
}

/**
 * POST /api/batches/{id}/announcements/preview-recipients/
 * Preview how many pelamar would receive the announcement for the given recipient_config.
 */
export async function previewBatchAnnouncementRecipients(
  batchId: number,
  recipientConfig: BatchAnnouncementRecipientConfig
): Promise<{ recipient_count: number }> {
  const { data } = await api.post<unknown>(
    `/api/batches/${batchId}/announcements/preview-recipients/`,
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
 * GET /api/batches/{id}/export-excel/
 * Downloads an .xlsx with applicant biodata for this batch.
 * Pass `statuses` to limit rows to those lamaran tahapan (repeatable query param `status`).
 * Omit `statuses` to include every tahapan in the batch.
 * Triggers a browser file download automatically.
 */
export async function exportBatchExcel(
  batchId: number,
  batchName: string,
  statuses?: ApplicationStatus[]
): Promise<void> {
  const search = new URLSearchParams()
  if (statuses?.length) {
    for (const s of statuses) {
      search.append("status", s)
    }
  }
  const qs = search.toString()
  const response = await api.get(
    `/api/batches/${batchId}/export-excel/${qs ? `?${qs}` : ""}`,
    {
      responseType: "blob",
    }
  )
  const blob = new Blob([response.data], {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  })
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  const safeName = batchName.replace(/[^a-zA-Z0-9\s_-]/g, "").trim().replace(/\s+/g, "_")
  const stagePart =
    statuses?.length === 1
      ? `_${statuses[0]}`
      : statuses?.length
        ? `_tahapan_${statuses.length}`
        : ""
  a.href = url
  a.download = `pelamar_${safeName}${stagePart}.xlsx`
  a.style.display = "none"
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}
