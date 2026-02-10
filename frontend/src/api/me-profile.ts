import { api } from "@/lib/api"
import type { ApiSuccessResponse } from "@/types/api"
import type { AdminUser } from "@/types/admin"
import type { StaffUser } from "@/types/staff"
import type { CompanyUser } from "@/types/company"

export type MeProfile = AdminUser | StaffUser | CompanyUser

/** GET /api/me/ - current user's full profile */
export async function getMyProfile(): Promise<MeProfile> {
  const { data } = await api.get<ApiSuccessResponse<MeProfile>>("/api/me/")
  if (!data.data) {
    throw new Error("Profil tidak ditemukan")
  }
  return data.data
}

/** PATCH /api/me/ - update current user's profile */
export async function updateMyProfile(
  payload: Partial<MeProfile>
): Promise<MeProfile> {
  const { data } = await api.patch<ApiSuccessResponse<MeProfile>>(
    "/api/me/",
    payload
  )
  if (!data.data) {
    throw new Error("Gagal memperbarui profil")
  }
  return data.data
}

