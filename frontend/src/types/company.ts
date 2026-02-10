/**
 * Company user type - matches backend CompanyUserSerializer.
 */

export interface CompanyProfile {
  id: number
  company_name: string
  contact_phone: string
  address: string
  created_at: string
  updated_at: string
}

export interface CompanyUser {
  id: number
  email: string
  role: string
  is_active: boolean
  email_verified: boolean
  email_verified_at: string | null
  date_joined: string
  updated_at: string
  company_profile: CompanyProfile | null
}

export interface CompanyUserCreateInput {
  email: string
  password: string
  company_profile: {
    company_name: string
    contact_phone?: string
    address?: string
  }
  is_active?: boolean
  email_verified?: boolean
}

export interface CompanyUserUpdateInput {
  email?: string
  password?: string
  company_profile?: {
    company_name?: string
    contact_phone?: string
    address?: string
  }
  is_active?: boolean
  email_verified?: boolean
}

export interface CompaniesListParams {
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

