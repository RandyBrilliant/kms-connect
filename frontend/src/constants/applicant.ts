/**
 * Constants for applicant-related enums, labels, and formatting.
 * Centralized to avoid magic strings and maintain consistency.
 */

import type {
  ApplicantVerificationStatus,
  DocumentReviewStatus,
  Gender,
  Religion,
  EducationLevel,
  WritingHand,
  MaritalStatus,
  NextOfKinRelationship,
  IndustryType,
  DestinationCountry,
} from "@/types/applicant"

// ============================================================================
// Verification Status
// ============================================================================

export const VERIFICATION_STATUS_LABELS: Record<
  ApplicantVerificationStatus,
  string
> = {
  SUBMITTED: "Dikirim",
  ACCEPTED: "Diterima",
  REJECTED: "Ditolak",
} as const

export const VERIFICATION_STATUS_COLORS: Record<
  ApplicantVerificationStatus,
  "outline" | "secondary" | "default" | "destructive"
> = {
  SUBMITTED: "secondary",
  ACCEPTED: "default",
  REJECTED: "destructive",
} as const

export const VERIFICATION_STATUS_DESCRIPTIONS: Record<
  ApplicantVerificationStatus,
  string
> = {
  SUBMITTED: "Pelamar sudah mengirim data, menunggu review admin",
  ACCEPTED: "Data pelamar sudah diverifikasi dan diterima",
  REJECTED: "Data pelamar ditolak. Lihat catatan untuk detailnya",
} as const

// ============================================================================
// Document Review Status
// ============================================================================

export const DOCUMENT_REVIEW_STATUS_LABELS: Record<
  DocumentReviewStatus,
  string
> = {
  PENDING: "Menunggu Review",
  APPROVED: "Disetujui",
  REJECTED: "Ditolak",
} as const

export const DOCUMENT_REVIEW_STATUS_COLORS: Record<
  DocumentReviewStatus,
  "secondary" | "default" | "destructive"
> = {
  PENDING: "secondary",
  APPROVED: "default",
  REJECTED: "destructive",
} as const

// ============================================================================
// Gender
// ============================================================================

export const GENDER_LABELS: Record<Gender, string> = {
  M: "Laki-laki",
  F: "Perempuan",
} as const

// ============================================================================
// Religion
// ============================================================================

export const RELIGION_LABELS: Record<Religion, string> = {
  ISLAM: "Islam",
  KRISTEN: "Kristen",
  KATHOLIK: "Katholik",
  HINDU: "Hindu",
  BUDHA: "Budha",
  LAINNYA: "Lainnya",
} as const

// ============================================================================
// Education Level
// ============================================================================

export const EDUCATION_LEVEL_LABELS: Record<EducationLevel, string> = {
  SMP: "SMP",
  SMA: "SMA / Sederajat",
  SMK: "SMK",
  MA: "MA / Madrasah Aliyah",
  D3: "Diploma 3",
  S1: "Sarjana (S1)",
} as const

// ============================================================================
// Writing Hand
// ============================================================================

export const WRITING_HAND_LABELS: Record<WritingHand, string> = {
  KANAN: "Kanan",
  KIRI: "Kiri",
} as const

// ============================================================================
// Marital Status
// ============================================================================

export const MARITAL_STATUS_LABELS: Record<MaritalStatus, string> = {
  "BELUM MENIKAH": "Belum Menikah",
  MENIKAH: "Menikah",
  "CERAI HIDUP": "Cerai Hidup",
  "CERAI MATI": "Cerai Mati",
} as const

// ============================================================================
// Next of Kin / Ahli Waris Relationship
// ============================================================================

export const NEXT_OF_KIN_RELATIONSHIP_LABELS: Record<NextOfKinRelationship, string> = {
  SUAMI: "Suami",
  ISTRI: "Istri",
  AYAH: "Ayah",
  IBU: "Ibu",
  KAKAK: "Kakak",
  ADIK: "Adik",
  ANAK: "Anak",
  PAMAN: "Paman",
  BIBI: "Bibi",
  LAINNYA: "Lainnya",
} as const

export const NEXT_OF_KIN_RELATIONSHIP_OPTIONS = Object.entries(
  NEXT_OF_KIN_RELATIONSHIP_LABELS,
) as [NextOfKinRelationship, string][]

