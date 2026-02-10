/**
 * Shared admin form for create and edit.
 * Displays all fields from backend AdminUserSerializer.
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
import { cn } from "@/lib/utils"
import type { AdminUser } from "@/types/admin"
import { adminCreateSchema, adminUpdateSchema } from "@/schemas/admin"
import type { AdminCreateSchema } from "@/schemas/admin"

interface AdminFormProps {
  admin?: AdminUser | null
  onSubmit: (values: {
    email: string
    full_name?: string
    password?: string
    is_active?: boolean
    email_verified?: boolean
  }) => Promise<void>
  isSubmitting?: boolean
}

type AdminFormValues = {
  email: string
  full_name: string
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

export function AdminForm({
  admin,
  onSubmit,
  isSubmitting = false,
}: AdminFormProps) {
  const isEdit = !!admin
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
  const [errors, setErrors] = useState<
    Partial<Record<keyof AdminFormValues, string>>
  >({})

  const form = useForm({
    defaultValues: {
      email: admin?.email ?? "",
      full_name: admin?.full_name ?? "",
      password: "",
      confirmPassword: "",
    },
    onSubmit: async ({ value }) => {
      setErrors({})

      if (isEdit) {
        const result = adminUpdateSchema.safeParse({
          email: value.email,
          full_name: value.full_name || undefined,
        })
        if (!result.success) {
          const errs: Partial<Record<keyof AdminFormValues, string>> = {}
          for (const issue of result.error.issues) {
            const path = issue.path[0] as keyof AdminFormValues
            if (path) errs[path] = issue.message
          }
          setErrors(errs)
          return
        }
        await onSubmit({
          email: result.data.email,
          full_name: result.data.full_name || undefined,
        })
        return
      }

      const result = adminCreateSchema.safeParse(value)
      if (!result.success) {
        const errs: Partial<Record<keyof AdminFormValues, string>> = {}
        for (const issue of result.error.issues) {
          const path = issue.path[0] as keyof AdminFormValues
          if (path) errs[path] = issue.message
        }
        setErrors(errs)
        return
      }

      const payload = result.data as AdminCreateSchema
      const submitData = {
        email: payload.email,
        full_name: payload.full_name || undefined,
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
            <CardTitle>Informasi Akun</CardTitle>
            <CardDescription>
              {isEdit
                ? "Perbarui email admin. Password tidak dapat diubah dari sini—gunakan Kirim Email Reset Password di sisi kanan."
                : "Masukkan informasi akun admin baru. Field yang ditandai dengan * wajib diisi."}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <FieldGroup>
              <form.Field
                name="full_name"
              >
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Nama Lengkap</FieldLabel>
                    <Input
                      id={field.name}
                      type="text"
                      placeholder="Contoh: John Doe"
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                    />
                    <FieldError
                      errors={[
                        ...(field.state.meta.errors as unknown[]).map((err) => {
                          const e = err as { message?: string } | string
                          if (typeof e === "string") return { message: e }
                          return { message: e?.message ?? String(e) }
                        }),
                        ...(errors.full_name ? [{ message: errors.full_name! }] : []),
                      ]}
                    />
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
                      placeholder="Contoh: admin@example.com"
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                    />
                    <FieldError
                      errors={[
                        ...(field.state.meta.errors as unknown[]).map((err) => {
                          const e = err as { message?: string } | string
                          if (typeof e === "string") return { message: e }
                          return { message: e?.message ?? String(e) }
                        }),
                        ...(errors.email ? [{ message: errors.email! }] : []),
                      ]}
                    />
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
                : "Tambah Admin"}
          </Button>
        </div>
      </form>
  )
}
