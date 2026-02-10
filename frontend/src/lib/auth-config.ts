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

/** Access token refresh interval (4 min). Backend default is 5 min. */
export const REFRESH_INTERVAL_MS = 4 * 60 * 1000
