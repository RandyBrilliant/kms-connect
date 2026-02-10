/**
 * Shared company form for create and edit.
 * Displays all fields from backend CompanyUserSerializer.
 */

import { useState } from "react"
import { useForm } from "@tanstack/react-form"
import { IconEye, IconEyeOff } from "@tabler/icons-react"

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { PhoneInput } from "@/components/ui/phone-input"
import { cn } from "@/lib/utils"
import type { CompanyUser } from "@/types/company"
import { companyCreateSchema, companyUpdateSchema } from "@/schemas/company"
import type { CompanyCreateSchema } from "@/schemas/company"

interface CompanyFormProps {
  company?: CompanyUser | null
  onSubmit: (values: {
    email: string
    company_name?: string
    contact_phone?: string
    address?: string
    password?: string
    is_active?: boolean
    email_verified?: boolean
  }) => Promise<void>
  isSubmitting?: boolean
}

type CompanyFormValues = {
  email: string
  company_name: string
  contact_phone: string
  address: string
  password: string
  confirmPassword: string
}

function PasswordInput({
  id,
  value,
  onChange,
  placeholder,
  showPassword,
  onToggleVisibility,
  error,
  disabled,
}: {
  id: string
  value: string
  onChange: (value: string) => void
  placeholder: string
  showPassword: boolean
  onToggleVisibility: () => void
  error?: string
  disabled?: boolean
}) {
  return (
    <>
      <div className="relative">
        <Input
          id={id}
          type={showPassword ? "text" : "password"}
          placeholder={placeholder}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          disabled={disabled}
          autoComplete="new-password"
          className={cn("pr-10", error && "border-destructive")}
        />
        <button
          type="button"
          onClick={onToggleVisibility}
          className="text-muted-foreground hover:text-foreground absolute right-3 top-1/2 -translate-y-1/2 cursor-pointer"
          tabIndex={-1}
          aria-label={showPassword ? "Sembunyikan password" : "Tampilkan password"}
        >
          {showPassword ? (
            <IconEyeOff className="size-4" />
          ) : (
            <IconEye className="size-4" />
          )}
        </button>
      </div>
      {error && <FieldError errors={[{ message: error }]} />}
    </>
  )
}

