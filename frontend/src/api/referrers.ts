/**
 * Referrers API - Staff + Admin users for pemberi rujukan dropdown.
 * Backend: GET /api/referrers/
 */

import { api } from "@/lib/api"

export interface ReferrerItem {
  id: number
  full_name: string
  email: string
  referral_code: string | null
}

/** GET /api/referrers/ - List Staff and Admin users for referrer dropdown */
export async function getReferrers(): Promise<ReferrerItem[]> {
  const { data } = await api.get<ReferrerItem[] | { results: ReferrerItem[] }>(
    "/api/referrers/"
  )
  return Array.isArray(data) ? data : data?.results ?? []
}
