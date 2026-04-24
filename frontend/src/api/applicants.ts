/**
 * Applicants (Pelamar) API - CRUD for Applicant role users.
 * Backend: /api/applicants/
 * Nested: work_experiences, documents
 */

import { api } from "@/lib/api"
import type {
  ApplicantUser,
  ApplicantUserCreateInput,
  ApplicantUserUpdateInput,
  ApplicantsListParams,
  PaginatedResponse,
  WorkExperience,
  WorkExperienceCreateInput,
  ApplicantDocument,
  DocumentType,
} from "@/types/applicant"

function buildQueryString(params: ApplicantsListParams): string {
  const search = new URLSearchParams()
  if (params.page != null) search.set("page", String(params.page))
  if (params.page_size != null) search.set("page_size", String(params.page_size))
  if (params.search) search.set("search", params.search)
  if (params.is_active != null) search.set("is_active", String(params.is_active))
  if (params.email_verified != null)
    search.set("email_verified", String(params.email_verified))
  if (params.verification_status)
    search.set("verification_status", params.verification_status)
  if (params.referrer != null) search.set("referrer", String(params.referrer))
  if (params.created_at_after) search.set("created_at_after", params.created_at_after)
  if (params.created_at_before) search.set("created_at_before", params.created_at_before)
  if (params.ordering) search.set("ordering", params.ordering)
  const qs = search.toString()
  return qs ? `?${qs}` : ""
}

function buildExportQueryString(params: Omit<ApplicantsListParams, "page" | "page_size">): string {
  const search = new URLSearchParams()
  if (params.search) search.set("search", params.search)
  if (params.is_active != null) search.set("is_active", String(params.is_active))
  if (params.email_verified != null)
    search.set("email_verified", String(params.email_verified))
  if (params.verification_status)
    search.set("verification_status", params.verification_status)
  if (params.referrer != null) search.set("referrer", String(params.referrer))
  if (params.created_at_after) search.set("created_at_after", params.created_at_after)
  if (params.created_at_before) search.set("created_at_before", params.created_at_before)
  if (params.ordering) search.set("ordering", params.ordering)
  const qs = search.toString()
  return qs ? `?${qs}` : ""
}

/** GET /api/applicants/ - List with pagination, search, filter */
export async function getApplicants(
  params: ApplicantsListParams = {}
): Promise<PaginatedResponse<ApplicantUser>> {
  const { data } = await api.get<PaginatedResponse<ApplicantUser>>(
    `/api/applicants/${buildQueryString(params)}`
  )
  return data
}

/** GET /api/applicants/export/ - Export applicants to Excel */
export async function exportApplicants(
  params: Omit<ApplicantsListParams, "page" | "page_size"> = {}
): Promise<Blob> {
  const { data } = await api.get<Blob>(`/api/applicants/export/${buildExportQueryString(params)}`, {
    responseType: "blob",
  })
  return data
}

/** GET /api/applicants/:id/ - Retrieve single applicant */
export async function getApplicant(id: number): Promise<ApplicantUser> {
  const { data } = await api.get<ApplicantUser>(`/api/applicants/${id}/`)
  return data
}

/** POST /api/applicants/ - Create applicant */
export async function createApplicant(
  input: ApplicantUserCreateInput
): Promise<ApplicantUser> {
  const { data } = await api.post<ApplicantUser>("/api/applicants/", input)
  return data
}

/** PATCH /api/applicants/:id/ - Partial update */
export async function patchApplicant(
  id: number,
  input: Partial<ApplicantUserUpdateInput>
): Promise<ApplicantUser> {
  const { data } = await api.patch<ApplicantUser>(`/api/applicants/${id}/`, input)
  return data
}

/** POST /api/applicants/:id/deactivate/ */
export async function deactivateApplicant(id: number): Promise<ApplicantUser> {
  const { data } = await api.post<{ data: ApplicantUser }>(
    `/api/applicants/${id}/deactivate/`
  )
  return data.data
}

/** POST /api/applicants/:id/activate/ */
export async function activateApplicant(id: number): Promise<ApplicantUser> {
  const { data } = await api.post<{ data: ApplicantUser }>(
    `/api/applicants/${id}/activate/`
  )
  return data.data
}

