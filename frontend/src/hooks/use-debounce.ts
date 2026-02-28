/**
 * Returns a debounced version of `value` that only updates after `delay` ms
 * of inactivity. Useful for delaying API calls while the user is still typing.
 */

import { useState, useEffect } from "react"

export function useDebounce<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = useState<T>(value)

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay)
    return () => clearTimeout(timer)
  }, [value, delay])

  return debounced
}