// ============================================================================
// Passport (has_passport is boolean | null)
// ============================================================================

export const HAS_PASSPORT_LABELS: Record<string, string> = {
  false: "Belum Ada",
  true: "Sudah Ada",
} as const

// ============================================================================
// Work Country (ISO 3166-1 alpha-2 codes from django-countries)
// ============================================================================

/** Common countries for work experience. Maps ISO code -> display name. */
export const COUNTRY_ISO_LABELS: Record<string, string> = {
  ID: "Indonesia",
  MY: "Malaysia",
  SG: "Singapore",
  SA: "Saudi Arabia",
  TW: "Taiwan",
  HK: "Hong Kong",
  JP: "Japan",
  KR: "South Korea",
  AE: "United Arab Emirates",
  QA: "Qatar",
} as const

export const WORK_COUNTRY_OPTIONS = Object.entries(COUNTRY_ISO_LABELS) as [
  string,
  string,
][]

// ============================================================================
// Industry Type
// ============================================================================

export const INDUSTRY_TYPE_LABELS: Record<IndustryType, string> = {
  SEMICONDUCTOR: "Semiconductor",
  ELEKTRONIK: "Elektronik",
  "PABRIK LAIN": "Pabrik Lain",
  JASA: "Jasa",
  "LAIN LAIN": "Lain-lain",
  "BELUM PERNAH BEKERJA": "Belum Pernah Bekerja",
} as const

// ============================================================================
// Destination Country
// ============================================================================

export const DESTINATION_COUNTRY_LABELS: Record<DestinationCountry, string> = {
  MALAYSIA: "Malaysia",
} as const

// ============================================================================
// Helper Functions
// ============================================================================

export function getVerificationStatusLabel(
  status: ApplicantVerificationStatus
): string {
  return VERIFICATION_STATUS_LABELS[status] || status
}

export function getVerificationStatusColor(
  status: ApplicantVerificationStatus
): "outline" | "secondary" | "default" | "destructive" {
  return VERIFICATION_STATUS_COLORS[status] || "outline"
}

export function getDocumentReviewStatusLabel(
  status: DocumentReviewStatus
): string {
  return DOCUMENT_REVIEW_STATUS_LABELS[status] || status
}

export function getDocumentReviewStatusColor(
  status: DocumentReviewStatus
): "secondary" | "default" | "destructive" {
  return DOCUMENT_REVIEW_STATUS_COLORS[status] || "secondary"
}

export function getGenderLabel(gender: Gender): string {
  return GENDER_LABELS[gender] || gender
}

export function getReligionLabel(religion: Religion): string {
  return RELIGION_LABELS[religion] || religion
}

export function getEducationLevelLabel(level: EducationLevel): string {
  return EDUCATION_LEVEL_LABELS[level] || level
}

export function getWritingHandLabel(hand: WritingHand): string {
  return WRITING_HAND_LABELS[hand] || hand
}

export function getMaritalStatusLabel(status: MaritalStatus): string {
  return MARITAL_STATUS_LABELS[status] || status
}

export function getHasPassportLabel(hasPassport: boolean | null | undefined): string {
  if (hasPassport === null || hasPassport === undefined) return "-"
  return HAS_PASSPORT_LABELS[String(hasPassport)] ?? "-"
}

/** Get display name for ISO country code (e.g. ID -> Indonesia). */
export function getCountryLabel(countryCode: string | null | undefined): string {
  if (!countryCode) return ""
  return COUNTRY_ISO_LABELS[countryCode] || countryCode
}

export function getIndustryTypeLabel(type: IndustryType): string {
  return INDUSTRY_TYPE_LABELS[type] || type
}

export function getNextOfKinRelationshipLabel(
  rel: NextOfKinRelationship | string,
): string {
  return NEXT_OF_KIN_RELATIONSHIP_LABELS[rel as NextOfKinRelationship] || rel
}

// ============================================================================
// Bank (Data Rekening PMI) — keep in sync with backend IndonesianBank
// ============================================================================

