/**
 * Company self-service API - for company users to access their own data.
 * Backend: /api/companies/me/
 */

import { api } from "@/lib/api"
import type { PaginatedResponse } from "@/types/admin"
import type { JobItem, JobsListParams } from "@/types/jobs"
import type {
  JobApplication,
  JobApplicationsListParams,
  CompanyDashboardStats,
} from "@/types/job-applications"
import type { ApplicantUser } from "@/types/applicant"

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

function buildApplicationsQueryString(params: JobApplicationsListParams): string {
  const searchParams = new URLSearchParams()
  if (params.page) searchParams.set("page", params.page.toString())
  if (params.page_size) searchParams.set("page_size", params.page_size.toString())
  if (params.search) searchParams.set("search", params.search)
  if (params.status && params.status !== "ALL") searchParams.set("status", params.status)
  if (params.job) searchParams.set("job", params.job.toString())
  if (params.ordering) searchParams.set("ordering", params.ordering)
  const str = searchParams.toString()
  return str ? `?${str}` : ""
}

/** GET /api/companies/me/jobs/ - List company's own job listings */
export async function getCompanyJobs(
  params: JobsListParams = {}
): Promise<PaginatedResponse<JobItem>> {
  const { data } = await api.get<PaginatedResponse<JobItem>>(
    `/api/companies/me/jobs/${buildJobsQueryString(params)}`
  )
  return data
}

/** GET /api/companies/me/jobs/:id/ - Get single job listing */
export async function getCompanyJob(id: number): Promise<JobItem> {
  const { data } = await api.get<JobItem>(`/api/companies/me/jobs/${id}/`)
  return data
}

/** GET /api/companies/me/applicants/ - List applicants who applied to company's jobs */
export async function getCompanyApplicants(
  params: { page?: number; page_size?: number; search?: string; ordering?: string } = {}
): Promise<PaginatedResponse<ApplicantUser>> {
  const searchParams = new URLSearchParams()
  if (params.page) searchParams.set("page", params.page.toString())
  if (params.page_size) searchParams.set("page_size", params.page_size.toString())
  if (params.search) searchParams.set("search", params.search)
  if (params.ordering) searchParams.set("ordering", params.ordering)
  const str = searchParams.toString()
  const queryString = str ? `?${str}` : ""

  const { data } = await api.get<PaginatedResponse<ApplicantUser>>(
    `/api/companies/me/applicants/${queryString}`
  )
  return data
}

/** GET /api/companies/me/applicants/:id/ - Get single applicant */
export async function getCompanyApplicant(id: number): Promise<ApplicantUser> {
  const { data } = await api.get<ApplicantUser>(`/api/companies/me/applicants/${id}/`)
  return data
}

/** GET /api/companies/me/applications/ - List applications to company's jobs */
export async function getCompanyApplications(
  params: JobApplicationsListParams = {}
): Promise<PaginatedResponse<JobApplication>> {
  const { data } = await api.get<PaginatedResponse<JobApplication>>(
    `/api/companies/me/applications/${buildApplicationsQueryString(params)}`
  )
  return data
}

/** GET /api/companies/me/applications/:id/ - Get single application */
export async function getCompanyApplication(id: number): Promise<JobApplication> {
  const { data } = await api.get<JobApplication>(
    `/api/companies/me/applications/${id}/`
  )
  return data
}

/** GET /api/companies/me/dashboard-stats/ - Get dashboard statistics */
export async function getCompanyDashboardStats(): Promise<CompanyDashboardStats> {
  const { data } = await api.get<{ data: CompanyDashboardStats }>(
    "/api/companies/me/dashboard-stats/"
  )
  return data.data
}
