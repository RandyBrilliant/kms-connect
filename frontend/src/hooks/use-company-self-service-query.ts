/**
 * TanStack Query hooks for company self-service endpoints.
 */

import { useQuery } from "@tanstack/react-query"
import {
  getCompanyJobs,
  getCompanyJob,
  getCompanyApplicants,
  getCompanyApplicant,
  getCompanyApplications,
  getCompanyApplication,
  getCompanyDashboardStats,
} from "@/api/company-self-service"
import type { JobsListParams } from "@/types/jobs"
import type { JobApplicationsListParams } from "@/types/job-applications"

export const companyKeys = {
  all: ["company-self-service"] as const,
  jobs: () => [...companyKeys.all, "jobs"] as const,
  jobsList: (params: JobsListParams) => [...companyKeys.jobs(), params] as const,
  jobDetail: (id: number) => [...companyKeys.jobs(), id] as const,
  applicants: () => [...companyKeys.all, "applicants"] as const,
  applicantsList: (params: unknown) => [...companyKeys.applicants(), params] as const,
  applicantDetail: (id: number) => [...companyKeys.applicants(), id] as const,
  applications: () => [...companyKeys.all, "applications"] as const,
  applicationsList: (params: JobApplicationsListParams) =>
    [...companyKeys.applications(), params] as const,
  applicationDetail: (id: number) => [...companyKeys.applications(), id] as const,
  dashboardStats: () => [...companyKeys.all, "dashboard-stats"] as const,
}

export function useCompanyJobsQuery(params: JobsListParams = {}) {
  return useQuery({
    queryKey: companyKeys.jobsList(params),
    queryFn: () => getCompanyJobs(params),
  })
}

export function useCompanyJobQuery(id: number | null, enabled = true) {
  return useQuery({
    queryKey: companyKeys.jobDetail(id!),
    queryFn: () => getCompanyJob(id!),
    enabled: enabled && id !== null,
  })
}

export function useCompanyApplicantsQuery(
  params: { page?: number; page_size?: number; search?: string; ordering?: string } = {}
) {
  return useQuery({
    queryKey: companyKeys.applicantsList(params),
    queryFn: () => getCompanyApplicants(params),
  })
}

export function useCompanyApplicantQuery(id: number | null, enabled = true) {
  return useQuery({
    queryKey: companyKeys.applicantDetail(id!),
    queryFn: () => getCompanyApplicant(id!),
    enabled: enabled && id !== null,
  })
}

export function useCompanyApplicationsQuery(params: JobApplicationsListParams = {}) {
  return useQuery({
    queryKey: companyKeys.applicationsList(params),
    queryFn: () => getCompanyApplications(params),
  })
}

export function useCompanyApplicationQuery(id: number | null, enabled = true) {
  return useQuery({
    queryKey: companyKeys.applicationDetail(id!),
    queryFn: () => getCompanyApplication(id!),
    enabled: enabled && id !== null,
  })
}

export function useCompanyDashboardStatsQuery() {
  return useQuery({
    queryKey: companyKeys.dashboardStats(),
    queryFn: () => getCompanyDashboardStats(),
  })
}