export function CompanyForm({
  company,
  onSubmit,
  isSubmitting = false,
}: CompanyFormProps) {
  const isEdit = !!company
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
  const [errors, setErrors] = useState<
    Partial<Record<keyof CompanyFormValues, string>>
  >({})

  const form = useForm({
    defaultValues: {
      email: company?.email ?? "",
      company_name: company?.company_profile?.company_name ?? "",
      contact_phone: company?.company_profile?.contact_phone ?? "",
      address: company?.company_profile?.address ?? "",
      password: "",
      confirmPassword: "",
    },
    onSubmit: async ({ value }) => {
      setErrors({})

      if (isEdit) {
        const result = companyUpdateSchema.safeParse({
          email: value.email,
          company_name: value.company_name || undefined,
          contact_phone: value.contact_phone || undefined,
          address: value.address || undefined,
        })
        if (!result.success) {
          const errs: Partial<Record<keyof CompanyFormValues, string>> = {}
          for (const issue of result.error.issues) {
            const path = issue.path[0] as keyof CompanyFormValues
            if (path) errs[path] = issue.message
          }
          setErrors(errs)
          return
        }
        await onSubmit({
          email: result.data.email,
          company_name: result.data.company_name,
          contact_phone: result.data.contact_phone,
          address: result.data.address,
        })
        return
      }

      const result = companyCreateSchema.safeParse(value)
      if (!result.success) {
        const errs: Partial<Record<keyof CompanyFormValues, string>> = {}
        for (const issue of result.error.issues) {
          const path = issue.path[0] as keyof CompanyFormValues
          if (path) errs[path] = issue.message
        }
        setErrors(errs)
        return
      }

      const payload = result.data as CompanyCreateSchema
      const submitData = {
        email: payload.email,
        company_name: payload.company_name,
        contact_phone: payload.contact_phone || undefined,
        address: payload.address || undefined,
        password: payload.password,
        is_active: true,
        email_verified: false,
      }
      await onSubmit(submitData)
    },
  })

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault()
        e.stopPropagation()
        void form.handleSubmit()
      }}
      className="flex flex-col gap-6"
    >
      <Card>
        <CardHeader>
          <CardTitle>Informasi Perusahaan</CardTitle>
          <CardDescription>
            {isEdit
              ? "Perbarui data perusahaan."
              : "Masukkan informasi akun perusahaan baru. Field yang ditandai dengan * wajib diisi."}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FieldGroup>
            <form.Field
              name="company_name"
            >
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    Nama Perusahaan <span className="text-destructive">*</span>
                  </FieldLabel>
                  <Input
                    id={field.name}
                    type="text"
                    placeholder="Contoh: PT KMS Connect Indonesia"
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                    onBlur={field.handleBlur}
                  />
                  <FieldError>
                    {(() => {
                      const [err] = field.state.meta.errors as unknown[]
                      if (!err) return errors.company_name
                      if (typeof err === "string") return err
                      return (err as { message?: string }).message ?? errors.company_name
                    })()}
                  </FieldError>
                </Field>
              )}
            </form.Field>

            <form.Field name="contact_phone">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Telepon</FieldLabel>
                  <PhoneInput
                    id={field.name}
                    placeholder="Contoh: +62 812 3456 7890"
                    value={field.state.value}
                    onChange={(val) => field.handleChange(val)}
                    onBlur={field.handleBlur}
                  />
                  <FieldError>
                    {(() => {
                      const [err] = field.state.meta.errors as unknown[]
                      if (!err) return errors.contact_phone
                      if (typeof err === "string") return err
                      return (err as { message?: string }).message ?? errors.contact_phone
                    })()}
                  </FieldError>
                </Field>
              )}
            </form.Field>

            <form.Field name="address">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Alamat</FieldLabel>
                  <Input
                    id={field.name}
                    type="text"
                    placeholder="Alamat lengkap perusahaan"
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                    onBlur={field.handleBlur}
                  />
                  <FieldError>
                    {(() => {
                      const [err] = field.state.meta.errors as unknown[]
                      if (!err) return errors.address
                      if (typeof err === "string") return err
                      return (err as { message?: string }).message ?? errors.address
                    })()}
                  </FieldError>
                </Field>
              )}
            </form.Field>

            <form.Field
              name="email"
            >
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    Email <span className="text-destructive">*</span>
                  </FieldLabel>
                  <Input
                    id={field.name}
                    type="email"
                    placeholder="Contoh: hr@company.com"
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                    onBlur={field.handleBlur}
                  />
                  <FieldError>
                    {(() => {
                      const err = field.state.meta.errors[0]
                      if (!err) return errors.email
                      if (typeof err === "string") return err
                      return (err as { message?: string }).message ?? errors.email
                    })()}
                  </FieldError>
                </Field>
              )}
            </form.Field>

            {!isEdit && (
              <div className="flex flex-col gap-6">
                <form.Field
                  name="password"
                >
                  {(field) => (
                    <Field>
                  <FieldLabel htmlFor={field.name} className="mb-2 block">
                    Password <span className="text-destructive">*</span>
                  </FieldLabel>
                  <PasswordInput
                    id={field.name}
                    value={field.state.value}
                    onChange={(v) => field.handleChange(v)}
                    placeholder="Min. 8 karakter"
                    showPassword={showPassword}
                    onToggleVisibility={() => setShowPassword((p) => !p)}
                    error={
                      (() => {
                        const err = field.state.meta.errors[0]
                        if (!err) return errors.password
                        if (typeof err === "string") return err
                        return (err as { message?: string }).message ?? errors.password
                      })()
                    }
                  />
                    </Field>
                  )}
                </form.Field>
                <form.Field
                  name="confirmPassword"
                >
                  {(field) => (
                    <Field>
                      <FieldLabel htmlFor={field.name} className="mb-2 block">
                        Konfirmasi Password{" "}
                        <span className="text-destructive">*</span>
                      </FieldLabel>
                  <PasswordInput
                    id={field.name}
                    value={field.state.value}
                    onChange={(v) => field.handleChange(v)}
                    placeholder="Ulangi password"
                    showPassword={showConfirmPassword}
                    onToggleVisibility={() =>
                      setShowConfirmPassword((p) => !p)
                    }
                    error={
                      (() => {
                        const err = field.state.meta.errors[0]
                        if (!err) return errors.confirmPassword
                        if (typeof err === "string") return err
                        return (err as { message?: string }).message ?? errors.confirmPassword
                      })()
                    }
                  />
                    </Field>
                  )}
                </form.Field>
              </div>
            )}
          </FieldGroup>
        </CardContent>
      </Card>

      <div className="flex gap-2">
        <Button type="submit" disabled={isSubmitting} className="cursor-pointer">
          {isSubmitting
            ? "Menyimpan..."
            : isEdit
              ? "Simpan Perubahan"
              : "Tambah Perusahaan"}
        </Button>
      </div>
    </form>
  )
}

