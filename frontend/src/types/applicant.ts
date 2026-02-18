/**
 * Applicant (Pelamar) types - matches backend ApplicantUserSerializer and nested models.
 * Region fields (province, district, village) are FK IDs to regions app.
 * full_name is on CustomUser; WorkExperience.country uses ISO 3166-1 alpha-2.
 */

export type ApplicantVerificationStatus =
  | "DRAFT"
  | "SUBMITTED"
  | "ACCEPTED"
  | "REJECTED"

export type Gender = "M" | "F" | "O"

export type DestinationCountry = "MALAYSIA"

export type Religion =
  | "ISLAM"
  | "KRISTEN"
  | "KATHOLIK"
  | "HINDU"
  | "BUDHA"
  | "LAINNYA"

export type EducationLevel =
  | "SMP"
  | "SMA"
  | "SMK"
  | "MA"
  | "D3"
  | "S1"

export type WritingHand = "KANAN" | "KIRI"

export type MaritalStatus =
  | "BELUM MENIKAH"
  | "MENIKAH"
  | "CERAI HIDUP"
  | "CERAI MATI"

export type IndustryType =
  | "SEMICONDUCTOR"
  | "ELEKTRONIK"
  | "PABRIK LAIN"
  | "JASA"
  | "LAIN LAIN"
  | "BELUM PERNAH BEKERJA"

/** Region display from backend (village_display, family_village_display) */
export interface RegionDisplay {
  province?: string
  regency?: string
  district?: string
  village?: string
}

export interface ApplicantProfile {
  id: number
  referrer: number | null
  registration_date: string | null
  destination_country: DestinationCountry
  full_name: string
  birth_place: string
  birth_date: string | null
  address: string
  /** Province FK id (regions.Province) */
  province: number | null
  /** District/Regency FK id (regions.Regency - Kabupaten/Kota) */
  district: number | null
  /** Village FK id (regions.Village) */
  village: number | null
  village_display?: RegionDisplay | null
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
  family_province: number | null
  family_district: number | null
  family_village: number | null
  family_village_display?: RegionDisplay | null
  family_contact_phone: string
  data_declaration_confirmed: boolean
  zero_cost_understood: boolean
  nik: string
  gender: Gender
  religion: Religion
  education_level: EducationLevel
  education_major: string
  height_cm: number | null
  weight_kg: number | null
  wears_glasses: boolean | null
  writing_hand: WritingHand
  marital_status: MaritalStatus
  has_passport: boolean | null
  passport_number: string
  passport_issue_date: string | null
  passport_issue_place: string
  passport_expiry_date: string | null
  family_card_number: string
  diploma_number: string
  bpjs_number: string
  shoe_size: string
  shirt_size: string
  photo: string | null
  notes: string
  verification_status: ApplicantVerificationStatus
  submitted_at: string | null
  verified_at: string | null
  verified_by: number | null
  verification_notes: string
  created_at: string
  updated_at: string
  age?: number
  days_since_submission?: number
  is_passport_expired?: boolean
  document_approval_rate?: number
  has_complete_documents?: boolean
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
  location: string
  country: string
  industry_type: IndustryType
  position: string
  department: string
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
  location?: string
  country?: string
  industry_type?: string
  position?: string
  department?: string
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
  // Location filters (province/district are FK IDs)
  province?: number
  district?: number
  // Demographic filters
  religion?: string
  education_level?: string
  marital_status?: string
  work_country?: string
  // Reference filters
  referrer?: number
  // Date filters
  submitted_after?: string
  submitted_before?: string
  // Miscellaneous
  with_related?: boolean
}

export interface PaginatedResponse<T> {
  count: number
  next: string | null
  previous: string | null
  results: T[]
}
