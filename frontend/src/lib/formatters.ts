/**
 * Formatting utilities for dates, numbers, and strings.
 * Centralized to ensure consistency across the application.
 */

import { format, formatDistanceToNow, parseISO } from "date-fns"
import { id } from "date-fns/locale"

// ============================================================================
// Date Formatting
// ============================================================================

/**
 * Format date as "dd MMM yyyy" (e.g., "15 Feb 2026")
 */
export function formatDate(date: string | Date | null | undefined): string {
  if (!date) return "-"
  try {
    const dateObj = typeof date === "string" ? parseISO(date) : date
    return format(dateObj, "dd MMM yyyy", { locale: id })
  } catch {
    return "-"
  }
}

/**
 * Format date with time as "dd MMM yyyy HH:mm" (e.g., "15 Feb 2026 14:35")
 */
export function formatDateTime(
  date: string | Date | null | undefined
): string {
  if (!date) return "-"
  try {
    const dateObj = typeof date === "string" ? parseISO(date) : date
    return format(dateObj, "dd MMM yyyy HH:mm", { locale: id })
  } catch {
    return "-"
  }
}

/**
 * Format date as relative time (e.g., "3 hari yang lalu")
 */
export function formatRelativeTime(
  date: string | Date | null | undefined
): string {
  if (!date) return "-"
  try {
    const dateObj = typeof date === "string" ? parseISO(date) : date
    return formatDistanceToNow(dateObj, { addSuffix: true, locale: id })
  } catch {
    return "-"
  }
}

/**
 * Format date for input fields (YYYY-MM-DD)
 */
export function formatDateForInput(
  date: string | Date | null | undefined
): string {
  if (!date) return ""
  try {
    const dateObj = typeof date === "string" ? parseISO(date) : date
    return format(dateObj, "yyyy-MM-dd")
  } catch {
    return ""
  }
}

// ============================================================================
// Number Formatting
// ============================================================================

/**
 * Format number with thousand separators (e.g., 1.234.567)
 */
export function formatNumber(num: number | null | undefined): string {
  if (num == null) return "-"
  return new Intl.NumberFormat("id-ID").format(num)
}

/**
 * Format currency in Rupiah (e.g., Rp 1.234.567)
 */
export function formatCurrency(amount: number | null | undefined): string {
  if (amount == null) return "-"
  return new Intl.NumberFormat("id-ID", {
    style: "currency",
    currency: "IDR",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount)
}

/**
 * Format percentage (e.g., 85.5%)
 */
export function formatPercentage(
  value: number | null | undefined,
  decimals: number = 1
): string {
  if (value == null) return "-"
  return `${value.toFixed(decimals)}%`
}

// ============================================================================
// String Formatting
// ============================================================================

/**
 * Format NIK with spaces (e.g., 3302 0123 4567 8901)
 */
export function formatNIK(nik: string | null | undefined): string {
  if (!nik) return "-"
  if (nik.length !== 16) return nik
  return nik.replace(/(\d{4})(\d{4})(\d{4})(\d{4})/, "$1 $2 $3 $4")
}

/**
 * Format phone number to Indonesian format
 * 08xxx => +62 8xxx
 */
export function formatPhone(phone: string | null | undefined): string {
  if (!phone) return "-"
  
  // Remove spaces and dashes
  const cleaned = phone.replace(/[\s-]/g, "")
  
  // Convert 08xxx to +62 8xxx
  if (cleaned.startsWith("0")) {
    const withoutZero = cleaned.substring(1)
    // Add spaces every 4 digits for readability
    return `+62 ${withoutZero.replace(/(\d{3,4})/g, "$1 ").trim()}`
  }
  
  // Already in +62 format
  if (cleaned.startsWith("+62")) {
    const number = cleaned.substring(3)
    return `+62 ${number.replace(/(\d{3,4})/g, "$1 ").trim()}`
  }
  
  // 62xxx format
  if (cleaned.startsWith("62")) {
    const number = cleaned.substring(2)
    return `+62 ${number.replace(/(\d{3,4})/g, "$1 ").trim()}`
  }
  
  return phone
}

/**
 * Format file size in human-readable format (e.g., "1.5 MB")
 */
export function formatFileSize(bytes: number | null | undefined): string {
  if (bytes == null || bytes === 0) return "0 B"
  
  const k = 1024
  const sizes = ["B", "KB", "MB", "GB"]
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  
  return `${(bytes / Math.pow(k, i)).toFixed(1)} ${sizes[i]}`
}

/**
 * Truncate long text with ellipsis
 */
export function truncate(
  text: string | null | undefined,
  maxLength: number = 50
): string {
  if (!text) return "-"
  if (text.length <= maxLength) return text
  return `${text.substring(0, maxLength)}...`
}

/**
 * Capitalize first letter of each word
 */
export function capitalize(text: string | null | undefined): string {
  if (!text) return ""
  return text
    .split(" ")
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(" ")
}

/**
 * Format full name with proper casing
 */
export function formatName(name: string | null | undefined): string {
  if (!name) return "-"
  return capitalize(name)
}

// ============================================================================
// Address Formatting
// ============================================================================

/**
 * Format full address from components (strings)
 */
export function formatFullAddress(components: {
  address?: string
  district?: string
  province?: string
}): string {
  const parts = [
    components.address,
    components.district,
    components.province,
  ].filter(Boolean)

  return parts.length > 0 ? parts.join(", ") : "-"
}

/**
 * Format address from village_display (RegionDisplay from backend)
 */
export function formatRegionDisplay(display: {
  village?: string
  district?: string
  regency?: string
  province?: string
} | null | undefined): string {
  if (!display) return "-"
  const parts = [
    display.village,
    display.district,
    display.regency,
    display.province,
  ].filter(Boolean)
  return parts.length > 0 ? parts.join(", ") : "-"
}

// ============================================================================
// Age Calculation
// ============================================================================

/**
 * Calculate age from birth date
 */
export function calculateAge(birthDate: string | Date | null | undefined): number | null {
  if (!birthDate) return null
  
  try {
    const birthDateObj = typeof birthDate === "string" ? parseISO(birthDate) : birthDate
    const today = new Date()
    let age = today.getFullYear() - birthDateObj.getFullYear()
    const monthDiff = today.getMonth() - birthDateObj.getMonth()
    
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDateObj.getDate())) {
      age--
    }
    
    return age
  } catch {
    return null
  }
}

/**
 * Format age with "tahun" suffix
 */
export function formatAge(birthDate: string | Date | null | undefined): string {
  const age = calculateAge(birthDate)
  return age != null ? `${age} tahun` : "-"
}

// ============================================================================
// Passport Formatting
// ============================================================================

/**
 * Format passport number (e.g., AB 1234567)
 */
export function formatPassport(passport: string | null | undefined): string {
  if (!passport) return "-"
  if (passport.length !== 9) return passport
  return passport.replace(/([A-Z]{2})(\d{7})/, "$1 $2")
}

// ============================================================================
// Days Since
// ============================================================================

/**
 * Calculate days between two dates
 */
export function daysBetween(
  startDate: string | Date,
  endDate: string | Date = new Date()
): number {
  const start = typeof startDate === "string" ? parseISO(startDate) : startDate
  const end = typeof endDate === "string" ? parseISO(endDate) : endDate
  const diffTime = Math.abs(end.getTime() - start.getTime())
  return Math.ceil(diffTime / (1000 * 60 * 60 * 24))
}

/**
 * Format days since date (e.g., "3 hari")
 */
export function formatDaysSince(
  date: string | Date | null | undefined
): string {
  if (!date) return "-"
  const days = daysBetween(date)
  return `${days} hari`
}
