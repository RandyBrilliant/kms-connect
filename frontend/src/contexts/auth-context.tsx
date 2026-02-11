import {
  createContext,
  useCallback,
  useEffect,
  type ReactNode,
} from "react"
import { useNavigate } from "react-router-dom"
import { useQueryClient } from "@tanstack/react-query"
import { toast } from "@/lib/toast"
import { login as loginApi, logout as logoutApi } from "@/api/auth"
import { setOnUnauthorized } from "@/lib/auth-config"
import { markSessionExpired, resetSessionState } from "@/lib/api"
import { useMeQuery, authKeys } from "@/hooks/use-auth-query"
import type { User } from "@/types/auth"
import {
  canAccessDashboard,
  getDashboardRouteForRole,
  type UserRole,
} from "@/types/auth"

interface AuthState {
  user: User | null
  isLoading: boolean
  isAuthenticated: boolean
}

export interface AuthContextValue extends AuthState {
  login: (email: string, password: string) => Promise<void>
  logout: () => Promise<void>
  setUser: (user: User | null) => void
}

export const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  // Use TanStack Query for user session management
  const { data: user, isLoading } = useMeQuery()

  const login = useCallback(
    async (email: string, password: string) => {
      const loggedInUser = await loginApi({ email, password })
      if (!canAccessDashboard(loggedInUser.role as UserRole)) {
        throw new Error(
          "Akun pelamar tidak dapat mengakses dashboard. Gunakan aplikasi pelamar."
        )
      }

      // Reset interceptor state so it can handle refreshes again
      resetSessionState()
      // Update query cache with logged-in user
      queryClient.setQueryData(authKeys.me(), loggedInUser)

      toast.success("Login berhasil", "Mengalihkan ke dashboard...")
      const route = getDashboardRouteForRole(loggedInUser.role as UserRole)
      navigate(route)
    },
    [navigate, queryClient]
  )

  const logout = useCallback(async () => {
    // 1. Kill the interceptor's refresh loop FIRST
    markSessionExpired()
    // 2. Cancel every in-flight & pending query so nothing fires after logout
    await queryClient.cancelQueries()
    // 3. Clear all cached data (removes query cache entirely)
    queryClient.clear()

    try {
      await logoutApi()
      toast.success("Logout berhasil", "Anda telah keluar dari akun")
    } catch (error) {
      // Even if logout API fails, local session is already cleared
      console.error("Logout error:", error)
    } finally {
      navigate("/login")
    }
  }, [navigate, queryClient])

  const setUser = useCallback(
    (newUser: User | null) => {
      queryClient.setQueryData(authKeys.me(), newUser)
    },
    [queryClient]
  )

  // Handle unauthorized errors (401) — called by interceptor when refresh fails
  const handleUnauthorized = useCallback(async () => {
    markSessionExpired()
    await queryClient.cancelQueries()
    queryClient.clear()
    navigate("/login")
    toast.error("Sesi berakhir", "Silakan login kembali")
  }, [navigate, queryClient])

  // Register unauthorized callback for API interceptor
  useEffect(() => {
    setOnUnauthorized(handleUnauthorized)
    return () => setOnUnauthorized(null)
  }, [handleUnauthorized])

  // NOTE: 401 handling is done inside the axios interceptor (lib/api.ts).
  // When the interceptor fails to refresh, it calls getOnUnauthorized(),
  // which invokes handleUnauthorized above. No extra useEffect needed.

  const value: AuthContextValue = {
    user: user ?? null,
    isLoading,
    isAuthenticated: !!user,
    login,
    logout,
    setUser,
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
