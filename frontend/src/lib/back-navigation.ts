import type { NavigateFunction } from "react-router-dom"

/**
 * Navigate back to previous page when possible, otherwise use a safe fallback.
 */
export function goBackOrDefault(
  navigate: NavigateFunction,
  fallbackPath: string
) {
  if (typeof window !== "undefined" && window.history.length > 1) {
    navigate(-1)
    return
  }
  navigate(fallbackPath)
}

