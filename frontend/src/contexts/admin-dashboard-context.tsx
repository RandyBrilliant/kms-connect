import * as React from "react"

/** Prefix absolute paths for master admin (`""`) or operator admin (`/admin-portal`). */
export function joinAdminPath(basePath: string, path: string): string {
  const normalized = path.startsWith("/") ? path : `/${path}`
  if (!basePath) return normalized
  return `${basePath}${normalized}`
}

export interface AdminDashboardContextValue {
  /** "" for master admin at `/`; `/admin-portal` for operator admin */
  basePath: string
}

const AdminDashboardContext = React.createContext<AdminDashboardContextValue>({
  basePath: "",
})

export function AdminDashboardProvider({
  basePath,
  children,
}: {
  basePath: string
  children: React.ReactNode
}) {
  return (
    <AdminDashboardContext.Provider value={{ basePath }}>
      {children}
    </AdminDashboardContext.Provider>
  )
}

export function useAdminDashboard() {
  return React.useContext(AdminDashboardContext)
}
