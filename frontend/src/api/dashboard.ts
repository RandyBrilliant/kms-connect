/**
 * Admin dashboard API - applicant statistics.
 */

import { api } from "@/lib/api"
import type {
  AdminApplicantSummary,
  ApplicantTimeseriesPoint,
  LatestApplicantRow,
} from "@/types/dashboard"

export async function getAdminApplicantSummary(): Promise<AdminApplicantSummary> {
  const { data } = await api.get<AdminApplicantSummary>(
    "/api/dashboard/applicants/summary/"
  )
  return data
}

export async function getAdminApplicantTimeseries(): Promise<
  ApplicantTimeseriesPoint[]
> {
  const { data } = await api.get<ApplicantTimeseriesPoint[]>(
    "/api/dashboard/applicants/timeseries/"
  )
  return data
}

export async function getAdminLatestApplicants(): Promise<LatestApplicantRow[]> {
  const { data } = await api.get<LatestApplicantRow[]>(
    "/api/dashboard/applicants/latest/"
  )
  return data
}

