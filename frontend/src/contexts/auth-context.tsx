import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  type ReactNode,
} from "react"
import { useNavigate } from "react-router-dom"
import { useQueryClient } from "@tanstack/react-query"
import { toast } from "@/lib/toast"
import { login as loginApi, logout as logoutApi } from "@/api/auth"
import { setOnUnauthorized } from "@/lib/auth-config"
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

interface AuthContextValue extends AuthState {
  login: (email: string, password: string) => Promise<void>
  logout: () => Promise<void>
  setUser: (user: User | null) => void
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  
  // Use TanStack Query for user session management
  const { data: user, isLoading, error } = useMeQuery()

  const login = useCallback(
    async (email: string, password: string) => {
      const loggedInUser = await loginApi({ email, password })
      if (!canAccessDashboard(loggedInUser.role as UserRole)) {
        throw new Error(
          "Akun pelamar tidak dapat mengakses dashboard. Gunakan aplikasi pelamar."
        )
      }
      
      // Update query cache with logged-in user
      queryClient.setQueryData(authKeys.me(), loggedInUser)
      
      toast.success("Login berhasil", "Mengalihkan ke dashboard...")
      const route = getDashboardRouteForRole(loggedInUser.role as UserRole)
      navigate(route)
    },
    [navigate, queryClient]
  )

  const logout = useCallback(async () => {
    try {
      await logoutApi()
      toast.success("Logout berhasil", "Anda telah keluar dari akun")
    } catch (error) {
      // Even if logout API fails, clear local session
      console.error("Logout error:", error)
    } finally {
      // Clear all cached data
      queryClient.clear()
      navigate("/login")
    }
  }, [navigate, queryClient])

  const setUser = useCallback(
    (newUser: User | null) => {
      queryClient.setQueryData(authKeys.me(), newUser)
    },
    [queryClient]
  )

  // Handle unauthorized errors (401)
  const handleUnauthorized = useCallback(() => {
    // Clear all cache
    queryClient.clear()
    navigate("/login")
    toast.error("Sesi berakhir", "Silakan login kembali")
  }, [navigate, queryClient])

  // Register unauthorized callback for API interceptor
  useEffect(() => {
    setOnUnauthorized(handleUnauthorized)
    return () => setOnUnauthorized(null)
  }, [handleUnauthorized])

  // Handle query errors (e.g., 401 from getMe)
  useEffect(() => {
    if (error) {
      const status = (error as any)?.response?.status
      // Don't show toast on initial 401 (user not logged in)
      // The login page will handle that
      if (status === 401 && user) {
        // Only show toast if user was previously authenticated
        handleUnauthorized()
      }
    }
  }, [error, user, handleUnauthorized])

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

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) {
    throw new Error("useAuth must be used within AuthProvider")
  }
  return ctx
}
