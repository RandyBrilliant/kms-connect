/**
 * Admin dashboard types for applicant statistics.
 */

export interface AdminApplicantSummary {
  total_applicants: number
  total_active_workers: number
  total_inactive_workers: number
  growth_rate_30d: number
}

export interface ApplicantTimeseriesPoint {
  date: string // ISO date (YYYY-MM-DD)
  count: number
}

export interface LatestApplicantRow {
  id: number
  full_name: string
  email: string
  verification_status: string
  created_at: string
}

