/**
 * Company users API - CRUD for Company role users.
 * Backend: /api/companies/
 */

import { api } from "@/lib/api"
import type {
  CompanyUser,
  CompanyUserCreateInput,
  CompanyUserUpdateInput,
  CompaniesListParams,
  PaginatedResponse,
} from "@/types/company"

function buildQueryString(params: CompaniesListParams): string {
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

/** GET /api/companies/ - List with pagination, search, filter */
export async function getCompanies(
  params: CompaniesListParams = {}
): Promise<PaginatedResponse<CompanyUser>> {
  const { data } = await api.get<PaginatedResponse<CompanyUser>>(
    `/api/companies/${buildQueryString(params)}`
  )
  return data
}

/** GET /api/companies/:id/ - Retrieve single company user */
export async function getCompany(id: number): Promise<CompanyUser> {
  const { data } = await api.get<CompanyUser>(`/api/companies/${id}/`)
  return data
}

/** POST /api/companies/ - Create company user */
export async function createCompany(
  input: CompanyUserCreateInput
): Promise<CompanyUser> {
  const { data } = await api.post<CompanyUser>("/api/companies/", input)
  return data
}

/** PUT /api/companies/:id/ - Full update */
export async function updateCompany(
  id: number,
  input: CompanyUserUpdateInput
): Promise<CompanyUser> {
  const { data } = await api.put<CompanyUser>(`/api/companies/${id}/`, input)
  return data
}

/** PATCH /api/companies/:id/ - Partial update */
export async function patchCompany(
  id: number,
  input: Partial<CompanyUserUpdateInput>
): Promise<CompanyUser> {
  const { data } = await api.patch<CompanyUser>(`/api/companies/${id}/`, input)
  return data
}

/** POST /api/companies/:id/deactivate/ */
export async function deactivateCompany(id: number): Promise<CompanyUser> {
  const { data } = await api.post<{ data: CompanyUser }>(
    `/api/companies/${id}/deactivate/`
  )
  return data.data
}

/** POST /api/companies/:id/activate/ */
export async function activateCompany(id: number): Promise<CompanyUser> {
  const { data } = await api.post<{ data: CompanyUser }>(
    `/api/companies/${id}/activate/`
  )
  return data.data
}

/**
 * Email helpers for company users.
 * Backend email endpoints are generic admin tools that accept any user_id.
 */

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


