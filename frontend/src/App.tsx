import { lazy, Suspense } from "react"
import { ThemeProvider } from "next-themes"
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom"
import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { IconLoader } from "@tabler/icons-react"
import { Toaster } from "@/components/ui/sonner"
import { toast } from "@/lib/toast"
import { AuthProvider } from "@/contexts/auth-context"
import { ProtectedRoute } from "@/components/protected-route"
import { AdminLayout } from "@/components/admin-layout"
import { ErrorBoundary, RouteErrorBoundary } from "@/components/error-boundary"

// Lazy-loaded page components for code splitting
const LoginPage = lazy(() => import("@/pages/login-page").then(m => ({ default: m.LoginPage })))
const AdminDashboardPage = lazy(() => import("@/pages/admin-dashboard-page").then(m => ({ default: m.AdminDashboardPage })))
const AdminAdminListPage = lazy(() => import("@/pages/admin-admin-list-page").then(m => ({ default: m.AdminAdminListPage })))
const AdminAdminFormPage = lazy(() => import("@/pages/admin-admin-form-page").then(m => ({ default: m.AdminAdminFormPage })))
const AdminNewsListPage = lazy(() => import("@/pages/admin-news-list-page").then(m => ({ default: m.AdminNewsListPage })))
const AdminNewsFormPage = lazy(() => import("@/pages/admin-news-form-page").then(m => ({ default: m.AdminNewsFormPage })))
const AdminJobListPage = lazy(() => import("@/pages/admin-job-list-page").then(m => ({ default: m.AdminJobListPage })))
const AdminJobFormPage = lazy(() => import("@/pages/admin-job-form-page").then(m => ({ default: m.AdminJobFormPage })))
const StaffStaffListPage = lazy(() => import("@/pages/staff-staff-list-page").then(m => ({ default: m.StaffStaffListPage })))
const StaffStaffFormPage = lazy(() => import("@/pages/staff-staff-form-page").then(m => ({ default: m.StaffStaffFormPage })))
const StaffDashboardPage = lazy(() => import("@/pages/staff-dashboard-page").then(m => ({ default: m.StaffDashboardPage })))
const CompanyDashboardPage = lazy(() => import("@/pages/company-dashboard-page").then(m => ({ default: m.CompanyDashboardPage })))
const CompanyCompanyListPage = lazy(() => import("@/pages/company-company-list-page").then(m => ({ default: m.CompanyCompanyListPage })))
const CompanyCompanyFormPage = lazy(() => import("@/pages/company-company-form-page").then(m => ({ default: m.CompanyCompanyFormPage })))
const AdminPelamarListPage = lazy(() => import("@/pages/admin-pelamar-list-page").then(m => ({ default: m.AdminPelamarListPage })))
const AdminPelamarFormPage = lazy(() => import("@/pages/admin-pelamar-form-page").then(m => ({ default: m.AdminPelamarFormPage })))
const AdminPelamarDetailPage = lazy(() => import("@/pages/admin-pelamar-detail-page").then(m => ({ default: m.AdminPelamarDetailPage })))
const ProfilePage = lazy(() => import("@/pages/profile-page").then(m => ({ default: m.ProfilePage })))

// Loading fallback component
function PageLoader() {
  return (
    <div className="flex h-screen w-full items-center justify-center">
      <div className="flex flex-col items-center gap-3">
        <IconLoader className="size-8 animate-spin text-primary" />
        <p className="text-sm text-muted-foreground">Memuat halaman...</p>
      </div>
    </div>
  )
}

