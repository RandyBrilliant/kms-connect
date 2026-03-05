/**
 * Applications API — read, individual FSM transitions, applicant confirm.
 * Backend: /api/applications/ and /api/applicants/me/applications/
 *
 * Assignment is handled by the batch API (batches.ts).
 */

import { api } from "@/lib/api"
import type { PaginatedResponse } from "@/types/admin"
import type {
  JobApplication,
  ApplicationsListParams,
  AssignApplicationInput,
  TransitionApplicationInput,
} from "@/types/job-applications"
import type { BatchAnnouncement } from "@/types/lamaran-batch"

function buildQueryString(params: ApplicationsListParams): string {
  const search = new URLSearchParams()
  if (params.page != null) search.set("page", String(params.page))
  if (params.page_size != null) search.set("page_size", String(params.page_size))
  if (params.search) search.set("search", params.search)
  if (params.status && params.status !== "ALL") search.set("status", params.status)
  if (params.job != null) search.set("job", String(params.job))
  if (params.applicant != null) search.set("applicant", String(params.applicant))
  if (params.batch != null) search.set("batch", String(params.batch))
  if (params.ordering) search.set("ordering", params.ordering)
  const qs = search.toString()
  return qs ? `?${qs}` : ""
}

/** GET /api/applications/ — admin lists all applications */
export async function getApplications(
  params: ApplicationsListParams = {}
): Promise<PaginatedResponse<JobApplication>> {
  const { data } = await api.get<PaginatedResponse<JobApplication>>(
    `/api/applications/${buildQueryString(params)}`
  )
  return data
}

/** GET /api/applications/:id/ — admin gets single application */
export async function getApplication(id: number): Promise<JobApplication> {
  const { data } = await api.get<JobApplication>(`/api/applications/${id}/`)
  return data
}

/** POST /api/applications/ — admin assigns an applicant to a job */
export async function assignApplication(
  input: AssignApplicationInput
): Promise<JobApplication> {
  const { data } = await api.post<JobApplication>("/api/applications/", {
    job: input.job,
    applicant: input.applicant,
    notes: input.note ?? "",
  })
  return data
}

/** PATCH /api/applications/:id/transition/ — admin moves to new status */
export async function transitionApplication(
  id: number,
  input: TransitionApplicationInput
): Promise<JobApplication> {
  const { data } = await api.patch<{ data: JobApplication }>(
    `/api/applications/${id}/transition/`,
    input
  )
  return data.data
}

/** PATCH /api/applications/:id/ — admin updates notes field */
export async function patchApplication(
  id: number,
  input: Pick<JobApplication, "notes">
): Promise<JobApplication> {
  const { data } = await api.patch<JobApplication>(
    `/api/applications/${id}/`,
    input
  )
  return data
}

// ---------------------------------------------------------------------------
// Applicant self-service
// ---------------------------------------------------------------------------

/** GET /api/applicants/me/applications/ — applicant lists own applications */
export async function getMyApplications(): Promise<JobApplication[]> {
  const { data } = await api.get<JobApplication[]>("/api/applicants/me/applications/")
  return data
}

/** GET /api/applicants/me/applications/:id/ — applicant gets own application detail */
export async function getMyApplication(id: number): Promise<JobApplication> {
  const { data } = await api.get<JobApplication>(
    `/api/applicants/me/applications/${id}/`
  )
  return data
}

/**
 * POST /api/applicants/me/applications/:id/confirm/
 * Applicant confirms attendance at current stage (Pra-Seleksi or Interview).
 */
export async function confirmApplicationAttendance(
  id: number
): Promise<JobApplication> {
  const { data } = await api.post<{ data: JobApplication }>(
    `/api/applicants/me/applications/${id}/confirm/`
  )
  return data.data
}

/**
 * GET /api/applicants/me/applications/:id/announcements/
 * Returns batch broadcast announcements for this application.
 * Used for PRA_SELEKSI and INTERVIEW stages as primary communication channel.
 */
export async function getApplicationAnnouncements(
  id: number
): Promise<BatchAnnouncement[]> {
  const { data } = await api.get<{ data: BatchAnnouncement[] }>(
    `/api/applicants/me/applications/${id}/announcements/`
  )
  return data.data
}
