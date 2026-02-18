/**
 * Type guard utilities for runtime type checking.
 * Provides type-safe narrowing for TypeScript.
 */

import type {
  ApplicantProfile,
  ApplicantVerificationStatus,
  WorkExperience,
  ApplicantDocument,
  Religion,
  EducationLevel,
  WritingHand,
  MaritalStatus,
  IndustryType,
  Gender,
} from "@/types/applicant"

// ============================================================================
// Basic Type Guards
// ============================================================================

/**
 * Check if value is not null or undefined
 */
export function isDefined<T>(value: T | null | undefined): value is T {
  return value !== null && value !== undefined
}

/**
 * Check if value is a non-empty string
 */
export function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim() !== ""
}

/**
 * Check if value is a valid number (not NaN or Infinity)
 */
export function isValidNumber(value: unknown): value is number {
  return typeof value === "number" && isFinite(value)
}

// ============================================================================
// Enum Type Guards
// ============================================================================

/**
 * Check if value is a valid ApplicantVerificationStatus
 */
export function isVerificationStatus(
  value: unknown
): value is ApplicantVerificationStatus {
  return (
    typeof value === "string" &&
    ["DRAFT", "SUBMITTED", "ACCEPTED", "REJECTED"].includes(value)
  )
}

/**
 * Check if value is a valid Gender
 */
export function isGender(value: unknown): value is Gender {
  return typeof value === "string" && ["L", "P"].includes(value)
}

/**
 * Check if value is a valid Religion
 */
export function isReligion(value: unknown): value is Religion {
  return (
    typeof value === "string" &&
    [
      "ISLAM",
      "KRISTEN",
      "KATOLIK",
      "HINDU",
      "BUDDHA",
      "KONGHUCU",
      "LAINNYA",
    ].includes(value)
  )
}

/**
 * Check if value is a valid EducationLevel
 */
export function isEducationLevel(value: unknown): value is EducationLevel {
  return (
    typeof value === "string" &&
    ["SD", "SMP", "SMA", "D3", "S1", "S2", "S3"].includes(value)
  )
}

/**
 * Check if value is a valid WritingHand
 */
export function isWritingHand(value: unknown): value is WritingHand {
  return typeof value === "string" && ["KANAN", "KIRI"].includes(value)
}

/**
 * Check if value is a valid MaritalStatus
 */
export function isMaritalStatus(value: unknown): value is MaritalStatus {
  return (
    typeof value === "string" &&
    ["BELUM_KAWIN", "KAWIN", "CERAI_HIDUP", "CERAI_MATI"].includes(value)
  )
}

/**
 * Check if value is a valid ISO 3166-1 alpha-2 country code (e.g. ID, MY) or empty
 */
export function isCountryCode(value: unknown): value is string {
  return (
    typeof value === "string" &&
    (value === "" || /^[A-Z]{2}$/.test(value))
  )
}

/**
 * Check if value is a valid IndustryType
 */
export function isIndustryType(value: unknown): value is IndustryType {
  return (
    typeof value === "string" &&
    [
      "MANUFAKTUR",
      "KONSTRUKSI",
      "PERTANIAN",
      "PERIKANAN",
      "PERHOTELAN",
      "RUMAH_TANGGA",
      "PERAWATAN",
      "TEKNOLOGI",
      "LAINNYA",
    ].includes(value)
  )
}

// ============================================================================
// Object Type Guards
// ============================================================================

/**
 * Check if object is an ApplicantProfile (basic check)
 */
export function isApplicantProfile(obj: unknown): obj is ApplicantProfile {
  if (!obj || typeof obj !== "object") return false

  const profile = obj as Partial<ApplicantProfile>

  return (
    typeof profile.id === "number" &&
    isNonEmptyString(profile.full_name)
  )
}

/**
 * Check if object is a WorkExperience (basic check)
 */
export function isWorkExperience(obj: unknown): obj is WorkExperience {
  if (!obj || typeof obj !== "object") return false

  const work = obj as Partial<WorkExperience>

  return (
    typeof work.id === "number" &&
    isNonEmptyString(work.position)
  )
}

/**
 * Check if object is an ApplicantDocument (basic check)
 */
export function isApplicantDocument(obj: unknown): obj is ApplicantDocument {
  if (!obj || typeof obj !== "object") return false

  const doc = obj as Partial<ApplicantDocument>

  return (
    typeof doc.id === "number" &&
    typeof doc.document_type === "number"
  )
}

// ============================================================================
// Status Check Helpers
// ============================================================================

/**
 * Check if applicant is in draft status
 */
export function isDraftStatus(
  status: ApplicantVerificationStatus | string
): boolean {
  return status === "DRAFT"
}

