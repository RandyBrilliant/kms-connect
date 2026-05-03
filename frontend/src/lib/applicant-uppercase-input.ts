import type { ChangeEvent } from "react"

/**
 * Biodata field names stored in UPPERCASE (parity with mobile), excluding email and numeric-heavy fields.
 */
export const APPLICANT_UPPERCASE_TEXT_FIELDS = new Set([
  "full_name",
  "birth_place_text",
  "address",
  "father_name",
  "father_occupation",
  "mother_name",
  "mother_occupation",
  "spouse_name",
  "spouse_occupation",
  "family_address",
  "heir_name",
  "notes",
  "education_major",
  "passport_number",
  "passport_issue_place",
  "diploma_number",
  "family_card_number",
])

export function handleApplicantUppercaseChange(
  fieldName: string,
  commit: (value: string) => void
): ((e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => void) | undefined {
  if (!APPLICANT_UPPERCASE_TEXT_FIELDS.has(fieldName)) return undefined
  return (e) => commit(e.target.value.toUpperCase())
}
