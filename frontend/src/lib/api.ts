import axios from "axios"
import { env } from "./env"
import { getOnUnauthorized } from "./auth-config"

/**
 * Axios instance for API requests.
 * Uses credentials: true for HTTP-only cookie auth.
 */
export const api = axios.create({
  baseURL: env.VITE_API_URL || "",
  withCredentials: true,
  headers: {
    "Content-Type": "application/json",
  },
})

/**
 * Global 401 handler:
 * - For any 401 (including refresh), notify AuthProvider via onUnauthorized
 * - Except for public auth endpoints like login, where 401 just means bad credentials
 * - Do NOT auto-call the refresh endpoint here (handled explicitly in auth-context)
 * - Avoid retry loops.
 */
api.interceptors.response.use(
  (res) => res,
  async (err) => {
    if (err.response?.status === 401) {
      const url = err.config?.url as string | undefined

      // 401 on public auth endpoints (e.g. wrong password) should NOT be treated as "session expired"
      if (url && url.includes("/api/auth/") && !url.includes("/token/refresh")) {
        return Promise.reject(err)
      }

      getOnUnauthorized()?.()
    }
    return Promise.reject(err)
  }
)