/** POST /api/applicants/:id/permanent-delete/ — Admin Utama only; irreversible. */
export async function permanentDeleteApplicant(
  id: number
): Promise<{ id: number; email: string }> {
  const { data } = await api.post<{
    data: { id: number; email: string }
    detail?: string
  }>(`/api/applicants/${id}/permanent-delete/`)
  return data.data
}

/** POST /api/admins/send-verification-email/ - Admin sends verification email to user */
export async function sendVerificationEmail(
  userId: number
): Promise<{ user_id: number; email: string }> {
  const { data } = await api.post<{ data: { user_id: number; email: string } }>(
    '/api/admins/send-verification-email/',
    { user_id: userId }
  )
  return data.data
}

/** POST /api/admins/send-password-reset/ - Admin sends password reset email to user */
export async function sendPasswordResetEmail(
  userId: number
): Promise<{ user_id: number; email: string }> {
  const { data } = await api.post<{ data: { user_id: number; email: string } }>(
    '/api/admins/send-password-reset/',
    { user_id: userId }
  )
  return data.data
}

/**
 * POST /api/applicant-profiles/:id/approve/
 * NOTE: Backend endpoint needs to be implemented
 */
export async function approveApplicant(
  profileId: number,
  notes: string
): Promise<{ success: boolean; message: string }> {
  const { data } = await api.post<{ success: boolean; message: string }>(
    `/api/applicant-profiles/${profileId}/approve/`,
    { notes }
  )
  return data
}

/**
 * POST /api/applicant-profiles/:id/reject/
 * NOTE: Backend endpoint needs to be implemented
 */
export async function rejectApplicant(
  profileId: number,
  notes: string
): Promise<{ success: boolean; message: string }> {
  const { data } = await api.post<{ success: boolean; message: string }>(
    `/api/applicant-profiles/${profileId}/reject/`,
    { notes }
  )
  return data
}

/** POST /api/applicant-profiles/bulk-approve/ */
export async function bulkApproveApplicants(
  profileIds: number[],
  notes: string
): Promise<{ success: boolean; message: string; updated: number }> {
  const { data } = await api.post<{ success: boolean; message: string; updated: number }>(
    `/api/applicant-profiles/bulk-approve/`,
    { profile_ids: profileIds, notes }
  )
  return data
}

/** POST /api/applicant-profiles/bulk-reject/ */
export async function bulkRejectApplicants(
  profileIds: number[],
  notes: string
): Promise<{ success: boolean; message: string; updated: number }> {
  const { data } = await api.post<{ success: boolean; message: string; updated: number }>(
    `/api/applicant-profiles/bulk-reject/`,
    { profile_ids: profileIds, notes }
  )
  return data
}

// --- Work Experiences ---
/** GET /api/applicants/:applicantId/work_experiences/ */
export async function getWorkExperiences(
  applicantId: number
): Promise<WorkExperience[]> {
  const { data } = await api.get<WorkExperience[]>(
    `/api/applicants/${applicantId}/work_experiences/`
  )
  return Array.isArray(data) ? data : (data as { results?: WorkExperience[] }).results ?? []
}

/** POST /api/applicants/:applicantId/work_experiences/ */
export async function createWorkExperience(
  applicantId: number,
  input: WorkExperienceCreateInput
): Promise<WorkExperience> {
  const { data } = await api.post<WorkExperience>(
    `/api/applicants/${applicantId}/work_experiences/`,
    input
  )
  return data
}

/** PATCH /api/applicants/:applicantId/work_experiences/:id/ */
export async function updateWorkExperience(
  applicantId: number,
  id: number,
  input: Partial<WorkExperienceCreateInput>
): Promise<WorkExperience> {
  const { data } = await api.patch<WorkExperience>(
    `/api/applicants/${applicantId}/work_experiences/${id}/`,
    input
  )
  return data
}

/** DELETE /api/applicants/:applicantId/work_experiences/:id/ */
export async function deleteWorkExperience(
  applicantId: number,
  id: number
): Promise<void> {
  await api.delete(`/api/applicants/${applicantId}/work_experiences/${id}/`)
}

