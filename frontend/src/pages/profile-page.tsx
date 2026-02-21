/**
 * Profile edit page for current user (Admin, Staff, Company).
 * Uses /api/me/ to fetch and update own profile.
 */

import { useState } from "react"

import { useAuth } from "@/hooks/use-auth"
import { useMeProfileQuery, useUpdateMeProfileMutation } from "@/hooks/use-me-profile"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Field, FieldGroup, FieldLabel, FieldError } from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { PhoneInput } from "@/components/ui/phone-input"
import type { AdminUser } from "@/types/admin"
import type { StaffUser } from "@/types/staff"
import type { CompanyUser } from "@/types/company"
import { staffUpdateSchema } from "@/schemas/staff"
import { adminUpdateSchema } from "@/schemas/admin"
import { companyUpdateSchema } from "@/schemas/company"
import { toast } from "@/lib/toast"
import { usePageTitle } from "@/hooks/use-page-title"

type Role = "ADMIN" | "STAFF" | "COMPANY" | "APPLICANT"

function AdminProfileForm({ profile }: { profile: AdminUser }) {
  const [values, setValues] = useState({
    full_name: profile.full_name || "",
  })
  const [errors, setErrors] = useState<{ full_name?: string }>({})
  const updateMutation = useUpdateMeProfileMutation()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrors({})

    const result = adminUpdateSchema.safeParse({
      email: profile.email,
      full_name: values.full_name || undefined,
    })
    if (!result.success) {
      const fieldErrors: typeof errors = {}
      for (const issue of result.error.issues) {
        const path = issue.path[0]
        if (path === "full_name") fieldErrors.full_name = issue.message
      }
      setErrors(fieldErrors)
      return
    }

    try {
      await updateMutation.mutateAsync({
        full_name: result.data.full_name ?? "",
      })
      toast.success("Profil diperbarui", "Perubahan berhasil disimpan")
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error("Gagal menyimpan", res.response?.data?.detail ?? "Coba lagi nanti")
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-6">
      <Card>
        <CardHeader>
          <CardTitle>Profil Admin</CardTitle>
          <CardDescription>
            Perbarui nama lengkap Anda. Email dan peran dikelola oleh administrator.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="admin-email">Email</FieldLabel>
              <Input id="admin-email" type="email" value={profile.email} disabled readOnly />
            </Field>
            <Field>
              <FieldLabel htmlFor="admin-full-name">Nama Lengkap</FieldLabel>
              <Input
                id="admin-full-name"
                type="text"
                value={values.full_name}
                onChange={(e) =>
                  setValues((v) => ({ ...v, full_name: e.target.value }))
                }
              />
              <FieldError>
                {errors.full_name}
              </FieldError>
            </Field>
          </FieldGroup>
        </CardContent>
      </Card>
      <div>
        <Button type="submit" disabled={updateMutation.isPending} className="cursor-pointer">
          {updateMutation.isPending ? "Menyimpan..." : "Simpan Perubahan"}
        </Button>
      </div>
    </form>
  )
}

function StaffProfileForm({ profile }: { profile: StaffUser }) {
  const [values, setValues] = useState({
    full_name: profile.staff_profile?.full_name ?? "",
    contact_phone: profile.staff_profile?.contact_phone ?? "",
  })
  const [errors, setErrors] = useState<{ full_name?: string; contact_phone?: string }>({})
  const updateMutation = useUpdateMeProfileMutation()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrors({})

    const result = staffUpdateSchema.safeParse({
      email: profile.email,
      full_name: values.full_name || undefined,
      contact_phone: values.contact_phone || undefined,
    })
    if (!result.success) {
      const fieldErrors: typeof errors = {}
      for (const issue of result.error.issues) {
        const path = issue.path[0]
        if (path === "full_name") fieldErrors.full_name = issue.message
        if (path === "contact_phone") fieldErrors.contact_phone = issue.message
      }
      setErrors(fieldErrors)
      return
    }

    try {
      await updateMutation.mutateAsync({
        email: result.data.email,
        staff_profile: {
          full_name: result.data.full_name ?? "",
          contact_phone: result.data.contact_phone ?? "",
        },
      } as any)
      toast.success("Profil diperbarui", "Perubahan berhasil disimpan")
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error("Gagal menyimpan", res.response?.data?.detail ?? "Coba lagi nanti")
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-6">
      <Card>
        <CardHeader>
          <CardTitle>Profil Staff</CardTitle>
          <CardDescription>
            Perbarui nama lengkap dan nomor telepon Anda.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="staff-email">Email</FieldLabel>
              <Input id="staff-email" type="email" value={profile.email} disabled readOnly />
            </Field>
            <Field>
              <FieldLabel htmlFor="staff-full-name">Nama Lengkap</FieldLabel>
              <Input
                id="staff-full-name"
                type="text"
                value={values.full_name}
                onChange={(e) =>
                  setValues((v) => ({ ...v, full_name: e.target.value }))
                }
              />
              <FieldError>
                {errors.full_name}
              </FieldError>
            </Field>
            <Field>
              <FieldLabel htmlFor="staff-phone">Telepon</FieldLabel>
              <PhoneInput
                id="staff-phone"
                value={values.contact_phone}
                onChange={(val) =>
                  setValues((v) => ({ ...v, contact_phone: val }))
                }
              />
              <FieldError>
                {errors.contact_phone}
              </FieldError>
            </Field>
          </FieldGroup>
        </CardContent>
      </Card>
      <div>
        <Button type="submit" disabled={updateMutation.isPending} className="cursor-pointer">
          {updateMutation.isPending ? "Menyimpan..." : "Simpan Perubahan"}
        </Button>
      </div>
    </form>
  )
}

