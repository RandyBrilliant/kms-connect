/**
 * Jobs API - CRUD for Lowongan Kerja (admin-side).
 * Backend: /api/jobs/
 */

import { api } from "@/lib/api"
import type { PaginatedResponse } from "@/types/admin"
import type { JobItem, JobsListParams } from "@/types/jobs"

function buildQueryString(params: JobsListParams): string {
  const search = new URLSearchParams()
  if (params.page != null) search.set("page", String(params.page))
  if (params.page_size != null) search.set("page_size", String(params.page_size))
  if (params.search) search.set("search", params.search)
  if (params.status && params.status !== "ALL") search.set("status", params.status)
  if (params.employment_type && params.employment_type !== "ALL")
    search.set("employment_type", params.employment_type)
  if (params.company != null) search.set("company", String(params.company))
  if (params.ordering) search.set("ordering", params.ordering)
  const qs = search.toString()
  return qs ? `?${qs}` : ""
}

/** GET /api/jobs/ - List with pagination, search, filter */
export async function getJobs(
  params: JobsListParams = {}
): Promise<PaginatedResponse<JobItem>> {
  const { data } = await api.get<PaginatedResponse<JobItem>>(
    `/api/jobs/${buildQueryString(params)}`
  )
  return data
}

/** GET /api/jobs/:id/ - Retrieve single job */
export async function getJob(id: number): Promise<JobItem> {
  const { data } = await api.get<JobItem>(`/api/jobs/${id}/`)
  return data
}

/** POST /api/jobs/ - Create job */
export async function createJob(input: Partial<JobItem>): Promise<JobItem> {
  const { data } = await api.post<JobItem>("/api/jobs/", input)
  return data
}

/** PATCH /api/jobs/:id/ - Partial update */
export async function patchJob(
  id: number,
  input: Partial<JobItem>
): Promise<JobItem> {
  const { data } = await api.patch<JobItem>(`/api/jobs/${id}/`, input)
  return data
}

/** DELETE /api/jobs/:id/ */
export async function deleteJob(id: number): Promise<void> {
  await api.delete(`/api/jobs/${id}/`)
}