// --- Documents ---
/** GET /api/applicants/:applicantId/documents/ */
export async function getApplicantDocuments(
  applicantId: number
): Promise<ApplicantDocument[]> {
  const { data } = await api.get<ApplicantDocument[]>(
    `/api/applicants/${applicantId}/documents/`
  )
  return Array.isArray(data) ? data : (data as { results?: ApplicantDocument[] }).results ?? []
}

/** POST /api/applicants/:applicantId/documents/ - Multipart form data */
export async function createApplicantDocument(
  applicantId: number,
  formData: FormData
): Promise<ApplicantDocument> {
  const { data } = await api.post<ApplicantDocument>(
    `/api/applicants/${applicantId}/documents/`,
    formData,
    {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    }
  )
  return data
}

/** PATCH /api/applicants/:applicantId/documents/:id/ */
export async function updateApplicantDocument(
  applicantId: number,
  id: number,
  input: {
    review_status?: "PENDING" | "APPROVED" | "REJECTED"
    review_notes?: string
  }
): Promise<ApplicantDocument> {
  const { data } = await api.patch<ApplicantDocument>(
    `/api/applicants/${applicantId}/documents/${id}/`,
    input
  )
  return data
}

/**
 * GET /api/applicants/:id/download-documents/
 * Downloads all uploaded documents for this applicant as a single ZIP archive.
 * Triggers a browser save-file dialog automatically.
 */
export async function downloadApplicantDocuments(
  applicantId: number,
  displayName: string
): Promise<void> {
  const response = await api.get(
    `/api/applicants/${applicantId}/download-documents/`,
    { responseType: "blob" }
  )

  // Prefer filename from Content-Disposition if available
  const disposition: string = response.headers["content-disposition"] ?? ""
  const match = disposition.match(/filename="?([^"]+)"?/)
  const safeName = displayName
    .replace(/[^a-zA-Z0-9\s_-]/g, "")
    .trim()
    .replace(/\s+/g, "_")
  const filename = match?.[1] ?? `Dokumen_${safeName}.zip`

  const blob = new Blob([response.data as BlobPart], { type: "application/zip" })
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  a.href = url
  a.download = filename
  a.style.display = "none"
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}

/**
 * GET /api/applicants/:id/biodata-pdf/
 * Fetches the Biodata CPMI PDF and opens it in a new browser tab for viewing.
 */
export async function viewBiodataPdf(applicantId: number): Promise<void> {
  const response = await api.get(
    `/api/applicants/${applicantId}/biodata-pdf/`,
    { responseType: "blob" }
  )
  const blob = new Blob([response.data as BlobPart], { type: "application/pdf" })
  const url = URL.createObjectURL(blob)
  const tab = window.open(url, "_blank")
  if (tab) {
    tab.addEventListener("load", () => URL.revokeObjectURL(url), { once: true })
  } else {
    setTimeout(() => URL.revokeObjectURL(url), 10_000)
  }
}

/**
 * GET /api/applicants/:id/inbond-pdf/
 * Fetches the Tanda Terima Pengembalian Biaya Transportasi (Inbond Cost) PDF
 * and opens it in a new browser tab. Admin-only.
 */
export async function viewInbondPdf(applicantId: number): Promise<void> {
  const response = await api.get(
    `/api/applicants/${applicantId}/inbond-pdf/`,
    { responseType: "blob" }
  )
  const blob = new Blob([response.data as BlobPart], { type: "application/pdf" })
  const url = URL.createObjectURL(blob)
  const tab = window.open(url, "_blank")
  if (tab) {
    tab.addEventListener("load", () => URL.revokeObjectURL(url), { once: true })
  } else {
    setTimeout(() => URL.revokeObjectURL(url), 10_000)
  }
}

/** DELETE /api/applicants/:applicantId/documents/:id/ */
export async function deleteApplicantDocument(
  applicantId: number,
  id: number
): Promise<void> {
  await api.delete(`/api/applicants/${applicantId}/documents/${id}/`)
}

// --- Document Types (read-only) ---
/** GET /api/document-types/ */
export async function getDocumentTypes(): Promise<DocumentType[]> {
  const { data } = await api.get<DocumentType[]>("/api/document-types/")
  return Array.isArray(data) ? data : (data as { results?: DocumentType[] }).results ?? []
}