/**
 * Check if applicant is submitted (pending review)
 */
export function isSubmittedStatus(
  status: ApplicantVerificationStatus | string
): boolean {
  return status === "SUBMITTED"
}

/**
 * Check if applicant is accepted
 */
export function isAcceptedStatus(
  status: ApplicantVerificationStatus | string
): boolean {
  return status === "ACCEPTED"
}

/**
 * Check if applicant is rejected
 */
export function isRejectedStatus(
  status: ApplicantVerificationStatus | string
): boolean {
  return status === "REJECTED"
}

/**
 * Check if status can be edited (DRAFT or REJECTED)
 */
export function isEditableStatus(
  status: ApplicantVerificationStatus | string
): boolean {
  return status === "DRAFT" || status === "REJECTED"
}

/**
 * Check if status requires admin action (SUBMITTED)
 */
export function requiresAdminAction(
  status: ApplicantVerificationStatus | string
): boolean {
  return status === "SUBMITTED"
}

// ============================================================================
// Completeness Checks
// ============================================================================

/**
 * Check if applicant has complete biodata
 */
export function hasCompleteBiodata(profile: ApplicantProfile): boolean {
  return !!(
    profile.full_name &&
    profile.nik &&
    profile.birth_place &&
    profile.birth_date &&
    profile.gender &&
    profile.religion &&
    profile.marital_status &&
    profile.education_level &&
    profile.contact_phone &&
    profile.address &&
    profile.district &&
    profile.province
  )
}

/**
 * Check if applicant has valid passport
 */
export function hasValidPassport(profile: ApplicantProfile): boolean {
  if (!profile.passport_number || !profile.passport_expiry_date) {
    return false
  }

  // Check if passport is not expired
  const expiryDate = new Date(profile.passport_expiry_date)
  return expiryDate > new Date()
}

/**
 * Check if applicant can submit for verification
 */
export function canSubmitForVerification(profile: ApplicantProfile): boolean {
  // Must be in DRAFT or REJECTED status
  if (!isEditableStatus(profile.verification_status)) {
    return false
  }

  // Must have complete biodata
  if (!hasCompleteBiodata(profile)) {
    return false
  }

  // Must have valid passport
  if (!hasValidPassport(profile)) {
    return false
  }

  return true
}

// ============================================================================
// Document Checks
// ============================================================================

/**
 * Check if document is an image
 */
export function isImageDocument(document: ApplicantDocument): boolean {
  if (!document.file) return false

  const imageExtensions = [".jpg", ".jpeg", ".png"]
  return imageExtensions.some((ext) => document.file.toLowerCase().endsWith(ext))
}

/**
 * Check if document is a PDF
 */
export function isPDFDocument(document: ApplicantDocument): boolean {
  if (!document.file) return false
  return document.file.toLowerCase().endsWith(".pdf")
}

/**
 * Check if document needs review
 */
export function documentNeedsReview(document: ApplicantDocument): boolean {
  return (
    document.review_status === "PENDING" || document.review_status === null
  )
}

/**
 * Check if document is approved
 */
export function isDocumentApproved(document: ApplicantDocument): boolean {
  return document.review_status === "APPROVED"
}

/**
 * Check if document is rejected
 */
export function isDocumentRejected(document: ApplicantDocument): boolean {
  return document.review_status === "REJECTED"
}

// ============================================================================
// Array Filtering Helpers
// ============================================================================

/**
 * Filter out null/undefined values from array with type safety
 */
export function filterDefined<T>(array: (T | null | undefined)[]): T[] {
  return array.filter(isDefined)
}

/**
 * Filter applicants by status
 */
export function filterByStatus(
  applicants: ApplicantProfile[],
  status: ApplicantVerificationStatus
): ApplicantProfile[] {
  return applicants.filter((a) => a.verification_status === status)
}

/**
 * Filter documents that need review
 */
export function filterDocumentsNeedingReview(
  documents: ApplicantDocument[]
): ApplicantDocument[] {
  return documents.filter(documentNeedsReview)
}

// ============================================================================
// Permission Checks
// ============================================================================

/**
 * Check if user can edit applicant profile
 * Note: Ownership check requires connection to user data
 */
export function canEditProfile(
  profile: ApplicantProfile
): boolean {
  // Profile must be in editable status
  return isEditableStatus(profile.verification_status)
}

/**
 * Check if user can delete document
 * Note: Ownership check requires connection to user data
 */
export function canDeleteDocument(
  document: ApplicantDocument,
  profile: ApplicantProfile
): boolean {
  // Profile must be in editable status
  if (!isEditableStatus(profile.verification_status)) {
    return false
  }

  // Document must not be approved
  return !isDocumentApproved(document)
}
