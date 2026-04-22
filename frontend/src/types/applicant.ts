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

export type NextOfKinRelationship =
  | "SUAMI"
  | "ISTRI"
  | "AYAH"
  | "IBU"
  | "KAKAK"
  | "ADIK"
  | "ANAK"
  | "PAMAN"
  | "BIBI"
  | "LAINNYA"

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

export interface ScoreBreakdown {
  score: number
  profile_completeness_ratio: number
  document_ratio: number
  profile_missing_fields: string[]
  missing_required_document_codes: string[]
}

/** Staff pemberi rujukan (embedded in profile JSON). */
export interface ApplicantReferrerDisplay {
  id: number
  /** Nama di DB (boleh kosong). */
  full_name: string
  /** Nama untuk UI: full_name atau turunan dari bagian lokal email (bukan kode rujukan). */
  display_name?: string
  email: string
  referral_code: string | null
}

export interface ApplicantProfile {
  id: number
  register_number: string | null
  referrer: number | null
  /** Resolved staff rujukan for display (read-only from API). */
  referrer_display?: ApplicantReferrerDisplay | null
  registration_date: string | null
  destination_country: DestinationCountry
  full_name: string
  birth_place: number | null
  birth_place_display?: string | null
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
  father_phone: string
  /** Ayah kandung sudah meninggal */
  father_almarhum?: boolean
  mother_name: string
  mother_age: number | null
  mother_occupation: string
  mother_phone: string
  /** Ibu kandung sudah meninggal (Almarhumah) */
  mother_almarhum?: boolean
  spouse_name: string
  spouse_age: number | null
  spouse_occupation: string
  /** Pasangan (suami/istri) sudah meninggal */
  spouse_almarhum?: boolean
  family_address: string
  family_province: number | null
  family_district: number | null
  family_village: number | null
  family_village_display?: RegionDisplay | null
  heir_name: string
  heir_relationship: NextOfKinRelationship | ""
  heir_relationship_display?: string
  heir_contact_phone: string
  data_declaration_confirmed: boolean
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
  tgl_medical: string | null
  hasil_medical: string
  tgl_bayar_sml: string | null
  tgl_fwcm_psikotes: string | null
  tgl_bayar_psikotes: string | null
  tgl_bayar_bpjs_pra: string | null
  tgl_bayar_bpjs_purna: string | null
  no_id_sisko: string
  disnaker: string
  no_sip: string
  no_jo: string
  biaya_ready_paspor: number | null
  pengembalian_biaya: number | null
  tgl_pengembalian: string | null
  jlh_uang_transport: number | null
  bank: string
  no_rek: string
  tanggal_pengembalian: string | null
  tgl_kirim_bio_ke_mly: string | null
  tgl_calling_visa: string | null
  no_calling_visa: string
  shoe_size: string
  shirt_size: string
  photo: string | null
  notes: string
  verification_status: ApplicantVerificationStatus
  submitted_at: string | null
  verified_at: string | null
  verified_by: number | null
  verification_notes: string
  score: number | null
  score_breakdown?: ScoreBreakdown | null
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
  /** Google OAuth subject (`sub`); absent or null if not linked */
  google_id?: string | null
  /** Apple Sign-In subject; absent or null if not linked */
  apple_id?: string | null
  applicant_profile: ApplicantProfile
}

export interface ApplicantUserCreateInput {
  email: string
  password: string
  /** Nama lengkap (CustomUser); can be sent at top level and/or in applicant_profile */
  full_name: string
  applicant_profile: {
    full_name: string
    nik: string
    birth_place?: number | null
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

export type DocumentPhase = "INITIAL" | "POST_INTERVIEW"

export interface DocumentType {
  id: number
  code: string
  name: string
  is_required: boolean
  sort_order: number
  description: string
  phase: DocumentPhase
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
  /** Filter by staff referrer user id (GET ?referrer=) */
  referrer?: number
  created_at_after?: string // Date string (YYYY-MM-DD) for filtering applicants who joined on or after this date
  created_at_before?: string // Date string (YYYY-MM-DD) for filtering applicants who joined on or before this date
  ordering?: string // e.g., "applicant_profile__score", "-applicant_profile__score", "applicant_profile__created_at", etc.
}

export interface PaginatedResponse<T> {
  count: number
  next: string | null
  previous: string | null
  results: T[]
}
