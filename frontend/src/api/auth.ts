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

/** GET /api/me/ - Current user (requires auth). Returns serialized user in data. */
export async function getMe(): Promise<User> {
  const { data } = await api.get<ApiSuccessResponse<User>>("/api/me/")
  const user = data.data
  if (!user || typeof user.id !== "number") {
    throw new Error("Not authenticated")
  }
  return user as User
}
