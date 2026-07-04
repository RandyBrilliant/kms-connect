/** Display formatting for orang tua when marked almarhum. */

export function formatParentName(
  name: string | null | undefined,
  almarhum?: boolean,
): string {
  const raw = (name ?? "").trim()
  if (!almarhum) return raw
  if (!raw) return "Alm."
  const upper = raw.toUpperCase()
  if (upper.startsWith("ALM.") || upper.startsWith("ALM ")) return raw
  return `Alm. ${raw}`
}

export function formatParentAge(
  age: number | null | undefined,
  almarhum?: boolean,
): string | number | null | undefined {
  if (almarhum) return "-"
  return age
}
