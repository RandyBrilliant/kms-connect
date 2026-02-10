/**
 * Centralized toast notifications.
 * Use these helpers for consistent status styling across the app.
 * Status colors: success=green, error=red, warning=amber, info=blue.
 */
import { toast as sonnerToast } from "sonner"

const DEFAULT_DURATION = 4000

export const toast = {
  success: (message: string, description?: string) => {
    sonnerToast.success(message, {
      description,
      duration: DEFAULT_DURATION,
    })
  },

  error: (message: string, description?: string) => {
    sonnerToast.error(message, {
      description,
      duration: DEFAULT_DURATION,
    })
  },

  warning: (message: string, description?: string) => {
    sonnerToast.warning(message, {
      description,
      duration: DEFAULT_DURATION,
    })
  },

  info: (message: string, description?: string) => {
    sonnerToast.info(message, {
      description,
      duration: DEFAULT_DURATION,
    })
  },

  /** Loading toast – returns id to pass to success/error for promise-style updates */
  loading: (message: string) => {
    return sonnerToast.loading(message)
  },
}
