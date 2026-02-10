/**
 * Company form page - shared for create and edit.
 * /perusahaan/new (create) and /perusahaan/:id/edit (edit)
 */

import { Link, useNavigate, useParams } from "react-router-dom"
import { IconArrowLeft } from "@tabler/icons-react"

import { CompanyForm } from "@/components/companies/company-form"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  useCompanyQuery,
  useCreateCompanyMutation,
  useUpdateCompanyMutation,
  useDeactivateCompanyMutation,
  useActivateCompanyMutation,
  useSendVerificationEmailMutation,
  useSendPasswordResetMutation,
} from "@/hooks/use-companies-query"
import { toast } from "@/lib/toast"
import type { CompanyUser } from "@/types/company"

const BASE_PATH = "/perusahaan"

function formatDate(value: string | null) {
  if (!value) return "-"
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  })
}

function CompanyEditSidebar({ company }: { company: CompanyUser }) {
  const deactivateMutation = useDeactivateCompanyMutation()
  const activateMutation = useActivateCompanyMutation()
  const sendVerificationMutation = useSendVerificationEmailMutation()
  const sendPasswordResetMutation = useSendPasswordResetMutation()

  const handleToggleActive = async () => {
    try {
      if (company.is_active) {
        await deactivateMutation.mutateAsync(company.id)
        toast.success("Perusahaan dinonaktifkan", "Akun tidak dapat login")
      } else {
        await activateMutation.mutateAsync(company.id)
        toast.success("Perusahaan diaktifkan", "Akun dapat login kembali")
      }
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error("Gagal", res?.response?.data?.detail ?? "Coba lagi nanti")
    }
  }

  const handleSendVerification = async () => {
    try {
      await sendVerificationMutation.mutateAsync(company.id)
      toast.success(
        "Email terkirim",
        "Email verifikasi telah dikirim ke " + company.email
      )
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error(
        "Gagal mengirim",
        res?.response?.data?.detail ?? "Coba lagi nanti"
      )
    }
  }

  const handleSendPasswordReset = async () => {
    try {
      await sendPasswordResetMutation.mutateAsync(company.id)
      toast.success(
        "Email terkirim",
        "Email reset password telah dikirim ke " + company.email
      )
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error(
        "Gagal mengirim",
        res?.response?.data?.detail ?? "Coba lagi nanti"
      )
    }
  }

  return (
    <div className="flex flex-col gap-6">
      {/* Status: Aktif / Nonaktif */}
      <Card>
        <CardHeader>
          <CardTitle>Status Akun</CardTitle>
          <CardDescription>
            {company.is_active
              ? "Akun aktif dan dapat login"
              : "Akun nonaktif dan tidak dapat login"}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button
            type="button"
            variant={company.is_active ? "destructive" : "default"}
            className={
              company.is_active
                ? "cursor-pointer"
                : "cursor-pointer border-green-600 bg-green-600 hover:bg-green-700 hover:text-white"
            }
            onClick={handleToggleActive}
            disabled={
              deactivateMutation.isPending || activateMutation.isPending
            }
          >
            {company.is_active ? "Nonaktifkan" : "Aktifkan"}
          </Button>
        </CardContent>
      </Card>

      {/* Send email verification */}
      <Card>
        <CardHeader>
          <CardTitle>Email Verifikasi</CardTitle>
          <CardDescription>
            Kirim email verifikasi ke {company.email}. Hanya untuk akun yang belum
            terverifikasi.
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
              company.email_verified || sendVerificationMutation.isPending
            }
          >
            Kirim Email Verifikasi
          </Button>
        </CardContent>
      </Card>

      {/* Send password reset */}
      <Card>
        <CardHeader>
          <CardTitle>Reset Password</CardTitle>
          <CardDescription>
            Kirim email reset password ke {company.email}. Pengguna akan menerima
            tautan untuk mengganti password.
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
            Kirim Email Reset Password
          </Button>
        </CardContent>
      </Card>

      {/* Metadata */}
      <Card>
        <CardHeader>
          <CardTitle>Metadata</CardTitle>
          <CardDescription>Informasi sistem terkait perusahaan ini</CardDescription>
        </CardHeader>
        <CardContent>
          <dl className="space-y-4 text-sm">
            <div>
              <dt className="text-muted-foreground">ID</dt>
              <dd className="font-medium">{company.id}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Peran</dt>
              <dd className="font-medium">{company.role}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Tanggal Bergabung</dt>
              <dd className="font-medium">{formatDate(company.date_joined)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Diperbarui pada</dt>
              <dd className="font-medium">{formatDate(company.updated_at)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Email diverifikasi pada</dt>
              <dd className="font-medium">{formatDate(company.email_verified_at)}</dd>
            </div>
          </dl>
        </CardContent>
      </Card>
    </div>
  )
}

export function CompanyCompanyFormPage() {
  const navigate = useNavigate()
  const { id } = useParams<{ id: string }>()
  const isEdit = id !== "new" && id != null
  const companyId = isEdit ? parseInt(id, 10) : null

  const { data: company, isLoading: loadingCompany } = useCompanyQuery(
    companyId ?? null,
    isEdit
  )
  const createMutation = useCreateCompanyMutation()
  const updateMutation = useUpdateCompanyMutation(companyId ?? 0)

  const handleSubmit = async (values: {
    email: string
    company_name?: string
    contact_phone?: string
    address?: string
    password?: string
    is_active?: boolean
    email_verified?: boolean
  }) => {
    try {
      if (isEdit && companyId) {
        await updateMutation.mutateAsync({
          email: values.email,
          company_profile: {
            company_name: values.company_name,
            contact_phone: values.contact_phone,
            address: values.address,
          },
        })
        toast.success("Perusahaan diperbarui", "Perubahan berhasil disimpan")
        navigate(BASE_PATH)
      } else {
        await createMutation.mutateAsync({
          email: values.email,
          password: values.password!,
          company_profile: {
            company_name: values.company_name!,
            contact_phone: values.contact_phone,
            address: values.address,
          },
          is_active: true,
          email_verified: false,
        })
        toast.success("Perusahaan ditambahkan", "Perusahaan baru berhasil dibuat")
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

  if (isEdit && loadingCompany) {
    return (
      <div className="flex min-h-[200px] items-center justify-center px-6 py-8">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    )
  }

  if (isEdit && !company && !loadingCompany) {
    return (
      <div className="px-6 py-8">
        <p className="text-destructive">Perusahaan tidak ditemukan.</p>
        <Button variant="link" asChild>
          <Link to={BASE_PATH}>Kembali ke daftar</Link>
        </Button>
      </div>
    )
  }

  const isSubmitting =
    createMutation.isPending || updateMutation.isPending
  const pageTitle = isEdit ? "Edit Perusahaan" : "Tambah Perusahaan"
  const breadcrumbItems = isEdit
    ? [
        { label: "Dashboard", href: "/" },
        { label: "Daftar Perusahaan", href: BASE_PATH },
        { label: "Edit" },
      ]
    : [
        { label: "Dashboard", href: "/" },
        { label: "Daftar Perusahaan", href: BASE_PATH },
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
                ? "Perbarui data perusahaan"
                : "Tambah pengguna baru dengan peran Perusahaan"}
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
            <CompanyForm
              company={company ?? null}
              onSubmit={handleSubmit}
              isSubmitting={isSubmitting}
            />
          </div>
          {isEdit && company && (
            <div className="flex flex-col gap-6 lg:min-w-0">
              <CompanyEditSidebar company={company} />
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

