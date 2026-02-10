/**
 * Applicant (Pelamar) create form.
 * Uses TanStack Form. Creates CustomUser + ApplicantProfile with basic biodata.
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { cn } from "@/lib/utils"
import { applicantCreateSchema } from "@/schemas/applicant"
import type { ApplicantCreateSchema } from "@/schemas/applicant"

interface ApplicantFormProps {
  onSubmit: (values: {
    email: string
    password: string
    applicant_profile: {
      full_name: string
      nik: string
      birth_place?: string
      birth_date?: string | null
      address?: string
      contact_phone?: string
      gender?: string
    }
  }) => Promise<void>
  isSubmitting?: boolean
}

type ApplicantFormValues = {
  email: string
  password: string
  confirmPassword: string
  full_name: string
  nik: string
  birth_place: string
  birth_date: string
  address: string
  contact_phone: string
  gender: string
}

function PasswordInput({
  id,
  value,
  onChange,
  placeholder,
  showPassword,
  onToggleVisibility,
  error,
}: {
  id: string
  value: string
  onChange: (value: string) => void
  placeholder: string
  showPassword: boolean
  onToggleVisibility: () => void
  error?: string
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

export function ApplicantForm({
  onSubmit,
  isSubmitting = false,
}: ApplicantFormProps) {
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
  const [errors, setErrors] = useState<Partial<Record<keyof ApplicantFormValues, string>>>({})

  const form = useForm({
    defaultValues: {
      email: "",
      password: "",
      confirmPassword: "",
      full_name: "",
      nik: "",
      birth_place: "",
      birth_date: "",
      address: "",
      contact_phone: "",
      gender: "",
    },
    onSubmit: async ({ value }) => {
      setErrors({})

      const result = applicantCreateSchema.safeParse({
        ...value,
        birth_date: value.birth_date || null,
        gender: value.gender || undefined,
      })

      if (!result.success) {
        const errs: Partial<Record<string, string>> = {}
        for (const issue of result.error.issues) {
          const path = issue.path[0] as string
          if (path) errs[path] = issue.message
        }
        setErrors(errs)
        return
      }

      const payload = result.data as ApplicantCreateSchema
      await onSubmit({
        email: payload.email,
        password: payload.password,
        applicant_profile: {
          full_name: payload.full_name,
          nik: payload.nik,
          birth_place: payload.birth_place || undefined,
          birth_date: payload.birth_date || undefined,
          address: payload.address || undefined,
          contact_phone: payload.contact_phone || undefined,
          gender: payload.gender || undefined,
        },
      })
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
            Masukkan email dan password untuk akun pelamar. Field yang ditandai dengan{" "}
            <span className="text-destructive">*</span> wajib diisi.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FieldGroup>
            <form.Field name="email">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    Email <span className="text-destructive">*</span>
                  </FieldLabel>
                  <Input
                    id={field.name}
                    type="email"
                    placeholder="Contoh: pelamar@example.com"
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                    onBlur={field.handleBlur}
                  />
                  <FieldError
                    errors={[
                      ...(field.state.meta.errors as unknown[]).map((err) =>
                        typeof err === "string" ? { message: err } : { message: (err as { message?: string }).message }
                      ),
                      ...(errors.email ? [{ message: errors.email }] : []),
                    ].filter(Boolean)}
                  />
                </Field>
              )}
            </form.Field>

            <form.Field name="password">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
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
                      (field.state.meta.errors[0] as string | undefined) ?? errors.password
                    }
                  />
                </Field>
              )}
            </form.Field>

            <form.Field name="confirmPassword">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    Konfirmasi Password <span className="text-destructive">*</span>
                  </FieldLabel>
                  <PasswordInput
                    id={field.name}
                    value={field.state.value}
                    onChange={(v) => field.handleChange(v)}
                    placeholder="Ulangi password"
                    showPassword={showConfirmPassword}
                    onToggleVisibility={() => setShowConfirmPassword((p) => !p)}
                    error={
                      (field.state.meta.errors[0] as string | undefined) ?? errors.confirmPassword
                    }
                  />
                </Field>
              )}
            </form.Field>
          </FieldGroup>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Biodata Pelamar</CardTitle>
          <CardDescription>
            Masukkan data biodata dasar. Field yang ditandai dengan{" "}
            <span className="text-destructive">*</span> wajib diisi.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FieldGroup>
            <form.Field name="full_name">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    Nama Lengkap <span className="text-destructive">*</span>
                  </FieldLabel>
                  <Input
                    id={field.name}
                    type="text"
                    placeholder="Nama sesuai KTP"
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                    onBlur={field.handleBlur}
                  />
                  <FieldError
                    errors={[
                      ...(field.state.meta.errors as unknown[]).map((err) =>
                        typeof err === "string" ? { message: err } : { message: (err as { message?: string }).message }
                      ),
                      ...(errors.full_name ? [{ message: errors.full_name }] : []),
                    ].filter(Boolean)}
                  />
                </Field>
              )}
            </form.Field>

            <form.Field name="nik">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    NIK <span className="text-destructive">*</span>
                  </FieldLabel>
                  <Input
                    id={field.name}
                    type="text"
                    placeholder="16 digit NIK"
                    maxLength={16}
                    value={field.state.value}
                    onChange={(e) =>
                      field.handleChange(e.target.value.replace(/\D/g, "").slice(0, 16))
                    }
                    onBlur={field.handleBlur}
                  />
                  <FieldError
                    errors={[
                      ...(field.state.meta.errors as unknown[]).map((err) =>
                        typeof err === "string" ? { message: err } : { message: (err as { message?: string }).message }
                      ),
                      ...(errors.nik ? [{ message: errors.nik }] : []),
                    ].filter(Boolean)}
                  />
                </Field>
              )}
            </form.Field>

            <div className="grid gap-6 sm:grid-cols-2">
              <form.Field name="birth_place">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Tempat Lahir</FieldLabel>
                    <Input
                      id={field.name}
                      type="text"
                      placeholder="Kota/Kabupaten"
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                    />
                  </Field>
                )}
              </form.Field>
              <form.Field name="birth_date">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Tanggal Lahir</FieldLabel>
                    <Input
                      id={field.name}
                      type="date"
                      value={field.state.value}
                      onChange={(e) =>
                        field.handleChange(e.target.value || "")
                      }
                      onBlur={field.handleBlur}
                    />
                  </Field>
                )}
              </form.Field>
            </div>

            <form.Field name="gender">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Jenis Kelamin</FieldLabel>
                  <Select
                    value={field.state.value || "none"}
                    onValueChange={(v) =>
                      field.handleChange(v === "none" ? "" : v)
                    }
                  >
                    <SelectTrigger className="cursor-pointer">
                      <SelectValue placeholder="Pilih" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="none">Pilih</SelectItem>
                      <SelectItem value="M">Laki-laki</SelectItem>
                      <SelectItem value="F">Perempuan</SelectItem>
                      <SelectItem value="O">Lainnya</SelectItem>
                    </SelectContent>
                  </Select>
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
                    placeholder="Alamat sesuai KTP"
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                    onBlur={field.handleBlur}
                  />
                </Field>
              )}
            </form.Field>

            <form.Field name="contact_phone">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>No. HP / WA</FieldLabel>
                  <Input
                    id={field.name}
                    type="tel"
                    placeholder="08xxxxxxxxxx"
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                    onBlur={field.handleBlur}
                  />
                </Field>
              )}
            </form.Field>
          </FieldGroup>
        </CardContent>
      </Card>

      <div className="flex gap-2">
        <Button type="submit" disabled={isSubmitting} className="cursor-pointer">
          {isSubmitting ? "Menyimpan..." : "Tambah Pelamar"}
        </Button>
      </div>
    </form>
  )
}
