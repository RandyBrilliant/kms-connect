/**
 * Applicant (Pelamar) create form – full biodata in one flow.
 * Uses TanStack Form. Required: email, password, full_name, nik. All other fields optional.
 */

import { useState } from "react"
import { useForm } from "@tanstack/react-form"
import { IconEye, IconEyeOff } from "@tabler/icons-react"
import { format } from "date-fns"

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
import { DatePicker } from "@/components/ui/date-picker"
import { SearchableSelect } from "@/components/ui/searchable-select"
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
import { BIODATA_SECTIONS, RequiredStar } from "./biodata-form-shared"
import { RegionAddressFields } from "./region-address-fields"
import {
  RELIGION_LABELS,
  EDUCATION_LEVEL_LABELS,
  WRITING_HAND_LABELS,
  MARITAL_STATUS_LABELS,
} from "@/constants/applicant"
import { useRegenciesQuery } from "@/hooks/use-regions-query"
import { useReferrersQuery } from "@/hooks/use-referrers-query"

interface ApplicantFormProps {
  onSubmit: (values: {
    email: string
    password: string
    full_name: string
    applicant_profile: Record<string, unknown>
  }) => Promise<void>
  isSubmitting?: boolean
}

function toNum(v: string): number | null {
  if (v === "" || v == null) return null
  const n = Number(v)
  return isNaN(n) ? null : n
}

/** Build applicant_profile from parsed create payload (omit account-only fields). */
const PROFILE_KEYS = [
  "full_name", "nik", "birth_place", "birth_date", "address", "province", "district", "village",
  "contact_phone", "gender", "sibling_count", "birth_order", "father_name", "father_age", "father_occupation",
  "mother_name", "mother_age", "mother_occupation", "spouse_name", "spouse_age", "spouse_occupation",
  "family_address", "family_province", "family_district", "family_village", "family_contact_phone",
  "religion", "education_level", "marital_status", "height_cm", "weight_kg", "writing_hand",
  "passport_number", "passport_issue_date", "passport_issue_place", "passport_expiry_date",
  "referrer", "notes",
] as const

