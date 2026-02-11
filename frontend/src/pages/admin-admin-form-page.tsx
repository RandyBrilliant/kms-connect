/**
 * Admin form page - shared for create and edit.
 * /admin/new (create) and /admin/:id/edit (edit)
 */

import { Link, useNavigate, useParams } from "react-router-dom"
import { IconArrowLeft, IconMail, IconKey } from "@tabler/icons-react"

import { AdminForm } from "@/components/admins/admin-form"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  useAdminQuery,
  useCreateAdminMutation,
  useUpdateAdminMutation,
  useDeactivateAdminMutation,
  useActivateAdminMutation,
  useSendVerificationEmailMutation,
  useSendPasswordResetMutation,
} from "@/hooks/use-admins-query"
import { toast } from "@/lib/toast"
import type { AdminUser } from "@/types/admin"
import { usePageTitle } from "@/hooks/use-page-title"

const BASE_PATH = "/admin"

function formatDate(value: string | null) {
  if (!value) return "-"
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  })
}

function AdminEditSidebar({ admin }: { admin: AdminUser }) {
  const deactivateMutation = useDeactivateAdminMutation()
  const activateMutation = useActivateAdminMutation()
  const sendVerificationMutation = useSendVerificationEmailMutation()
  const sendPasswordResetMutation = useSendPasswordResetMutation()

  const handleToggleActive = async () => {
    try {
      if (admin.is_active) {
        await deactivateMutation.mutateAsync(admin.id)
        toast.success("Admin dinonaktifkan", "Akun tidak dapat login")
      } else {
        await activateMutation.mutateAsync(admin.id)
        toast.success("Admin diaktifkan", "Akun dapat login kembali")
      }
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error("Gagal", res?.response?.data?.detail ?? "Coba lagi nanti")
    }
  }

  const handleSendVerification = async () => {
    try {
      await sendVerificationMutation.mutateAsync(admin.id)
      toast.success("Email terkirim", "Email verifikasi telah dikirim ke " + admin.email)
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error("Gagal mengirim", res?.response?.data?.detail ?? "Coba lagi nanti")
    }
  }

  const handleSendPasswordReset = async () => {
    try {
      await sendPasswordResetMutation.mutateAsync(admin.id)
      toast.success("Email terkirim", "Email reset password telah dikirim ke " + admin.email)
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error("Gagal mengirim", res?.response?.data?.detail ?? "Coba lagi nanti")
    }
  }

  return (
    <div className="flex flex-col gap-6">
      {/* Status: Aktif / Nonaktif */}
      <Card>
        <CardHeader>
          <CardTitle>Status Akun</CardTitle>
          <CardDescription>
            {admin.is_active
              ? "Akun aktif dan dapat login"
              : "Akun nonaktif dan tidak dapat login"}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button
            type="button"
            variant={admin.is_active ? "destructive" : "default"}
            className={
              admin.is_active
                ? "cursor-pointer"
                : "cursor-pointer border-green-600 bg-green-600 hover:bg-green-700 hover:text-white"
            }
            onClick={handleToggleActive}
            disabled={
              deactivateMutation.isPending || activateMutation.isPending
            }
          >
            {admin.is_active ? "Nonaktifkan" : "Aktifkan"}
          </Button>
        </CardContent>
      </Card>

      {/* Send email verification */}
      <Card>
        <CardHeader>
          <CardTitle>Email Verifikasi</CardTitle>
          <CardDescription>
            Kirim email verifikasi ke {admin.email}. Hanya untuk akun yang belum terverifikasi.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="cursor-pointer"
            onClick={handleSendVerification}
            disabled={
              admin.email_verified || sendVerificationMutation.isPending
            }
          >
            <IconMail className="mr-2 size-4" />
            Kirim Email Verifikasi
          </Button>
        </CardContent>
      </Card>

      {/* Send password reset */}
      <Card>
        <CardHeader>
          <CardTitle>Reset Password</CardTitle>
          <CardDescription>
            Kirim email reset password ke {admin.email}. Pengguna akan menerima tautan untuk mengganti password.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="cursor-pointer"
            onClick={handleSendPasswordReset}
            disabled={sendPasswordResetMutation.isPending}
          >
            <IconKey className="mr-2 size-4" />
            Kirim Email Reset Password
          </Button>
        </CardContent>
      </Card>

      {/* Metadata */}
      <Card>
        <CardHeader>
          <CardTitle>Metadata</CardTitle>
          <CardDescription>Informasi sistem terkait admin ini</CardDescription>
        </CardHeader>
        <CardContent>
          <dl className="space-y-4 text-sm">
            <div>
              <dt className="text-muted-foreground">ID</dt>
              <dd className="font-medium">{admin.id}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Peran</dt>
              <dd className="font-medium">{admin.role}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Tanggal Bergabung</dt>
              <dd className="font-medium">{formatDate(admin.date_joined)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Login Terakhir</dt>
              <dd className="font-medium">{formatDate(admin.last_login)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Diperbarui pada</dt>
              <dd className="font-medium">{formatDate(admin.updated_at)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Email diverifikasi pada</dt>
              <dd className="font-medium">{formatDate(admin.email_verified_at)}</dd>
            </div>
          </dl>
        </CardContent>
      </Card>
    </div>
  )
}

export function AdminAdminFormPage() {
  const navigate = useNavigate()
  const { id } = useParams<{ id: string }>()
  const isEdit = id !== "new" && id != null
  const adminId = isEdit ? parseInt(id, 10) : null

  usePageTitle(isEdit ? "Edit Admin" : "Tambah Admin")

  const { data: admin, isLoading: loadingAdmin } = useAdminQuery(
    adminId ?? null,
    isEdit
  )
  const createMutation = useCreateAdminMutation()
  const updateMutation = useUpdateAdminMutation(adminId ?? 0)

  const handleSubmit = async (values: {
    email: string
    full_name?: string
    password?: string
    is_active?: boolean
    email_verified?: boolean
  }) => {
    try {
      if (isEdit && adminId) {
        await updateMutation.mutateAsync({
          email: values.email,
          full_name: values.full_name,
        })
        toast.success("Admin diperbarui", "Perubahan berhasil disimpan")
        navigate(BASE_PATH)
      } else {
        await createMutation.mutateAsync({
          email: values.email,
          full_name: values.full_name,
          password: values.password!,
          is_active: true,
          email_verified: false,
        })
        toast.success("Admin ditambahkan", "Admin baru berhasil dibuat")
        navigate(BASE_PATH)
      }
    } catch (err: unknown) {
      const res = err as {
        response?: { data?: { errors?: Record<string, string[]>; detail?: string } }
      }
      const errors = res?.response?.data?.errors
      const detail = res?.response?.data?.detail
      if (errors) {
        toast.error("Validasi gagal", Object.values(errors).flat().join(". "))
      } else {
        toast.error("Gagal menyimpan", detail ?? "Coba lagi nanti")
      }
      throw err
    }
  }

  if (isEdit && loadingAdmin) {
    return (
      <div className="flex min-h-[200px] items-center justify-center px-6 py-8">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    )
  }

  if (isEdit && !admin && !loadingAdmin) {
    return (
      <div className="px-6 py-8">
        <p className="text-destructive">Admin tidak ditemukan.</p>
        <Button variant="link" asChild>
          <Link to={BASE_PATH}>Kembali ke daftar</Link>
        </Button>
      </div>
    )
  }

  const isSubmitting =
    createMutation.isPending || updateMutation.isPending
  const pageTitle = isEdit ? "Edit Admin" : "Tambah Admin"
  const breadcrumbItems = isEdit
    ? [
        { label: "Dashboard", href: "/" },
        { label: "Daftar Admin", href: BASE_PATH },
        { label: "Edit" },
      ]
    : [
        { label: "Dashboard", href: "/" },
        { label: "Daftar Admin", href: BASE_PATH },
        { label: "Tambah Baru" },
      ]

  return (
    <div className="w-full px-6 py-6 md:px-8 md:py-8">
      <div className="w-full">
        <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div className="flex flex-col gap-2">
            <BreadcrumbNav items={breadcrumbItems} />
            <h1 className="text-2xl font-bold">{pageTitle}</h1>
            <p className="text-muted-foreground">
              {isEdit
                ? "Perbarui data admin"
                : "Tambah pengguna baru dengan peran Admin"}
            </p>
          </div>
          <Button variant="ghost" size="sm" className="w-fit cursor-pointer" asChild>
            <Link to={BASE_PATH}>
              <IconArrowLeft className="mr-2 size-4" />
              Kembali
            </Link>
          </Button>
        </div>

        <div
          className={
            isEdit
              ? "grid gap-8 lg:grid-cols-[1fr_400px] xl:grid-cols-[1fr_420px]"
              : "max-w-2xl"
          }
        >
          <div className="min-w-0">
            <AdminForm
              admin={admin ?? null}
              onSubmit={handleSubmit}
              isSubmitting={isSubmitting}
            />
          </div>
          {isEdit && admin && (
            <div className="flex flex-col gap-6 lg:min-w-0">
              <AdminEditSidebar admin={admin} />
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