export const INDONESIAN_BANKS: readonly { value: string; label: string }[] = [
  { value: "BRI", label: "Bank Rakyat Indonesia (BRI)" },
  { value: "BNI", label: "Bank Negara Indonesia (BNI)" },
  { value: "MANDIRI", label: "Bank Mandiri" },
  { value: "BTN", label: "Bank Tabungan Negara (BTN)" },
  { value: "BSI", label: "Bank Syariah Indonesia (BSI)" },
  { value: "BCA", label: "Bank Central Asia (BCA)" },
  { value: "CIMB_NIAGA", label: "Bank CIMB Niaga" },
  { value: "DANAMON", label: "Bank Danamon" },
  { value: "PERMATA", label: "Bank Permata" },
  { value: "PANIN", label: "Panin Bank" },
  { value: "MAYBANK", label: "Maybank Indonesia" },
  { value: "OCBC", label: "Bank OCBC Indonesia (OCBC NISP)" },
  { value: "SMBC", label: "Bank SMBC Indonesia (d/h BTPN / Jenius)" },
  { value: "MEGA", label: "Bank Mega" },
  { value: "SINARMAS", label: "Bank Sinarmas" },
  { value: "KB_BANK", label: "KB Bank (d/h Bukopin)" },
  { value: "MUAMALAT", label: "Bank Muamalat" },
  { value: "BCA_SYARIAH", label: "BCA Syariah" },
  { value: "BANK_RAYA", label: "Bank Raya" },
  { value: "MAYAPADA", label: "Bank Mayapada" },
  { value: "ARTHA_GRAHA", label: "Bank Artha Graha" },
  { value: "MNC", label: "Bank MNC Internasional" },
  { value: "SAMPOERNA", label: "Bank Sahabat Sampoerna" },
  { value: "UOB", label: "UOB Indonesia" },
  { value: "HSBC", label: "HSBC Indonesia" },
  { value: "DBS", label: "DBS Indonesia" },
  { value: "CCB", label: "China Construction Bank Indonesia" },
  { value: "ICBC", label: "ICBC Indonesia" },
  { value: "JAGO", label: "Bank Jago" },
  { value: "SEABANK", label: "SeaBank Indonesia" },
  { value: "BLU", label: "BCA Digital (blu)" },
  { value: "NEO", label: "Bank Neo Commerce" },
  { value: "ALLO", label: "Allo Bank" },
  { value: "SUMUT", label: "Bank Sumut" },
  { value: "ACEH", label: "Bank Aceh Syariah" },
  { value: "NAGARI", label: "Bank Nagari" },
  { value: "BRK_SYARIAH", label: "BRK Syariah (Riau Kepri)" },
  { value: "JAMBI", label: "Bank Jambi" },
  { value: "SUMSEL_BABEL", label: "Bank Sumsel Babel" },
  { value: "BENGKULU", label: "Bank Bengkulu" },
  { value: "LAMPUNG", label: "Bank Lampung" },
  { value: "DKI", label: "Bank DKI" },
  { value: "BJB", label: "Bank BJB" },
  { value: "BANTEN", label: "Bank Banten" },
  { value: "JATENG", label: "Bank Jateng" },
  { value: "BPD_DIY", label: "BPD DIY" },
  { value: "JATIM", label: "Bank Jatim" },
  { value: "BPD_BALI", label: "Bank BPD Bali" },
  { value: "NTB_SYARIAH", label: "Bank NTB Syariah" },
  { value: "NTT", label: "Bank NTT" },
  { value: "KALBAR", label: "Bank Kalbar" },
  { value: "KALTENG", label: "Bank Kalteng" },
  { value: "KALSEL", label: "Bank Kalsel" },
  { value: "KALTIMTARA", label: "Bank Kaltimtara" },
  { value: "SULSELBAR", label: "Bank Sulselbar" },
  { value: "SULTENG", label: "Bank Sulteng" },
  { value: "SULTRA", label: "Bank Sultra" },
  { value: "SULUTGO", label: "Bank SulutGo" },
  { value: "MALUKU_MALUT", label: "Bank Maluku Malut" },
  { value: "PAPUA", label: "Bank Papua" },
] as const

/** Bank code → display name; unknown legacy free-text values are returned as-is. */
export function bankLabel(code: string | null | undefined): string {
  if (!code) return ""
  return INDONESIAN_BANKS.find((b) => b.value === code)?.label ?? code
}
