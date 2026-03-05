import { api } from "@/lib/api"
import type { User } from "@/types/auth"
import type { ApiSuccessResponse, LoginResponseData } from "@/types/api"

export interface LoginCredentials {
  email: string
  password: string
}

/** POST /api/auth/token/ - Returns user + sets HTTP-only cookies */
export async function login(credentials: LoginCredentials): Promise<User> {
  const { data } = await api.post<ApiSuccessResponse<LoginResponseData>>(
    "/api/auth/token/",
    credentials
  )
  if (!data.data?.user) {
    throw new Error("Invalid response from server")
  }
  return data.data.user as User
}

/** POST /api/auth/token/refresh/ - Refresh access token (uses HTTP-only refresh cookie) */
export async function refreshToken(): Promise<void> {
  await api.post("/api/auth/token/refresh/")
}

/** POST /api/auth/logout/ - Clears auth cookies */
export async function logout(): Promise<void> {
  await api.post("/api/auth/logout/")
}

/** POST /api/auth/request-password-reset/ - Request password reset email (public) */
export async function requestPasswordReset(email: string): Promise<void> {
  await api.post("/api/auth/request-password-reset/", { email })
}

/** POST /api/auth/resend-verification-email/ - Resend verification email (public) */
export async function resendVerificationEmail(email: string): Promise<void> {
  await api.post("/api/auth/resend-verification-email/", { email })
}

/** POST /api/auth/verify-email-code/ - Verify email with 6-digit code */
export async function verifyEmailCode(
  email: string,
  code: string,
): Promise<ApiSuccessResponse<{ email: string }>> {
  const { data } = await api.post<ApiSuccessResponse<{ email: string }>>(
    "/api/auth/verify-email-code/",
    { email, code },
  )
  return data
}

/**
 * POST /api/auth/confirm-reset-password/ - Confirm password reset with uid + token.
 * Payload: { uid: string, token: string, new_password: string }
 */
export async function confirmResetPassword(input: {
  uid: string
  token: string
  new_password: string
}): Promise<ApiSuccessResponse<unknown>> {
  const { data } = await api.post<ApiSuccessResponse<unknown>>(
    "/api/auth/confirm-reset-password/",
    input
  )
  return data
}

/** POST /api/auth/change-password/ - Change password for authenticated dashboard users. */
export async function changePassword(input: {
  old_password: string
  new_password: string
}): Promise<void> {
  await api.post("/api/auth/change-password/", input)
}

/** GET /api/me/ - Current user (requires auth). Returns serialized user in data. */
export async function getMe(): Promise<User> {
  const { data } = await api.get<ApiSuccessResponse<User>>("/api/me/")
  const user = data.data
  if (!user || typeof user.id !== "number") {
    throw new Error("Not authenticated")
  }
  return user as User
}
