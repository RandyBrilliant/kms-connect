/**
 * Applications API — CRUD + assign + transition.
 * Backend: /api/applications/
 */

import { api } from "@/lib/api"
import type { PaginatedResponse } from "@/types/admin"
import type {
  JobApplication,
  ApplicationsListParams,
  AssignApplicationInput,
  TransitionApplicationInput,
} from "@/types/job-applications"

function buildQueryString(params: ApplicationsListParams): string {
  const search = new URLSearchParams()
  if (params.page != null) search.set("page", String(params.page))
  if (params.page_size != null) search.set("page_size", String(params.page_size))
  if (params.search) search.set("search", params.search)
  if (params.status && params.status !== "ALL") search.set("status", params.status)
  if (params.source && params.source !== "ALL") search.set("source", params.source)
  if (params.job != null) search.set("job", String(params.job))
  if (params.applicant != null) search.set("applicant", String(params.applicant))
  if (params.ordering) search.set("ordering", params.ordering)
  const qs = search.toString()
  return qs ? `?${qs}` : ""
}

/** GET /api/applications/ */
export async function getApplications(
  params: ApplicationsListParams = {}
): Promise<PaginatedResponse<JobApplication>> {
  const { data } = await api.get<PaginatedResponse<JobApplication>>(
    `/api/applications/${buildQueryString(params)}`
  )
  return data
}

/** GET /api/applications/:id/ */
export async function getApplication(id: number): Promise<JobApplication> {
  const { data } = await api.get<JobApplication>(`/api/applications/${id}/`)
  return data
}

/** POST /api/applications/assign/ — admin assigns applicant to job */
export async function assignApplication(
  input: AssignApplicationInput
): Promise<JobApplication> {
  const { data } = await api.post<{ data: JobApplication }>(
    "/api/applications/assign/",
    input
  )
  return data.data
}

/** PATCH /api/applications/:id/transition/ — move to new status */
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

/** PATCH /api/applications/:id/ — update notes field */
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
