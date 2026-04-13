/**
 * Flatten DRF validation payloads: { errors: { a: ["m"], b: { c: ["x"] } } }
 * for toast / inline messages (detail alone is often generic).
 */
export function formatApiValidationErrors(payload: unknown): string | null {
  if (!payload || typeof payload !== "object") return null
  const errors = (payload as { errors?: unknown }).errors
  if (!errors || typeof errors !== "object" || Array.isArray(errors)) return null

  const msgs: string[] = []

  const walk = (obj: object, prefix: string) => {
    for (const [key, value] of Object.entries(obj)) {
      const path = prefix ? `${prefix}.${key}` : key
      if (Array.isArray(value) && value.length) {
        const parts = value.map((v) => (typeof v === "string" ? v : JSON.stringify(v)))
        msgs.push(`${path}: ${parts.join(", ")}`)
      } else if (value && typeof value === "object" && !Array.isArray(value)) {
        walk(value as object, path)
      } else if (typeof value === "string" && value) {
        msgs.push(`${path}: ${value}`)
      }
    }
  }

  walk(errors as object, "")
  return msgs.length ? msgs.join(" ") : null
}
