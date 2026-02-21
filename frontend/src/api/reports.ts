/**
 * Reports API - Applicant statistics with date range filtering.
 */

import { api } from "@/lib/api"
import type { ApplicantReport, ReportParams } from "@/types/report"

/**
 * Build query string for report params
 */
function buildReportQueryString(params: ReportParams): string {
  const search = new URLSearchParams()
  if (params.start_date) search.set("start_date", params.start_date)
  if (params.end_date) search.set("end_date", params.end_date)
  const qs = search.toString()
  return qs ? `?${qs}` : ""
}

/**
 * GET /api/reports/applicants/ - Get applicant statistics report
 * @param params Optional date range filters (defaults to current month)
 */
export async function getApplicantReport(
  params: ReportParams = {}
): Promise<ApplicantReport> {
  const queryString = buildReportQueryString(params)
  const { data } = await api.get<ApplicantReport>(
    `/api/reports/applicants/${queryString}`
  )
  return data
}
