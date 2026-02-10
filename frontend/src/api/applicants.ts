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
    search.set("applicant_profile__verification_status", params.verification_status)
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

/** POST /api/applicants/:id/send_verification_email/ */
export async function sendVerificationEmail(
  userId: number
): Promise<{ user_id: number; email: string }> {
  const { data } = await api.post<{ user_id: number; email: string }>(
    `/api/applicants/${userId}/send_verification_email/`
  )
  return data
}

/** POST /api/applicants/:id/send_password_reset_email/ */
export async function sendPasswordResetEmail(
  userId: number
): Promise<{ user_id: number; email: string }> {
  const { data } = await api.post<{ user_id: number; email: string }>(
    `/api/applicants/${userId}/send_password_reset_email/`
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
