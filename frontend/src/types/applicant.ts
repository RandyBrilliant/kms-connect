/**
 * Applicant (Pelamar) types - matches backend ApplicantUserSerializer and nested models.
 */

export type ApplicantVerificationStatus =
  | "DRAFT"
  | "SUBMITTED"
  | "ACCEPTED"
  | "REJECTED"

export type Gender = "M" | "F" | "O"

export interface ApplicantProfile {
  id: number
  referrer: number | null
  full_name: string
  birth_place: string
  birth_date: string | null
  address: string
  contact_phone: string
  sibling_count: number | null
  birth_order: number | null
  father_name: string
  father_age: number | null
  father_occupation: string
  mother_name: string
  mother_age: number | null
  mother_occupation: string
  spouse_name: string
  spouse_age: number | null
  spouse_occupation: string
  family_address: string
  family_contact_phone: string
  nik: string
  gender: string
  photo: string | null
  notes: string
  verification_status: ApplicantVerificationStatus
  submitted_at: string | null
  verified_at: string | null
  verified_by: number | null
  verification_notes: string
  created_at: string
  updated_at: string
}

export interface ApplicantUser {
  id: number
  email: string
  role: string
  is_active: boolean
  email_verified: boolean
  email_verified_at: string | null
  date_joined: string
  updated_at: string
  applicant_profile: ApplicantProfile
}

export interface ApplicantUserCreateInput {
  email: string
  password: string
  applicant_profile: {
    full_name: string
    nik: string
    birth_place?: string
    birth_date?: string | null
    address?: string
    contact_phone?: string
    gender?: string
    [key: string]: unknown
  }
}

export interface ApplicantUserUpdateInput {
  email?: string
  password?: string
  applicant_profile?: Partial<ApplicantProfile>
}

export interface WorkExperience {
  id: number
  company_name: string
  position: string
  start_date: string | null
  end_date: string | null
  still_employed: boolean
  description: string
  sort_order: number
  created_at: string
  updated_at: string
}

export interface WorkExperienceCreateInput {
  company_name: string
  position?: string
  start_date?: string | null
  end_date?: string | null
  still_employed?: boolean
  description?: string
  sort_order?: number
}

export interface DocumentType {
  id: number
  code: string
  name: string
  is_required: boolean
  sort_order: number
  description: string
}

export type DocumentReviewStatus = "PENDING" | "APPROVED" | "REJECTED"

export interface ApplicantDocument {
  id: number
  document_type: number
  file: string
  uploaded_at: string
  ocr_text: string
  ocr_data: Record<string, unknown> | null
  ocr_processed_at: string | null
  review_status: DocumentReviewStatus
  reviewed_by: number | null
  reviewed_at: string | null
  review_notes: string
  reviewed_by_name?: string | null
}

export interface ApplicantsListParams {
  page?: number
  page_size?: number
  search?: string
  is_active?: boolean
  email_verified?: boolean
  verification_status?: ApplicantVerificationStatus
  ordering?: string
}

export interface PaginatedResponse<T> {
  count: number
  next: string | null
  previous: string | null
  results: T[]
}
