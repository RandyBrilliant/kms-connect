/**
 * Admin user type - matches backend AdminUserSerializer.
 */

export interface AdminUser {
  id: number
  email: string
  full_name: string
  role: string
  is_active: boolean
  email_verified: boolean
  email_verified_at: string | null
  date_joined: string
  last_login: string | null
  updated_at: string
}

export interface AdminUserCreateInput {
  email: string
  full_name?: string
  password: string
  is_active?: boolean
  email_verified?: boolean
}

export interface AdminUserUpdateInput {
  email?: string
  full_name?: string
  password?: string
  is_active?: boolean
  email_verified?: boolean
}

export interface AdminsListParams {
  page?: number
  page_size?: number
  search?: string
  is_active?: boolean
  email_verified?: boolean
  ordering?: string
}

export interface PaginatedResponse<T> {
  count: number
  next: string | null
  previous: string | null
  results: T[]
}