// QueryClient configuration with optimized defaults
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Stale time: data is fresh for 1 minute
      staleTime: 60 * 1000,
      // Cache time: unused data stays in cache for 5 minutes
      gcTime: 5 * 60 * 1000,
      // Retry failed requests 3 times with exponential backoff
      retry: (failureCount, error: any) => {
        // Don't retry on 4xx errors (client errors)
        if (error?.response?.status >= 400 && error?.response?.status < 500) {
          return false
        }
        return failureCount < 3
      },
      retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
      // Refetch on window focus for data freshness
      refetchOnWindowFocus: true,
      // Refetch on network reconnect
      refetchOnReconnect: true,
      // Don't refetch on mount if data is still fresh
      refetchOnMount: true,
    },
    mutations: {
      // Retry mutations once on network errors
      retry: (failureCount, error: any) => {
        // Only retry on network errors, not on 4xx/5xx
        if (error?.response?.status) {
          return false
        }
        return failureCount < 1
      },
      // Global error handler for mutations
      onError: (error: any) => {
        const message = error?.response?.data?.message || error?.message || "Terjadi kesalahan"
        toast.error("Operasi gagal", message)
      },
    },
  },
})

function AppRoutes() {
  return (
    <RouteErrorBoundary>
      <Suspense fallback={<PageLoader />}>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
      <Route
        path="/"
        element={
          <ProtectedRoute allowedRoles={["ADMIN"]}>
            <AdminLayout />
          </ProtectedRoute>
        }
      >
        <Route index element={<AdminDashboardPage />} />
        <Route path="admin" element={<AdminAdminListPage />} />
        <Route path="admin/new" element={<AdminAdminFormPage />} />
        <Route path="admin/:id/edit" element={<AdminAdminFormPage />} />
        <Route path="berita" element={<AdminNewsListPage />} />
        <Route path="berita/new" element={<AdminNewsFormPage />} />
        <Route path="berita/:id/edit" element={<AdminNewsFormPage />} />
        <Route path="lowongan-kerja" element={<AdminJobListPage />} />
        <Route path="lowongan-kerja/new" element={<AdminJobFormPage />} />
        <Route path="lowongan-kerja/:id/edit" element={<AdminJobFormPage />} />
        <Route path="pelamar" element={<AdminPelamarListPage />} />
        <Route path="pelamar/new" element={<AdminPelamarFormPage />} />
        <Route path="pelamar/:id" element={<AdminPelamarDetailPage />} />
        <Route path="staff" element={<StaffStaffListPage />} />
        <Route path="staff/new" element={<StaffStaffFormPage />} />
        <Route path="staff/:id/edit" element={<StaffStaffFormPage />} />
        <Route path="perusahaan" element={<CompanyCompanyListPage />} />
        <Route path="perusahaan/new" element={<CompanyCompanyFormPage />} />
        <Route path="perusahaan/:id/edit" element={<CompanyCompanyFormPage />} />
        <Route path="profil" element={<ProfilePage />} />
      </Route>
      <Route
        path="/staff"
        element={
          <ProtectedRoute allowedRoles={["STAFF"]}>
            <StaffDashboardPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/staff/profil"
        element={
          <ProtectedRoute allowedRoles={["STAFF"]}>
            <StaffDashboardPage>
              <ProfilePage />
            </StaffDashboardPage>
          </ProtectedRoute>
        }
      />
      <Route
        path="/company"
        element={
          <ProtectedRoute allowedRoles={["COMPANY"]}>
            <CompanyDashboardPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/company/profil"
        element={
          <ProtectedRoute allowedRoles={["COMPANY"]}>
            <CompanyDashboardPage>
              <ProfilePage />
            </CompanyDashboardPage>
          </ProtectedRoute>
        }
      />
      <Route path="*" element={<Navigate to="/login" replace />} />
        </Routes>
      </Suspense>
    </RouteErrorBoundary>
  )
}

export default function App() {
  return (
    <ErrorBoundary
      onError={(error, errorInfo) => {
        // Log to console in development
        if (import.meta.env.DEV) {
          console.error("Application Error:", error, errorInfo)
        }
        // TODO: Send to error tracking service (Sentry, LogRocket, etc.)
        // logErrorToService({ error, errorInfo, user: getCurrentUser() })
      }}
    >
      <ThemeProvider defaultTheme="light" forcedTheme="light">
        <QueryClientProvider client={queryClient}>
          <BrowserRouter>
            <AuthProvider>
              <AppRoutes />
              <Toaster />
            </AuthProvider>
          </BrowserRouter>
        </QueryClientProvider>
      </ThemeProvider>
    </ErrorBoundary>
  )
}
