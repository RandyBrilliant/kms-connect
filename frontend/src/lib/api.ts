import axios, { type AxiosError, type InternalAxiosRequestConfig } from "axios"
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

// ---------------------------------------------------------------------------
// Automatic token refresh interceptor
// ---------------------------------------------------------------------------
// When any request receives a 401:
//   1. Try POST /api/auth/token/refresh/ (uses HTTP-only refresh cookie)
//   2. If refresh succeeds → replay the original request transparently
//   3. If refresh fails   → the refresh token is expired, call onUnauthorized
//
// A queue ensures that if multiple requests 401 at the same time, only ONE
// refresh call is made. The others wait and are replayed after.
// ---------------------------------------------------------------------------

let isRefreshing = false
let isSessionDead = false
let failedQueue: {
  resolve: (value?: unknown) => void
  reject: (reason?: unknown) => void
}[] = []

/**
 * Mark the session as dead — the interceptor will stop trying to refresh.
 * Called during logout and when refresh fails.
 */
export function markSessionExpired() {
  isSessionDead = true
  isRefreshing = false
  processQueue(new axios.AxiosError("Session expired", "401") as AxiosError)
}

/**
 * Reset session state — call after a successful login so the interceptor
 * is ready to handle refreshes again.
 */
export function resetSessionState() {
  isSessionDead = false
  isRefreshing = false
  failedQueue = []
}

function processQueue(error: AxiosError | null) {
  failedQueue.forEach(({ resolve, reject }) => {
    if (error) {
      reject(error)
    } else {
      resolve()
    }
  })
  failedQueue = []
}

/** URLs where a 401 means "bad credentials", not "session expired" */
function isPublicAuthUrl(url: string | undefined): boolean {
  if (!url) return false
  return (
    url.includes("/api/auth/token/") &&
    !url.includes("/token/refresh")
  ) || url.includes("/api/auth/request-password-reset/")
}

api.interceptors.response.use(
  (res) => res,
  async (err: AxiosError) => {
    const originalRequest = err.config as InternalAxiosRequestConfig & {
      _retry?: boolean
    }

    // Not a 401 → just reject normally
    if (err.response?.status !== 401) {
      return Promise.reject(err)
    }

    // Session already known to be dead (logout in progress or refresh failed)
    // → reject immediately, don't attempt refresh
    if (isSessionDead) {
      return Promise.reject(err)
    }

    // 401 on login / password-reset → bad credentials, not session expiry
    if (isPublicAuthUrl(originalRequest?.url)) {
      return Promise.reject(err)
    }

    // 401 on the refresh endpoint itself → refresh token is expired, give up
    if (originalRequest?.url?.includes("/token/refresh")) {
      isSessionDead = true
      getOnUnauthorized()?.()
      return Promise.reject(err)
    }

    // Already retried this request → avoid infinite loop
    if (originalRequest._retry) {
      return Promise.reject(err)
    }

    // If a refresh is already in-flight, queue this request
    if (isRefreshing) {
      return new Promise((resolve, reject) => {
        failedQueue.push({ resolve, reject })
      })
        .then(() => {
          originalRequest._retry = true
          return api(originalRequest)
        })
        .catch((queueErr) => Promise.reject(queueErr))
    }

    // Start a refresh
    originalRequest._retry = true
    isRefreshing = true

    try {
      await api.post("/api/auth/token/refresh/")
      // Refresh succeeded → replay all queued requests
      processQueue(null)
      // Replay the original request
      return api(originalRequest)
    } catch (refreshError) {
      // Refresh failed → session truly expired      isSessionDead = true      processQueue(refreshError as AxiosError)
      getOnUnauthorized()?.()
      return Promise.reject(refreshError)
    } finally {
      isRefreshing = false
    }
  }
)
