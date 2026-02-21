/**
 * User roles from backend (CustomUser.role).
 * Only ADMIN, STAFF, COMPANY can access the dashboard.
 * APPLICANT uses a separate mobile/applicant portal.
 */
export type UserRole = "ADMIN" | "STAFF" | "COMPANY" | "APPLICANT"

/** User summary returned by login and /api/me/ */
export interface User {
  id: number
  email: string
  full_name?: string
  role: UserRole
  is_active: boolean
  email_verified: boolean
}

/** Roles allowed to access the backoffice dashboard */
export const DASHBOARD_ROLES: UserRole[] = ["ADMIN", "STAFF", "COMPANY"]

/** Route prefix per role (dashboard / home) */
export const ROLE_ROUTE: Record<UserRole, string> = {
  ADMIN: "/",
  STAFF: "/staff-portal",
  COMPANY: "/company",
  APPLICANT: "/login", // Applicants redirect to login with error
}

export function getDashboardRouteForRole(role: UserRole): string {
  return ROLE_ROUTE[role]
}

export function canAccessDashboard(role: UserRole): boolean {
  return DASHBOARD_ROLES.includes(role)
}
