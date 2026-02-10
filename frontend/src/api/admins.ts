/**
 * Admin users API - CRUD for Admin role users.
 * Backend: /api/admins/
 */

import { api } from "@/lib/api"
import type {
  AdminUser,
  AdminUserCreateInput,
  AdminUserUpdateInput,
  AdminsListParams,
  PaginatedResponse,
} from "@/types/admin"

function buildQueryString(params: AdminsListParams): string {
  const search = new URLSearchParams()
  if (params.page != null) search.set("page", String(params.page))
  if (params.page_size != null) search.set("page_size", String(params.page_size))
  if (params.search) search.set("search", params.search)
  if (params.is_active != null) search.set("is_active", String(params.is_active))
  if (params.email_verified != null)
    search.set("email_verified", String(params.email_verified))
  if (params.ordering) search.set("ordering", params.ordering)
  const qs = search.toString()
  return qs ? `?${qs}` : ""
}

/** GET /api/admins/ - List with pagination, search, filter */
export async function getAdmins(
  params: AdminsListParams = {}
): Promise<PaginatedResponse<AdminUser>> {
  const { data } = await api.get<PaginatedResponse<AdminUser>>(
    `/api/admins/${buildQueryString(params)}`
  )
  return data
}

/** GET /api/admins/:id/ - Retrieve single admin */
export async function getAdmin(id: number): Promise<AdminUser> {
  const { data } = await api.get<AdminUser>(`/api/admins/${id}/`)
  return data
}

/** POST /api/admins/ - Create admin */
export async function createAdmin(
  input: AdminUserCreateInput
): Promise<AdminUser> {
  const { data } = await api.post<AdminUser>("/api/admins/", input)
  return data
}

/** PUT /api/admins/:id/ - Full update */
export async function updateAdmin(
  id: number,
  input: AdminUserUpdateInput
): Promise<AdminUser> {
  const { data } = await api.put<AdminUser>(`/api/admins/${id}/`, input)
  return data
}

/** PATCH /api/admins/:id/ - Partial update */
export async function patchAdmin(
  id: number,
  input: Partial<AdminUserUpdateInput>
): Promise<AdminUser> {
  const { data } = await api.patch<AdminUser>(`/api/admins/${id}/`, input)
  return data
}

/** POST /api/admins/:id/deactivate/ */
export async function deactivateAdmin(id: number): Promise<AdminUser> {
  const { data } = await api.post<{ data: AdminUser }>(
    `/api/admins/${id}/deactivate/`
  )
  return data.data
}

/** POST /api/admins/:id/activate/ */
export async function activateAdmin(id: number): Promise<AdminUser> {
  const { data } = await api.post<{ data: AdminUser }>(
    `/api/admins/${id}/activate/`
  )
  return data.data
}

/** POST /api/admins/send-verification-email/ - Admin sends verification email to user */
export async function sendVerificationEmail(userId: number): Promise<{ user_id: number; email: string }> {
  const { data } = await api.post<{ data: { user_id: number; email: string } }>(
    "/api/admins/send-verification-email/",
    { user_id: userId }
  )
  return data.data
}

/** POST /api/admins/send-password-reset/ - Admin sends password reset email to user */
export async function sendPasswordResetEmail(userId: number): Promise<{ user_id: number; email: string }> {
  const { data } = await api.post<{ data: { user_id: number; email: string } }>(
    "/api/admins/send-password-reset/",
    { user_id: userId }
  )
  return data.data
}
