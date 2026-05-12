import type { ApplicantProfile } from "@/types/applicant"

/**
 * Default Disnaker: kabupaten/kota alamat KTP from API `village_display.regency`, uppercase.
 * Matches backend `ktp_kabupaten_kota_upper` when hierarchy is resolved from village/district FKs.
 */
export function defaultDisnakerFromApplicantProfile(
  profile: ApplicantProfile
): string {
  const raw = profile.village_display?.regency?.trim()
  return raw ? raw.toUpperCase() : ""
}
