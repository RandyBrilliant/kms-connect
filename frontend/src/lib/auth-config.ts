/**
 * Auth configuration and callbacks.
 *
 * The axios interceptor (lib/api.ts) calls getOnUnauthorized() when a token
 * refresh fails, allowing AuthProvider to clear state and navigate to /login
 * without creating a circular dependency.
 */

export type OnUnauthorizedCallback = () => void

let onUnauthorized: OnUnauthorizedCallback | null = null

export function setOnUnauthorized(callback: OnUnauthorizedCallback | null) {
  onUnauthorized = callback
}

export function getOnUnauthorized(): OnUnauthorizedCallback | null {
  return onUnauthorized
}
