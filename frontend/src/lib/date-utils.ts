/**
 * Date utility functions for reports and date range filtering.
 * Uses date-fns for consistent date formatting.
 */

import {
  startOfMonth,
  endOfMonth,
  startOfYear,
  endOfYear,
  subMonths,
  subDays,
  format,
} from "date-fns"

/**
 * Format date to YYYY-MM-DD (ISO date string for API)
 */
export function formatDateForAPI(date: Date): string {
  return format(date, "yyyy-MM-dd")
}

/**
 * Get current month date range
 * @returns {start_date, end_date} for current month
 */
export function getCurrentMonthRange(): { start_date: string; end_date: string } {
  const now = new Date()
  return {
    start_date: formatDateForAPI(startOfMonth(now)),
    end_date: formatDateForAPI(endOfMonth(now)),
  }
}

/**
 * Get last month date range
 */
export function getLastMonthRange(): { start_date: string; end_date: string } {
  const now = new Date()
  const lastMonth = subMonths(now, 1)
  return {
    start_date: formatDateForAPI(startOfMonth(lastMonth)),
    end_date: formatDateForAPI(endOfMonth(lastMonth)),
  }
}

/**
 * Get current year date range
 */
export function getCurrentYearRange(): { start_date: string; end_date: string } {
  const now = new Date()
  return {
    start_date: formatDateForAPI(startOfYear(now)),
    end_date: formatDateForAPI(endOfYear(now)),
  }
}

/**
 * Get last 30 days date range
 */
export function getLast30DaysRange(): { start_date: string; end_date: string } {
  const now = new Date()
  return {
    start_date: formatDateForAPI(subDays(now, 30)),
    end_date: formatDateForAPI(now),
  }
}

/**
 * Get last 7 days date range
 */
export function getLast7DaysRange(): { start_date: string; end_date: string } {
  const now = new Date()
  return {
    start_date: formatDateForAPI(subDays(now, 7)),
    end_date: formatDateForAPI(now),
  }
}

/**
 * Format Date object for display (Indonesian format)
 */
export function formatDateForDisplay(date: Date): string {
  return format(date, "dd MMM yyyy")
}

/**
 * Parse API date string (YYYY-MM-DD) to Date object
 */
export function parseAPIDate(dateStr: string): Date {
  return new Date(dateStr)
}
