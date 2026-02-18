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
  DRAFT: "Draf",
  SUBMITTED: "Dikirim",
  ACCEPTED: "Diterima",
  REJECTED: "Ditolak",
} as const

export const VERIFICATION_STATUS_COLORS: Record<
  ApplicantVerificationStatus,
  "outline" | "secondary" | "default" | "destructive"
> = {
  DRAFT: "outline",
  SUBMITTED: "secondary",
  ACCEPTED: "default",
  REJECTED: "destructive",
} as const

export const VERIFICATION_STATUS_DESCRIPTIONS: Record<
  ApplicantVerificationStatus,
  string
> = {
  DRAFT: "Pelamar sedang mengisi data, belum mengirim untuk verifikasi",
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
  O: "Lainnya",
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
