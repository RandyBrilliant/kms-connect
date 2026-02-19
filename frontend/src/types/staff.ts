/**
 * Staff user type - matches backend StaffUserSerializer.
 */

export interface StaffProfile {
  id: number
  full_name: string
  contact_phone: string
  photo: string | null
  created_at: string
  updated_at: string
}

export interface StaffUser {
  id: number
  email: string
  role: string
  is_active: boolean
  email_verified: boolean
  email_verified_at: string | null
  date_joined: string
  last_login: string | null
  updated_at: string
  referral_code: string | null
  google_id: string | null
  staff_profile: StaffProfile
}

export interface StaffUserCreateInput {
  email: string
  password: string
  staff_profile: {
    full_name: string
    contact_phone?: string
    photo?: string | null
  }
  is_active?: boolean
  email_verified?: boolean
}

export interface StaffUserUpdateInput {
  email?: string
  password?: string
  staff_profile?: {
    full_name?: string
    contact_phone?: string
    photo?: string | null
  }
  is_active?: boolean
  email_verified?: boolean
}

export interface StaffsListParams {
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
