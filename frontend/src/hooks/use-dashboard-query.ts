/**
 * TanStack Query hooks for admin dashboard (applicants).
 */

import { useQuery } from "@tanstack/react-query"

import {
  getAdminApplicantSummary,
  getAdminApplicantTimeseries,
  getAdminLatestApplicants,
} from "@/api/dashboard"

export const dashboardKeys = {
  all: ["dashboard"] as const,
  applicants: () => [...dashboardKeys.all, "applicants"] as const,
  summary: () => [...dashboardKeys.applicants(), "summary"] as const,
  timeseries: () => [...dashboardKeys.applicants(), "timeseries"] as const,
  latest: () => [...dashboardKeys.applicants(), "latest"] as const,
}

export function useAdminApplicantSummaryQuery() {
  return useQuery({
    queryKey: dashboardKeys.summary(),
    queryFn: getAdminApplicantSummary,
  })
}

export function useAdminApplicantTimeseriesQuery() {
  return useQuery({
    queryKey: dashboardKeys.timeseries(),
    queryFn: getAdminApplicantTimeseries,
  })
}

export function useAdminLatestApplicantsQuery() {
  return useQuery({
    queryKey: dashboardKeys.latest(),
    queryFn: getAdminLatestApplicants,
  })
}