function CompanyProfileForm({ profile }: { profile: CompanyUser }) {
  const [values, setValues] = useState({
    company_name: profile.company_profile?.company_name ?? "",
    contact_phone: profile.company_profile?.contact_phone ?? "",
    address: profile.company_profile?.address ?? "",
  })
  const [errors, setErrors] = useState<{
    company_name?: string
    contact_phone?: string
    address?: string
  }>({})
  const updateMutation = useUpdateMeProfileMutation()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrors({})

    const result = companyUpdateSchema.safeParse({
      email: profile.email,
      company_name: values.company_name || undefined,
      contact_phone: values.contact_phone || undefined,
      address: values.address || undefined,
    })
    if (!result.success) {
      const fieldErrors: typeof errors = {}
      for (const issue of result.error.issues) {
        const path = issue.path[0]
        if (path === "company_name") fieldErrors.company_name = issue.message
        if (path === "contact_phone") fieldErrors.contact_phone = issue.message
        if (path === "address") fieldErrors.address = issue.message
      }
      setErrors(fieldErrors)
      return
    }

    try {
      await updateMutation.mutateAsync({
        email: result.data.email,
        company_profile: {
          company_name: result.data.company_name ?? "",
          contact_phone: result.data.contact_phone ?? "",
          address: result.data.address ?? "",
        },
      } as any)
      toast.success("Profil diperbarui", "Perubahan berhasil disimpan")
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error("Gagal menyimpan", res.response?.data?.detail ?? "Coba lagi nanti")
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-6">
      <Card>
        <CardHeader>
          <CardTitle>Profil Perusahaan</CardTitle>
          <CardDescription>
            Perbarui nama perusahaan, nomor telepon, dan alamat.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="company-email">Email</FieldLabel>
              <Input id="company-email" type="email" value={profile.email} disabled readOnly />
            </Field>
            <Field>
              <FieldLabel htmlFor="company-name">
                Nama Perusahaan <span className="text-destructive">*</span>
              </FieldLabel>
              <Input
                id="company-name"
                type="text"
                value={values.company_name}
                onChange={(e) =>
                  setValues((v) => ({ ...v, company_name: e.target.value }))
                }
              />
              <FieldError>
                {errors.company_name}
              </FieldError>
            </Field>
            <Field>
              <FieldLabel htmlFor="company-phone">Telepon</FieldLabel>
              <PhoneInput
                id="company-phone"
                value={values.contact_phone}
                onChange={(val) =>
                  setValues((v) => ({ ...v, contact_phone: val }))
                }
              />
              <FieldError>
                {errors.contact_phone}
              </FieldError>
            </Field>
            <Field>
              <FieldLabel htmlFor="company-address">Alamat</FieldLabel>
              <Input
                id="company-address"
                type="text"
                value={values.address}
                onChange={(e) =>
                  setValues((v) => ({ ...v, address: e.target.value }))
                }
              />
              <FieldError>
                {errors.address}
              </FieldError>
            </Field>
          </FieldGroup>
        </CardContent>
      </Card>
      <div>
        <Button type="submit" disabled={updateMutation.isPending} className="cursor-pointer">
          {updateMutation.isPending ? "Menyimpan..." : "Simpan Perubahan"}
        </Button>
      </div>
    </form>
  )
}

export function ProfilePage() {
  usePageTitle("Profil Saya")
  
  const { user } = useAuth()
  const { data, isLoading, isError, error } = useMeProfileQuery()

  if (!user) {
    return null
  }

  const role = user.role as Role

  if (isLoading) {
    return (
      <div className="flex min-h-[200px] items-center justify-center px-6 py-8">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    )
  }

  if (isError || !data) {
    return (
      <div className="px-6 py-8">
        <p className="text-destructive">
          Gagal memuat profil: {(error as Error | undefined)?.message ?? "Tidak diketahui"}
        </p>
      </div>
    )
  }

  const breadcrumbItems = [
    { label: "Dashboard", href: role === "ADMIN" ? "/" : role === "STAFF" ? "/staff-portal" : "/company" },
    { label: "Profil Saya" },
  ]

  return (
    <div className="w-full px-6 py-6 md:px-8 md:py-8">
      <div className="w-full max-w-2xl">
        <div className="mb-6 flex flex-col gap-2">
          <BreadcrumbNav items={breadcrumbItems} />
          <h1 className="text-2xl font-bold">Profil Saya</h1>
          <p className="text-muted-foreground">
            Kelola informasi dasar akun Anda.
          </p>
        </div>

        {role === "ADMIN" && <AdminProfileForm profile={data as AdminUser} />}
        {role === "STAFF" && <StaffProfileForm profile={data as StaffUser} />}
        {role === "COMPANY" && <CompanyProfileForm profile={data as CompanyUser} />}
      </div>
    </div>
  )
}

