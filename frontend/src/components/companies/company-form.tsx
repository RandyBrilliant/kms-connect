/**
 * Shared company form for create and edit.
 * Displays all fields from backend CompanyUserSerializer.
 */

import { useState } from "react"
import { useForm } from "@tanstack/react-form"
import { zodValidator } from "@tanstack/zod-form-adapter"

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

export function CompanyForm({
  company,
  onSubmit,
  isSubmitting = false,
}: CompanyFormProps) {
  const isEdit = !!company
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
    validatorAdapter: zodValidator(),
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
              validators={{ onChange: companyCreateSchema.shape.company_name }}
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
              validators={{ onChange: companyCreateSchema.shape.email }}
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
                      return err.message ?? errors.email
                    })()}
                  </FieldError>
                </Field>
              )}
            </form.Field>

            {!isEdit && (
              <div className="flex flex-col gap-6">
                <form.Field
                  name="password"
                  validators={{ onChange: companyCreateSchema.shape.password }}
                >
                  {(field) => (
                    <Field>
                      <FieldLabel htmlFor={field.name} className="mb-2 block">
                        Password <span className="text-destructive">*</span>
                      </FieldLabel>
                      <Input
                        id={field.name}
                        type="password"
                        placeholder="Min. 8 karakter"
                        value={field.state.value}
                        onChange={(e) => field.handleChange(e.target.value)}
                        onBlur={field.handleBlur}
                      />
                      <FieldError>
                        {(() => {
                          const err = field.state.meta.errors[0]
                          if (!err) return errors.password
                          if (typeof err === "string") return err
                          return err.message ?? errors.password
                        })()}
                      </FieldError>
                    </Field>
                  )}
                </form.Field>
                <form.Field
                  name="confirmPassword"
                  validators={{
                    onChange: companyCreateSchema.shape.confirmPassword,
                  }}
                >
                  {(field) => (
                    <Field>
                      <FieldLabel htmlFor={field.name} className="mb-2 block">
                        Konfirmasi Password{" "}
                        <span className="text-destructive">*</span>
                      </FieldLabel>
                      <Input
                        id={field.name}
                        type="password"
                        placeholder="Ulangi password"
                        value={field.state.value}
                        onChange={(e) => field.handleChange(e.target.value)}
                        onBlur={field.handleBlur}
                      />
                      <FieldError>
                        {(() => {
                          const err = field.state.meta.errors[0]
                          if (!err) return errors.confirmPassword
                          if (typeof err === "string") return err
                          return err.message ?? errors.confirmPassword
                        })()}
                      </FieldError>
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

