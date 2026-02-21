/**
 * Job Applications types - matches backend main.JobApplicationSerializer.
 */

export type ApplicationStatus = "APPLIED" | "UNDER_REVIEW" | "ACCEPTED" | "REJECTED"

export interface JobApplication {
  id: number
  applicant: number
  applicant_name?: string
  applicant_email?: string
  job: number
  job_title?: string
  company_name?: string
  status: ApplicationStatus
  applied_at: string
  reviewed_at: string | null
  reviewed_by: number | null
  reviewed_by_name?: string | null
  notes: string
  created_at: string
  updated_at: string
}

export interface JobApplicationsListParams {
  page?: number
  page_size?: number
  search?: string
  status?: ApplicationStatus | "ALL"
  job?: number
  ordering?: string
}

export interface CompanyDashboardStats {
  total_jobs: number
  total_open_jobs: number
  total_applications: number
  total_applicants: number
  status_breakdown: Record<ApplicationStatus, number>
  recent_applications: JobApplication[]
}