function buildApplicantProfile(payload: ApplicantCreateSchema): Record<string, unknown> {
  const profile: Record<string, unknown> = {}
  for (const key of PROFILE_KEYS) {
    const v = payload[key]
    if (v === undefined || v === "") continue
    profile[key] = v
  }
  return profile
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

const defaultBiodata = {
  sibling_count: "",
  birth_order: "",
  father_name: "",
  father_age: "",
  father_occupation: "",
  mother_name: "",
  mother_age: "",
  mother_occupation: "",
  spouse_name: "",
  spouse_age: "",
  spouse_occupation: "",
  family_address: "",
  family_contact_phone: "",
  family_province: null as number | null,
  family_district: null as number | null,
  family_village: null as number | null,
  religion: "",
  education_level: "",
  marital_status: "",
  height_cm: "",
  weight_kg: "",
  writing_hand: "",
  passport_number: "",
  passport_issue_date: "",
  passport_issue_place: "",
  passport_expiry_date: "",
  referrer: null as number | null,
  notes: "",
  province: null as number | null,
  district: null as number | null,
  village: null as number | null,
}

export function ApplicantForm({
  onSubmit,
  isSubmitting = false,
}: ApplicantFormProps) {
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
  const [errors, setErrors] = useState<Partial<Record<string, string>>>({})
  const { data: regencies = [], isPending: regenciesLoading } = useRegenciesQuery(null)
  const { data: referrers = [], isPending: referrersLoading } = useReferrersQuery()

  const form = useForm({
    defaultValues: {
      email: "",
      password: "",
      confirmPassword: "",
      full_name: "",
      nik: "",
      birth_place: null as number | null,
      birth_date: "",
      address: "",
      contact_phone: "",
      gender: "",
      ...defaultBiodata,
    },
    onSubmit: async ({ value }) => {
      setErrors({})
      const payload = {
        ...value,
        birth_date: value.birth_date || null,
        gender: value.gender || undefined,
        sibling_count: toNum(value.sibling_count),
        birth_order: toNum(value.birth_order),
        father_age: toNum(value.father_age),
        mother_age: toNum(value.mother_age),
        spouse_age: toNum(value.spouse_age),
        height_cm: toNum(value.height_cm),
        weight_kg: toNum(value.weight_kg),
        religion: value.religion || undefined,
        education_level: value.education_level || undefined,
        marital_status: value.marital_status || undefined,
        writing_hand: value.writing_hand || undefined,
        passport_issue_date: value.passport_issue_date || null,
        passport_expiry_date: value.passport_expiry_date || null,
      }
      const result = applicantCreateSchema.safeParse(payload)
      if (!result.success) {
        const errs: Partial<Record<string, string>> = {}
        for (const issue of result.error.issues) {
          const path = issue.path[0] as string
          if (path) errs[path] = issue.message
        }
        setErrors(errs)
        return
      }
      const data = result.data as ApplicantCreateSchema
      await onSubmit({
        email: data.email,
        password: data.password,
        full_name: data.full_name,
        applicant_profile: buildApplicantProfile(data),
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
          <CardTitle>{BIODATA_SECTIONS.account.title}</CardTitle>
          <CardDescription>{BIODATA_SECTIONS.account.description}</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FieldGroup>
            <form.Field name="email">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    Email <RequiredStar field="email" />
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
                    Password <RequiredStar field="password" />
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
                    Konfirmasi Password <RequiredStar field="password" />
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
          <CardTitle>{BIODATA_SECTIONS.dataCpmi.title}</CardTitle>
          <CardDescription>{BIODATA_SECTIONS.dataCpmi.description}</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FieldGroup>
            <form.Field name="full_name">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    Nama Lengkap <RequiredStar field="full_name" />
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
                    NIK <RequiredStar field="nik" />
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
                    <SearchableSelect
                      items={regencies.map((r) => ({ id: r.id, name: r.name }))}
                      value={field.state.value}
                      onChange={(id) => field.handleChange(id)}
                      placeholder="Pilih kabupaten/kota tempat lahir"
                      clearLabel="Pilih kabupaten/kota"
                      disabled={false}
                      loading={regenciesLoading}
                      emptyMessage="Tidak ada kabupaten/kota"
                    />
                    <FieldError
                      errors={[
                        ...(field.state.meta.errors as unknown[]).map((err) =>
                          typeof err === "string" ? { message: err } : { message: (err as { message?: string }).message }
                        ),
                        ...(errors.birth_place ? [{ message: errors.birth_place }] : []),
                      ].filter(Boolean)}
                    />
                  </Field>
                )}
              </form.Field>
              <form.Field name="birth_date">
                {(field) => {
                  const selectedDate = field.state.value
                    ? new Date(field.state.value)
                    : null;
                  return (
                    <Field>
                      <FieldLabel htmlFor={field.name}>Tanggal Lahir</FieldLabel>
                      <DatePicker
                        date={selectedDate}
                        onDateChange={(d) =>
                          field.handleChange(
                            d ? format(d, "yyyy-MM-dd") : ""
                          )
                        }
                        placeholder="Pilih tanggal lahir"
                      />
                    </Field>
                  )
                }}
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
                  <FieldError
                    errors={[
                      ...(field.state.meta.errors as unknown[]).map((err) =>
                        typeof err === "string" ? { message: err } : { message: (err as { message?: string }).message }
                      ),
                      ...(errors.address ? [{ message: errors.address }] : []),
                    ].filter(Boolean)}
                  />
                </Field>
              )}
            </form.Field>

            <form.Field name="province">
              {(fp) => (
                <form.Field name="district">
                  {(fd) => (
                    <form.Field name="village">
                      {(fv) => (
                        <RegionAddressFields
                          value={{
                            province: fp.state.value ?? null,
                            district: fd.state.value ?? null,
                            village: fv.state.value ?? null,
                          }}
                          onChange={(v) => {
                            fp.handleChange(v.province)
                            fd.handleChange(v.district)
                            fv.handleChange(v.village)
                          }}
                          disabled={isSubmitting}
                        />
                      )}
                    </form.Field>
                  )}
                </form.Field>
              )}
            </form.Field>

            <form.Field name="contact_phone">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>No. HP / WA</FieldLabel>
                  <PhoneInput
                    id={field.name}
                    value={field.state.value}
                    onChange={(val) => field.handleChange(val)}
                    disabled={isSubmitting}
                    placeholder="No. HP aktif"
                  />
                </Field>
              )}
            </form.Field>

            <div className="grid gap-6 sm:grid-cols-2">
              <form.Field name="sibling_count">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Jumlah Saudara</FieldLabel>
                    <Input
                      id={field.name}
                      type="number"
                      min={0}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                    />
                  </Field>
                )}
              </form.Field>
              <form.Field name="birth_order">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Anak Ke</FieldLabel>
                    <Input
                      id={field.name}
                      type="number"
                      min={0}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                    />
                  </Field>
                )}
              </form.Field>
            </div>
          </FieldGroup>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>{BIODATA_SECTIONS.dataKeluarga.title}</CardTitle>
          <CardDescription>{BIODATA_SECTIONS.dataKeluarga.description}</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FieldGroup>
            <div className="grid gap-6 sm:grid-cols-3">
              <form.Field name="father_name">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Nama Ayah</FieldLabel>
                    <Input id={field.name} value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} onBlur={field.handleBlur} />
                  </Field>
                )}
              </form.Field>
              <form.Field name="father_age">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Umur Ayah</FieldLabel>
                    <Input id={field.name} type="number" min={0} value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} onBlur={field.handleBlur} />
                  </Field>
                )}
              </form.Field>
              <form.Field name="father_occupation">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Pekerjaan Ayah</FieldLabel>
                    <Input id={field.name} value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} onBlur={field.handleBlur} />
                  </Field>
                )}
              </form.Field>
            </div>
            <div className="grid gap-6 sm:grid-cols-3">
              <form.Field name="mother_name">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Nama Ibu</FieldLabel>
                    <Input id={field.name} value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} onBlur={field.handleBlur} />
                  </Field>
                )}
              </form.Field>
              <form.Field name="mother_age">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Umur Ibu</FieldLabel>
                    <Input id={field.name} type="number" min={0} value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} onBlur={field.handleBlur} />
                  </Field>
                )}
              </form.Field>
              <form.Field name="mother_occupation">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Pekerjaan Ibu</FieldLabel>
                    <Input id={field.name} value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} onBlur={field.handleBlur} />
                  </Field>
                )}
              </form.Field>
            </div>
            <div className="grid gap-6 sm:grid-cols-3">
              <form.Field name="spouse_name">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Nama Suami/Istri</FieldLabel>
                    <Input id={field.name} value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} onBlur={field.handleBlur} />
                  </Field>
                )}
              </form.Field>
              <form.Field name="spouse_age">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Umur Suami/Istri</FieldLabel>
                    <Input id={field.name} type="number" min={0} value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} onBlur={field.handleBlur} />
                  </Field>
                )}
              </form.Field>
              <form.Field name="spouse_occupation">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Pekerjaan Suami/Istri</FieldLabel>
                    <Input id={field.name} value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} onBlur={field.handleBlur} />
                  </Field>
                )}
              </form.Field>
            </div>
            <form.Field name="family_address">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Alamat Orangtua/Keluarga</FieldLabel>
                  <Input id={field.name} value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} onBlur={field.handleBlur} />
                </Field>
              )}
            </form.Field>
            <form.Field name="family_province">
              {(fp) => (
                <form.Field name="family_district">
                  {(fd) => (
                    <form.Field name="family_village">
                      {(fv) => (
                        <RegionAddressFields
                          value={{
                            province: fp.state.value ?? null,
                            district: fd.state.value ?? null,
                            village: fv.state.value ?? null,
                          }}
                          onChange={(v) => {
                            fp.handleChange(v.province)
                            fd.handleChange(v.district)
                            fv.handleChange(v.village)
                          }}
                          disabled={isSubmitting}
                          labelPrefix="Alamat Keluarga"
                        />
                      )}
                    </form.Field>
                  )}
                </form.Field>
              )}
            </form.Field>
            <form.Field name="family_contact_phone">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>No. HP Keluarga</FieldLabel>
                  <PhoneInput id={field.name} value={field.state.value} onChange={(val) => field.handleChange(val)} disabled={isSubmitting} placeholder="No. HP keluarga" />
                </Field>
              )}
            </form.Field>
          </FieldGroup>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>{BIODATA_SECTIONS.dataPribadi.title}</CardTitle>
          <CardDescription>{BIODATA_SECTIONS.dataPribadi.description}</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FieldGroup>
            <div className="grid gap-6 sm:grid-cols-3">
              <form.Field name="religion">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Agama</FieldLabel>
                    <Select value={field.state.value || "none"} onValueChange={(v) => field.handleChange(v === "none" ? "" : v)}>
                      <SelectTrigger className="cursor-pointer"><SelectValue placeholder="Pilih agama" /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="none">Pilih agama</SelectItem>
                        {Object.entries(RELIGION_LABELS).map(([key, label]) => (<SelectItem key={key} value={key}>{label}</SelectItem>))}
                      </SelectContent>
                    </Select>
                  </Field>
                )}
              </form.Field>
              <form.Field name="education_level">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Pendidikan Terakhir</FieldLabel>
                    <Select value={field.state.value || "none"} onValueChange={(v) => field.handleChange(v === "none" ? "" : v)}>
                      <SelectTrigger className="cursor-pointer"><SelectValue placeholder="Pilih pendidikan" /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="none">Pilih pendidikan</SelectItem>
                        {Object.entries(EDUCATION_LEVEL_LABELS).map(([key, label]) => (<SelectItem key={key} value={key}>{label}</SelectItem>))}
                      </SelectContent>
                    </Select>
                  </Field>
                )}
              </form.Field>
              <form.Field name="marital_status">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Status Pernikahan</FieldLabel>
                    <Select value={field.state.value || "none"} onValueChange={(v) => field.handleChange(v === "none" ? "" : v)}>
                      <SelectTrigger className="cursor-pointer"><SelectValue placeholder="Pilih status" /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="none">Pilih status</SelectItem>
                        {Object.entries(MARITAL_STATUS_LABELS).map(([key, label]) => (<SelectItem key={key} value={key}>{label}</SelectItem>))}
                      </SelectContent>
                    </Select>
                  </Field>
                )}
              </form.Field>
            </div>
          </FieldGroup>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>{BIODATA_SECTIONS.ciriFisik.title}</CardTitle>
          <CardDescription>{BIODATA_SECTIONS.ciriFisik.description}</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FieldGroup>
            <div className="grid gap-6 sm:grid-cols-3">
              <form.Field name="height_cm">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Tinggi Badan (cm)</FieldLabel>
                    <Input id={field.name} type="number" min={0} value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} onBlur={field.handleBlur} placeholder="Contoh: 165" />
                  </Field>
                )}
              </form.Field>
              <form.Field name="weight_kg">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Berat Badan (kg)</FieldLabel>
                    <Input id={field.name} type="number" min={0} value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} onBlur={field.handleBlur} placeholder="Contoh: 55" />
                  </Field>
                )}
              </form.Field>
              <form.Field name="writing_hand">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Tangan Menulis</FieldLabel>
                    <Select value={field.state.value || "none"} onValueChange={(v) => field.handleChange(v === "none" ? "" : v)}>
                      <SelectTrigger className="cursor-pointer"><SelectValue placeholder="Pilih tangan" /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="none">Pilih tangan</SelectItem>
                        {Object.entries(WRITING_HAND_LABELS).map(([key, label]) => (<SelectItem key={key} value={key}>{label}</SelectItem>))}
                      </SelectContent>
                    </Select>
                  </Field>
                )}
              </form.Field>
            </div>
          </FieldGroup>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>{BIODATA_SECTIONS.dataPaspor.title}</CardTitle>
          <CardDescription>{BIODATA_SECTIONS.dataPaspor.description}</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FieldGroup>
            <form.Field name="passport_number">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Nomor Paspor</FieldLabel>
                  <Input id={field.name} value={field.state.value} onChange={(e) => field.handleChange(e.target.value.toUpperCase())} onBlur={field.handleBlur} placeholder="Contoh: A1234567" />
                </Field>
              )}
            </form.Field>
            <div className="grid gap-6 sm:grid-cols-3">
              <form.Field name="passport_issue_date">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Tanggal Terbit Paspor</FieldLabel>
                    <DatePicker date={field.state.value ? new Date(field.state.value) : null} onDateChange={(d) => field.handleChange(d ? format(d, "yyyy-MM-dd") : "")} placeholder="Pilih tanggal terbit" />
                  </Field>
                )}
              </form.Field>
              <form.Field name="passport_expiry_date">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Tanggal Kadaluarsa Paspor</FieldLabel>
                    <DatePicker date={field.state.value ? new Date(field.state.value) : null} onDateChange={(d) => field.handleChange(d ? format(d, "yyyy-MM-dd") : "")} placeholder="Pilih tanggal kadaluarsa" />
                  </Field>
                )}
              </form.Field>
              <form.Field name="passport_issue_place">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Tempat Terbit Paspor</FieldLabel>
                    <Input id={field.name} value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} onBlur={field.handleBlur} placeholder="Contoh: Jakarta" />
                  </Field>
                )}
              </form.Field>
            </div>
          </FieldGroup>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>{BIODATA_SECTIONS.referrer.title}</CardTitle>
          <CardDescription>{BIODATA_SECTIONS.referrer.description}</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FieldGroup>
            <form.Field name="referrer">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Pemberi Rujukan (Staff/Admin)</FieldLabel>
                  <SearchableSelect
                    items={referrers.map((r) => ({
                      id: r.id,
                      name: r.referral_code
                        ? `${r.full_name} (${r.email}) · ${r.referral_code}`
                        : `${r.full_name} (${r.email})`,
                    }))}
                    value={field.state.value}
                    onChange={(id) => field.handleChange(id)}
                    placeholder="Pilih atau cari nama / email / kode rujukan"
                    clearLabel="Tidak ada rujukan (Admin)"
                    disabled={isSubmitting}
                    loading={referrersLoading}
                    emptyMessage="Tidak ada Staff/Admin"
                  />
                </Field>
              )}
            </form.Field>
          </FieldGroup>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>{BIODATA_SECTIONS.notes.title}</CardTitle>
          <CardDescription>{BIODATA_SECTIONS.notes.description}</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FieldGroup>
            <form.Field name="notes">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Keterangan</FieldLabel>
                  <Input id={field.name} value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} onBlur={field.handleBlur} />
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
