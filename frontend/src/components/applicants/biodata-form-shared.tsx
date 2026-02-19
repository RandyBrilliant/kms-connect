/**
 * Shared UI for biodata forms: required indicator and section headings.
 * Used by both ApplicantForm (create) and ApplicantBiodataTab (edit).
 */

import { BIODATA_SECTIONS, isRequiredBiodata, isRequiredOnCreate } from "@/constants/biodata-form"

export function RequiredStar({ field }: { field: string }) {
  if (!isRequiredBiodata(field) && !isRequiredOnCreate(field)) return null
  return <span className="text-destructive">*</span>
}

export function SectionTitle({ section }: { section: keyof typeof BIODATA_SECTIONS }) {
  const { title, description } = BIODATA_SECTIONS[section]
  return (
    <>
      <h3 className="text-lg font-semibold">{title}</h3>
      {description && (
        <p className="text-muted-foreground text-sm">{description}</p>
      )}
    </>
  )
}

export { BIODATA_SECTIONS, isRequiredBiodata, isRequiredOnCreate }
