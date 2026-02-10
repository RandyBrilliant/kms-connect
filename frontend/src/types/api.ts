/**
 * Backend API response shapes.
 * Matches account.api_responses success_response / error_response.
 */

/** Success response wrapper */
export interface ApiSuccessResponse<T = unknown> {
  code: string
  detail?: string
  data?: T
}

/** Error response wrapper */
export interface ApiErrorResponse {
  code: string
  detail: string
  errors?: Record<string, string[]>
}

/** Login success data */
export interface LoginResponseData {
  user: {
    id: number
    email: string
    role: string
    is_active: boolean
    email_verified: boolean
  }
}
