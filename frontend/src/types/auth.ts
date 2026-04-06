/**
 * User roles from backend (CustomUser.role).
 * MASTER_ADMIN and ADMIN use the web dashboard; APPLICANT uses mobile portal.
 */
export type UserRole =
  | "MASTER_ADMIN"
  | "ADMIN"
  | "STAFF"
  | "COMPANY"
  | "APPLICANT"

/** User summary returned by login and /api/me/ */
export interface User {
  id: number
  email: string
  full_name?: string
  role: UserRole
  is_active: boolean
  email_verified: boolean
}

/** Roles allowed to access the backoffice web dashboard */
export const DASHBOARD_ROLES: UserRole[] = [
  "MASTER_ADMIN",
  "ADMIN",
  "STAFF",
  "COMPANY",
]

/** Route prefix per role (dashboard / home) */
export const ROLE_ROUTE: Record<UserRole, string> = {
  MASTER_ADMIN: "/",
  ADMIN: "/admin-portal",
  STAFF: "/staff-portal",
  COMPANY: "/company",
  APPLICANT: "/login",
}

export function getDashboardRouteForRole(role: UserRole): string {
  return ROLE_ROUTE[role]
}

export function canAccessDashboard(role: UserRole): boolean {
  return DASHBOARD_ROLES.includes(role)
}

export function isMasterAdmin(role: UserRole): boolean {
  return role === "MASTER_ADMIN"
}

export function isRestrictedAdmin(role: UserRole): boolean {
  return role === "ADMIN"
}

export function isAnyWebAdmin(role: UserRole): boolean {
  return role === "MASTER_ADMIN" || role === "ADMIN"
}
