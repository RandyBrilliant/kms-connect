/**
 * TanStack Query hooks for reports (laporan).
 */

import { useQuery } from "@tanstack/react-query"
import { getApplicantReport } from "@/api/reports"
import type { ReportParams } from "@/types/report"

/**
 * Query keys for reports
 */
export const reportKeys = {
  all: ["reports"] as const,
  applicants: (params: ReportParams) =>
    [...reportKeys.all, "applicants", params] as const,
}

/**
 * Hook to fetch applicant report with date range filtering
 */
export function useApplicantReportQuery(params: ReportParams) {
  return useQuery({
    queryKey: reportKeys.applicants(params),
    queryFn: () => getApplicantReport(params),
    // Data is relatively stable, cache for 5 minutes
    staleTime: 5 * 60 * 1000,
    // Only fetch if we have valid params
    enabled: !!params.start_date && !!params.end_date,
  })
}
