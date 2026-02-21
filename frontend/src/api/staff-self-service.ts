/**
 * Staff self-service API - for staff users to access their own data.
 * Backend: /api/staff/me/
 */

import { api } from "@/lib/api"
import type { PaginatedResponse } from "@/types/admin"
import type { JobItem, JobsListParams } from "@/types/jobs"
import type { ApplicantUser } from "@/types/applicant"

export interface StaffDashboardStats {
  total_referred_applicants: number
  total_active: number
  total_accepted: number
  total_submitted: number
  verification_breakdown: Record<string, number>
  recent_applicants: ApplicantUser[]
}

function buildJobsQueryString(params: JobsListParams): string {
  const searchParams = new URLSearchParams()
  if (params.page) searchParams.set("page", params.page.toString())
  if (params.page_size) searchParams.set("page_size", params.page_size.toString())
  if (params.search) searchParams.set("search", params.search)
  if (params.status && params.status !== "ALL") searchParams.set("status", params.status)
  if (params.employment_type && params.employment_type !== "ALL")
    searchParams.set("employment_type", params.employment_type)
  if (params.company) searchParams.set("company", params.company.toString())
  if (params.ordering) searchParams.set("ordering", params.ordering)
  const str = searchParams.toString()
  return str ? `?${str}` : ""
}

/** GET /api/staff/me/jobs/ - List all job listings */
export async function getStaffJobs(
  params: JobsListParams = {}
): Promise<PaginatedResponse<JobItem>> {
  const { data } = await api.get<PaginatedResponse<JobItem>>(
    `/api/staff/me/jobs/${buildJobsQueryString(params)}`
  )
  return data
}

/** GET /api/staff/me/jobs/:id/ - Get single job listing */
export async function getStaffJob(id: number): Promise<JobItem> {
  const { data } = await api.get<JobItem>(`/api/staff/me/jobs/${id}/`)
  return data
}

/** GET /api/staff/me/applicants/ - List applicants referred by this staff */
export async function getStaffReferredApplicants(
  params: { 
    page?: number
    page_size?: number
    search?: string
    ordering?: string
    verification_status?: string
  } = {}
): Promise<PaginatedResponse<ApplicantUser>> {
  const searchParams = new URLSearchParams()
  if (params.page) searchParams.set("page", params.page.toString())
  if (params.page_size) searchParams.set("page_size", params.page_size.toString())
  if (params.search) searchParams.set("search", params.search)
  if (params.ordering) searchParams.set("ordering", params.ordering)
  if (params.verification_status)
    searchParams.set("applicant_profile__verification_status", params.verification_status)
  const str = searchParams.toString()
  const queryString = str ? `?${str}` : ""

  const { data } = await api.get<PaginatedResponse<ApplicantUser>>(
    `/api/staff/me/applicants/${queryString}`
  )
  return data
}

/** GET /api/staff/me/applicants/:id/ - Get single referred applicant */
export async function getStaffReferredApplicant(id: number): Promise<ApplicantUser> {
  const { data } = await api.get<ApplicantUser>(`/api/staff/me/applicants/${id}/`)
  return data
}

/** GET /api/staff/me/dashboard-stats/ - Get dashboard statistics */
export async function getStaffDashboardStats(): Promise<StaffDashboardStats> {
  const { data } = await api.get<{ data: StaffDashboardStats }>(
    "/api/staff/me/dashboard-stats/"
  )
  return data.data
}
