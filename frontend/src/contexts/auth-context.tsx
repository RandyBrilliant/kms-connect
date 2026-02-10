import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react"
import { useNavigate } from "react-router-dom"
import { toast } from "@/lib/toast"
import {
  login as loginApi,
  logout as logoutApi,
  getMe,
  refreshToken,
} from "@/api/auth"
import {
  REFRESH_INTERVAL_MS,
  setOnUnauthorized,
} from "@/lib/auth-config"
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
  const [user, setUser] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const navigate = useNavigate()

  const login = useCallback(async (email: string, password: string) => {
    const loggedInUser = await loginApi({ email, password })
    if (!canAccessDashboard(loggedInUser.role as UserRole)) {
      throw new Error(
        "Akun pelamar tidak dapat mengakses dashboard. Gunakan aplikasi pelamar."
      )
    }
    setUser(loggedInUser)
    toast.success("Login berhasil", "Mengalihkan ke dashboard...")
    const route = getDashboardRouteForRole(loggedInUser.role as UserRole)
    navigate(route)
  }, [navigate])

  const logout = useCallback(async () => {
    try {
      await logoutApi()
      toast.success("Logout berhasil", "Anda telah keluar dari akun")
    } finally {
      setUser(null)
      navigate("/login")
    }
  }, [navigate])

  const refreshIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const handleUnauthorized = useCallback(() => {
    setUser(null)
    navigate("/login")
    toast.error("Sesi berakhir", "Silakan login kembali")
  }, [navigate])

  useEffect(() => {
    setOnUnauthorized(handleUnauthorized)
    return () => setOnUnauthorized(null)
  }, [handleUnauthorized])

  useEffect(() => {
    let cancelled = false
    getMe()
      .then((u) => {
        if (!cancelled) setUser(u)
      })
      .catch(() => {
        if (!cancelled) setUser(null)
      })
      .finally(() => {
        if (!cancelled) setIsLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [])

  useEffect(() => {
    if (!user) return

    const doRefresh = () => {
      refreshToken().catch(() => {
        handleUnauthorized()
      })
    }

    refreshIntervalRef.current = setInterval(doRefresh, REFRESH_INTERVAL_MS)

    const onVisibilityChange = () => {
      if (document.visibilityState === "visible") {
        doRefresh()
      }
    }
    document.addEventListener("visibilitychange", onVisibilityChange)

    return () => {
      if (refreshIntervalRef.current) {
        clearInterval(refreshIntervalRef.current)
        refreshIntervalRef.current = null
      }
      document.removeEventListener("visibilitychange", onVisibilityChange)
    }
  }, [user, handleUnauthorized])

  const value: AuthContextValue = {
    user,
    isLoading,
    isAuthenticated: !!user,
    login,
    logout,
    setUser,
  }

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) {
    throw new Error("useAuth must be used within AuthProvider")
  }
  return ctx
}
