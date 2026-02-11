import { Navigate } from "react-router-dom"
import { LoginForm } from "@/components/login-form"
import { useAuth } from "@/contexts/auth-context"
import {
  canAccessDashboard,
  getDashboardRouteForRole,
} from "@/types/auth"
import { Button } from "@/components/ui/button"
import { usePageTitle } from "@/hooks/use-page-title"

export function LoginPage() {
  usePageTitle("Login")
  const { user, isLoading, logout } = useAuth()

  if (isLoading) {
    return (
      <div className="flex min-h-svh items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    )
  }

  if (user) {
    if (canAccessDashboard(user.role)) {
      return (
        <Navigate to={getDashboardRouteForRole(user.role)} replace />
      )
    }
    return (
      <div className="flex min-h-svh flex-col items-center justify-center gap-4 bg-muted p-4 text-center">
        <p className="text-muted-foreground">
          Akun pelamar tidak dapat mengakses dashboard. Gunakan aplikasi
          pelamar.
        </p>
        <Button variant="outline" onClick={() => logout()}>
          Keluar
        </Button>
      </div>
    )
  }

  return (
    <div className="flex min-h-svh flex-col items-center justify-center bg-muted p-4">
      <div className="w-full max-w-md">
        <LoginForm />
      </div>
    </div>
  )
}
