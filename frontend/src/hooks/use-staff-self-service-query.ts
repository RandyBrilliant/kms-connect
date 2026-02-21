/**
 * TanStack Query hooks for staff self-service endpoints.
 */

import { useQuery } from "@tanstack/react-query"
import {
  getStaffJobs,
  getStaffJob,
  getStaffReferredApplicants,
  getStaffReferredApplicant,
  getStaffDashboardStats,
} from "@/api/staff-self-service"
import type { JobsListParams } from "@/types/jobs"

export const staffKeys = {
  all: ["staff-self-service"] as const,
  jobs: () => [...staffKeys.all, "jobs"] as const,
  jobsList: (params: JobsListParams) => [...staffKeys.jobs(), params] as const,
  jobDetail: (id: number) => [...staffKeys.jobs(), id] as const,
  applicants: () => [...staffKeys.all, "applicants"] as const,
  applicantsList: (params: unknown) => [...staffKeys.applicants(), params] as const,
  applicantDetail: (id: number) => [...staffKeys.applicants(), id] as const,
  dashboardStats: () => [...staffKeys.all, "dashboard-stats"] as const,
}

export function useStaffJobsQuery(params: JobsListParams = {}) {
  return useQuery({
    queryKey: staffKeys.jobsList(params),
    queryFn: () => getStaffJobs(params),
  })
}

export function useStaffJobQuery(id: number | null, enabled = true) {
  return useQuery({
    queryKey: staffKeys.jobDetail(id!),
    queryFn: () => getStaffJob(id!),
    enabled: enabled && id !== null,
  })
}

export function useStaffReferredApplicantsQuery(
  params: {
    page?: number
    page_size?: number
    search?: string
    ordering?: string
    verification_status?: string
  } = {}
) {
  return useQuery({
    queryKey: staffKeys.applicantsList(params),
    queryFn: () => getStaffReferredApplicants(params),
  })
}

export function useStaffReferredApplicantQuery(id: number | null, enabled = true) {
  return useQuery({
    queryKey: staffKeys.applicantDetail(id!),
    queryFn: () => getStaffReferredApplicant(id!),
    enabled: enabled && id !== null,
  })
}

export function useStaffDashboardStatsQuery() {
  return useQuery({
    queryKey: staffKeys.dashboardStats(),
    queryFn: () => getStaffDashboardStats(),
  })
}
