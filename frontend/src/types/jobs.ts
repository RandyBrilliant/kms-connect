/**
 * Lowongan Kerja types - matches backend main.LowonganKerjaSerializer.
 */

export type JobStatus = "DRAFT" | "OPEN" | "CLOSED" | "ARCHIVED"
export type EmploymentType = "FULL_TIME" | "PART_TIME" | "CONTRACT" | "INTERNSHIP"

export interface JobItem {
  id: number
  title: string
  slug: string
  company: number
  company_name?: string | null
  location_country: string
  location_city: string
  description: string
  requirements: string
  employment_type: EmploymentType
  salary_min: number | null
  salary_max: number | null
  currency: string
  status: JobStatus
  posted_at: string | null
  deadline: string | null
  created_by: number | null
  created_by_name?: string | null
  created_at: string
  updated_at: string
}

export interface JobsListParams {
  page?: number
  page_size?: number
  search?: string
  status?: JobStatus | "ALL"
  employment_type?: EmploymentType | "ALL"
  company?: number
  ordering?: string
}

