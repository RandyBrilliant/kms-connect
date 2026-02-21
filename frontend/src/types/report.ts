/**
 * Report types for applicant statistics with date range filtering.
 */

export interface ReportDateRange {
  start_date: string // YYYY-MM-DD
  end_date: string // YYYY-MM-DD
}

export interface ReportSummary {
  total_applicants: number
  total_accepted: number
  total_rejected: number
  total_submitted: number
  total_draft: number
  completion_rate: number // Percentage of applicants with all required documents
}

export interface StatusBreakdown {
  verification_status: string
  count: number
}

export interface ProvinceBreakdown {
  province_name: string | null
  count: number
}

export interface GenderBreakdown {
  gender: string | null
  count: number
}

export interface EducationBreakdown {
  education_level: string | null
  count: number
}

export interface DestinationBreakdown {
  destination_country: string | null
  count: number
}

export interface ReferrerBreakdown {
  staff_id: number
  staff_name: string
  count: number
}

export interface TimelinePoint {
  date: string // YYYY-MM-DD
  count: number
}

export interface ApplicantReport {
  date_range: ReportDateRange
  summary: ReportSummary
  by_status: StatusBreakdown[]
  by_province: ProvinceBreakdown[]
  by_gender: GenderBreakdown[]
  by_education: EducationBreakdown[]
  by_destination: DestinationBreakdown[]
  by_referrer: ReferrerBreakdown[]
  timeline: TimelinePoint[]
}

export interface ReportParams {
  start_date?: string // YYYY-MM-DD (defaults to first day of current month)
  end_date?: string // YYYY-MM-DD (defaults to today)
}
