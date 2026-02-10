/**
 * Staff users API - CRUD for Staff role users.
 * Backend: /api/staff/
 */

import { api } from "@/lib/api"
import type {
    StaffUser,
    StaffUserCreateInput,
    StaffUserUpdateInput,
    StaffsListParams,
    PaginatedResponse,
} from "@/types/staff"

function buildQueryString(params: StaffsListParams): string {
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

/** GET /api/staff/ - List with pagination, search, filter */
export async function getStaffs(
    params: StaffsListParams = {}
): Promise<PaginatedResponse<StaffUser>> {
    const { data } = await api.get<PaginatedResponse<StaffUser>>(
        `/api/staff/${buildQueryString(params)}`
    )
    return data
}

/** GET /api/staff/:id/ - Retrieve single staff */
export async function getStaff(id: number): Promise<StaffUser> {
    const { data } = await api.get<StaffUser>(`/api/staff/${id}/`)
    return data
}

/** POST /api/staff/ - Create staff */
export async function createStaff(
    input: StaffUserCreateInput
): Promise<StaffUser> {
    const { data } = await api.post<StaffUser>("/api/staff/", input)
    return data
}

/** PUT /api/staff/:id/ - Full update */
export async function updateStaff(
    id: number,
    input: StaffUserUpdateInput
): Promise<StaffUser> {
    const { data } = await api.put<StaffUser>(`/api/staff/${id}/`, input)
    return data
}

/** PATCH /api/staff/:id/ - Partial update */
export async function patchStaff(
    id: number,
    input: Partial<StaffUserUpdateInput>
): Promise<StaffUser> {
    const { data } = await api.patch<StaffUser>(`/api/staff/${id}/`, input)
    return data
}

/** POST /api/staff/:id/deactivate/ */
export async function deactivateStaff(id: number): Promise<StaffUser> {
    const { data } = await api.post<{ data: StaffUser }>(
        `/api/staff/${id}/deactivate/`
    )
    return data.data
}

/** POST /api/staff/:id/activate/ */
export async function activateStaff(id: number): Promise<StaffUser> {
    const { data } = await api.post<{ data: StaffUser }>(
        `/api/staff/${id}/activate/`
    )
    return data.data
}

/** POST /api/staff/send-verification-email/ - Admin sends verification email to user */
export async function sendVerificationEmail(userId: number): Promise<{ user_id: number; email: string }> {
    const { data } = await api.post<{ data: { user_id: number; email: string } }>(
        "/api/staff/send-verification-email/",
        { user_id: userId }
    )
    return data.data
}

/** POST /api/staff/send-password-reset/ - Admin sends password reset email to user */
export async function sendPasswordResetEmail(userId: number): Promise<{ user_id: number; email: string }> {
    const { data } = await api.post<{ data: { user_id: number; email: string } }>(
        "/api/staff/send-password-reset/",
        { user_id: userId }
    )
    return data.data
}
