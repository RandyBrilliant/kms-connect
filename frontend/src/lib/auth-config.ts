/**
 * Auth configuration and callbacks.
 * Allows API layer to notify auth context of session expiry without circular deps.
 */

export type OnUnauthorizedCallback = () => void

let onUnauthorized: OnUnauthorizedCallback | null = null

export function setOnUnauthorized(callback: OnUnauthorizedCallback | null) {
  onUnauthorized = callback
}

export function getOnUnauthorized(): OnUnauthorizedCallback | null {
  return onUnauthorized
}

/**
 * Access token refresh interval (4 min).
 * Backend access token expires after 5 minutes.
 * We refetch user data every 4 minutes to keep session alive.
 * 
 * Note: This is now handled by TanStack Query's refetchInterval in use-auth-query.ts
 * @deprecated Use refetchInterval in useMeQuery instead
 */
export const REFRESH_INTERVAL_MS = 4 * 60 * 1000

/**
 * Token lifetime configuration.
 * Should match backend settings.
 */
export const TOKEN_CONFIG = {
  /** Access token expires after 5 minutes (backend default) */
  ACCESS_TOKEN_LIFETIME_MS: 5 * 60 * 1000,
  
  /** Refresh token expires after 7 days (backend default) */
  REFRESH_TOKEN_LIFETIME_MS: 7 * 24 * 60 * 60 * 1000,
  
  /** Refetch user data every 4 minutes to keep session alive */
  REFETCH_INTERVAL_MS: 4 * 60 * 1000,
  
  /** Grace period before showing "session expired" (30 seconds) */
  SESSION_GRACE_PERIOD_MS: 30 * 1000,
} as const
