import { ThemeProvider } from "next-themes"
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom"
import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { Toaster } from "@/components/ui/sonner"
import { AuthProvider } from "@/contexts/auth-context"
import { ProtectedRoute } from "@/components/protected-route"
import { AdminLayout } from "@/components/admin-layout"
import { LoginPage } from "@/pages/login-page"
import { AdminDashboardPage } from "@/pages/admin-dashboard-page"
import { AdminAdminListPage } from "@/pages/admin-admin-list-page"
import { AdminAdminFormPage } from "@/pages/admin-admin-form-page"
import { StaffStaffListPage } from "@/pages/staff-staff-list-page"
import { StaffStaffFormPage } from "@/pages/staff-staff-form-page"
import { StaffDashboardPage } from "@/pages/staff-dashboard-page"
import { CompanyDashboardPage } from "@/pages/company-dashboard-page"
import { CompanyCompanyListPage } from "@/pages/company-company-list-page"
import { CompanyCompanyFormPage } from "@/pages/company-company-form-page"
import { AdminPelamarListPage } from "@/pages/admin-pelamar-list-page"
import { AdminPelamarFormPage } from "@/pages/admin-pelamar-form-page"
import { AdminPelamarDetailPage } from "@/pages/admin-pelamar-detail-page"
import { ProfilePage } from "@/pages/profile-page"

const queryClient = new QueryClient()

function AppRoutes() {
  return (
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
  )
}

export default function App() {
  return (
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
  )
}
