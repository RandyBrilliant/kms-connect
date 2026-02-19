/**
 * Biodata tab - edit ApplicantProfile fields.
 * Uses TanStack Form.
 */

import { useState } from "react"
import { useForm } from "@tanstack/react-form"

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
import { DatePicker } from "@/components/ui/date-picker"
import { PhoneInput } from "@/components/ui/phone-input"
import { applicantProfileUpdateSchema } from "@/schemas/applicant"
import type { ApplicantProfile } from "@/types/applicant"
import { format } from "date-fns"
import {
  RELIGION_LABELS,
  EDUCATION_LEVEL_LABELS,
  WRITING_HAND_LABELS,
  MARITAL_STATUS_LABELS,
} from "@/constants/applicant"
import { BIODATA_SECTIONS, RequiredStar } from "./biodata-form-shared"
import { RegionAddressFields } from "./region-address-fields"
import { SearchableSelect } from "@/components/ui/searchable-select"
import { useRegenciesQuery } from "@/hooks/use-regions-query"
import { useReferrersQuery } from "@/hooks/use-referrers-query"

interface ApplicantBiodataTabProps {
  profile: ApplicantProfile
  onSubmit: (data: Partial<ApplicantProfile>) => Promise<void>
  isSubmitting?: boolean
}

type BiodataFormValues = {
  full_name: string
  nik: string
  birth_place: number | null
  birth_date: string
  address: string
  contact_phone: string
  gender: string
  sibling_count: string
  birth_order: string
  father_name: string
  father_age: string
  father_occupation: string
  mother_name: string
  mother_age: string
  mother_occupation: string
  spouse_name: string
  spouse_age: string
  spouse_occupation: string
  family_address: string
  family_contact_phone: string
  notes: string
  province: number | null
  district: number | null
  village: number | null
  family_province: number | null
  family_district: number | null
  family_village: number | null
  religion: string
  education_level: string
  marital_status: string
  height_cm: string
  weight_kg: string
  writing_hand: string
  passport_number: string
  passport_issue_date: string
  passport_expiry_date: string
  passport_issue_place: string
  referrer: number | null
}

function toFormValues(p: ApplicantProfile): BiodataFormValues {
  return {
    full_name: p.full_name || "",
    nik: p.nik || "",
    birth_place: p.birth_place ?? null,
    birth_date: p.birth_date || "",
    address: p.address || "",
    contact_phone: p.contact_phone || "",
    gender: p.gender || "",
    sibling_count: p.sibling_count != null ? String(p.sibling_count) : "",
    birth_order: p.birth_order != null ? String(p.birth_order) : "",
    father_name: p.father_name || "",
    father_age: p.father_age != null ? String(p.father_age) : "",
    father_occupation: p.father_occupation || "",
    mother_name: p.mother_name || "",
    mother_age: p.mother_age != null ? String(p.mother_age) : "",
    mother_occupation: p.mother_occupation || "",
    spouse_name: p.spouse_name || "",
    spouse_age: p.spouse_age != null ? String(p.spouse_age) : "",
    spouse_occupation: p.spouse_occupation || "",
    family_address: p.family_address || "",
    family_contact_phone: p.family_contact_phone || "",
    notes: p.notes || "",
    province: p.province ?? null,
    district: p.district ?? null,
    village: p.village ?? null,
    family_province: p.family_province ?? null,
    family_district: p.family_district ?? null,
    family_village: p.family_village ?? null,
    religion: p.religion || "",
    education_level: p.education_level || "",
    marital_status: p.marital_status || "",
    height_cm: p.height_cm != null ? String(p.height_cm) : "",
    weight_kg: p.weight_kg != null ? String(p.weight_kg) : "",
    writing_hand: p.writing_hand || "",
    passport_number: p.passport_number || "",
    passport_issue_date: p.passport_issue_date || "",
    passport_expiry_date: p.passport_expiry_date || "",
    passport_issue_place: p.passport_issue_place || "",
    referrer: p.referrer ?? null,
  }
}

function toNum(v: string): number | null {
  if (v === "" || v == null) return null
  const n = Number(v)
  return isNaN(n) ? null : n
}

export function ApplicantBiodataTab({
  profile,
  onSubmit,
  isSubmitting = false,
}: ApplicantBiodataTabProps) {
  const [errors, setErrors] = useState<Partial<Record<string, string>>>({})
  const { data: regencies = [], isPending: regenciesLoading } = useRegenciesQuery(null)
  const { data: referrers = [], isPending: referrersLoading } = useReferrersQuery()

  const form = useForm({
    defaultValues: toFormValues(profile),
    onSubmit: async ({ value }) => {
      setErrors({})

      const payload = {
        full_name: value.full_name || undefined,
        birth_place: value.birth_place ?? undefined,
        birth_date: value.birth_date || null,
        address: value.address || undefined,
        contact_phone: value.contact_phone || undefined,
        gender: (value.gender || undefined) as "M" | "F" | "O" | undefined,
        sibling_count: toNum(value.sibling_count),
        birth_order: toNum(value.birth_order),
        father_name: value.father_name || undefined,
        father_age: toNum(value.father_age),
        father_occupation: value.father_occupation || undefined,
        mother_name: value.mother_name || undefined,
        mother_age: toNum(value.mother_age),
        mother_occupation: value.mother_occupation || undefined,
        spouse_name: value.spouse_name || undefined,
        spouse_age: toNum(value.spouse_age),
        spouse_occupation: value.spouse_occupation || undefined,
        family_address: value.family_address || undefined,
        family_contact_phone: value.family_contact_phone || undefined,
        notes: value.notes || undefined,
        province: value.province ?? undefined,
        district: value.district ?? undefined,
        village: value.village ?? undefined,
        family_province: value.family_province ?? undefined,
        family_district: value.family_district ?? undefined,
        family_village: value.family_village ?? undefined,
        religion: value.religion || undefined,
        education_level: value.education_level || undefined,
        marital_status: value.marital_status || undefined,
        height_cm: toNum(value.height_cm),
        weight_kg: toNum(value.weight_kg),
        writing_hand: value.writing_hand || undefined,
        passport_number: value.passport_number || undefined,
        passport_issue_date: value.passport_issue_date || null,
        passport_expiry_date: value.passport_expiry_date || null,
        passport_issue_place: value.passport_issue_place || undefined,
        referrer: value.referrer ?? undefined,
      }

      const result = applicantProfileUpdateSchema.safeParse(payload)
      if (!result.success) {
        const errs: Partial<Record<string, string>> = {}
        for (const issue of result.error.issues) {
          const path = issue.path[0] as string
          if (path) errs[path] = issue.message
        }
        setErrors(errs)
        return
      }

      const raw = result.data as Record<string, unknown>
      const data: Partial<ApplicantProfile> = { ...raw }
      if (raw.gender === "") data.gender = undefined
      if (raw.religion === "") data.religion = undefined
      if (raw.education_level === "") data.education_level = undefined
      if (raw.marital_status === "") data.marital_status = undefined
      if (raw.writing_hand === "") data.writing_hand = undefined
      await onSubmit(data)
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
                    maxLength={16}
                    value={field.state.value}
                    disabled
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
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                    onBlur={field.handleBlur}
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
                    <Select
                      value={field.state.value || "none"}
                      onValueChange={(v) =>
                        field.handleChange(v === "none" ? "" : v)
                      }
                    >
                      <SelectTrigger className="cursor-pointer">
                        <SelectValue placeholder="Pilih agama" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="none">Pilih agama</SelectItem>
                        {Object.entries(RELIGION_LABELS).map(([key, label]) => (
                          <SelectItem key={key} value={key}>
                            {label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </Field>
                )}
              </form.Field>

              <form.Field name="education_level">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Pendidikan Terakhir</FieldLabel>
                    <Select
                      value={field.state.value || "none"}
                      onValueChange={(v) =>
                        field.handleChange(v === "none" ? "" : v)
                      }
                    >
                      <SelectTrigger className="cursor-pointer">
                        <SelectValue placeholder="Pilih pendidikan" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="none">Pilih pendidikan</SelectItem>
                        {Object.entries(EDUCATION_LEVEL_LABELS).map(([key, label]) => (
                          <SelectItem key={key} value={key}>
                            {label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </Field>
                )}
              </form.Field>

              <form.Field name="marital_status">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Status Pernikahan</FieldLabel>
                    <Select
                      value={field.state.value || "none"}
                      onValueChange={(v) =>
                        field.handleChange(v === "none" ? "" : v)
                      }
                    >
                      <SelectTrigger className="cursor-pointer">
                        <SelectValue placeholder="Pilih status" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="none">Pilih status</SelectItem>
                        {Object.entries(MARITAL_STATUS_LABELS).map(([key, label]) => (
                          <SelectItem key={key} value={key}>
                            {label}
                          </SelectItem>
                        ))}
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
                    <Input
                      id={field.name}
                      type="number"
                      min={0}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                      placeholder="Contoh: 165"
                    />
                  </Field>
                )}
              </form.Field>

              <form.Field name="weight_kg">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Berat Badan (kg)</FieldLabel>
                    <Input
                      id={field.name}
                      type="number"
                      min={0}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                      placeholder="Contoh: 55"
                    />
                  </Field>
                )}
              </form.Field>

              <form.Field name="writing_hand">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Tangan Menulis</FieldLabel>
                    <Select
                      value={field.state.value || "none"}
                      onValueChange={(v) =>
                        field.handleChange(v === "none" ? "" : v)
                      }
                    >
                      <SelectTrigger className="cursor-pointer">
                        <SelectValue placeholder="Pilih tangan" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="none">Pilih tangan</SelectItem>
                        {Object.entries(WRITING_HAND_LABELS).map(([key, label]) => (
                          <SelectItem key={key} value={key}>
                            {label}
                          </SelectItem>
                        ))}
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
                  <Input
                    id={field.name}
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value.toUpperCase())}
                    onBlur={field.handleBlur}
                    placeholder="Contoh: A1234567"
                  />
                </Field>
              )}
            </form.Field>

            <div className="grid gap-6 sm:grid-cols-3">
              <form.Field name="passport_issue_date">
                {(field) => {
                  const selectedDate = field.state.value
                    ? new Date(field.state.value)
                    : null
                  return (
                    <Field>
                      <FieldLabel htmlFor={field.name}>Tanggal Terbit Paspor</FieldLabel>
                      <DatePicker
                        date={selectedDate}
                        onDateChange={(d) =>
                          field.handleChange(
                            d ? format(d, "yyyy-MM-dd") : ""
                          )
                        }
                        placeholder="Pilih tanggal terbit"
                      />
                    </Field>
                  )
                }}
              </form.Field>

              <form.Field name="passport_expiry_date">
                {(field) => {
                  const selectedDate = field.state.value
                    ? new Date(field.state.value)
                    : null
                  return (
                    <Field>
                      <FieldLabel htmlFor={field.name}>Tanggal Kadaluarsa Paspor</FieldLabel>
                      <DatePicker
                        date={selectedDate}
                        onDateChange={(d) =>
                          field.handleChange(
                            d ? format(d, "yyyy-MM-dd") : ""
                          )
                        }
                        placeholder="Pilih tanggal kadaluarsa"
                      />
                    </Field>
                  )
                }}
              </form.Field>

              <form.Field name="passport_issue_place">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Tempat Terbit Paspor</FieldLabel>
                    <Input
                      id={field.name}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                      placeholder="Contoh: Jakarta"
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
                    <Input
                      id={field.name}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                    />
                  </Field>
                )}
              </form.Field>
              <form.Field name="father_age">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Umur Ayah</FieldLabel>
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
              <form.Field name="father_occupation">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Pekerjaan Ayah</FieldLabel>
                    <Input
                      id={field.name}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                    />
                  </Field>
                )}
              </form.Field>
            </div>

            <div className="grid gap-6 sm:grid-cols-3">
              <form.Field name="mother_name">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Nama Ibu</FieldLabel>
                    <Input
                      id={field.name}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                    />
                  </Field>
                )}
              </form.Field>
              <form.Field name="mother_age">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Umur Ibu</FieldLabel>
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
              <form.Field name="mother_occupation">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Pekerjaan Ibu</FieldLabel>
                    <Input
                      id={field.name}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                    />
                  </Field>
                )}
              </form.Field>
            </div>

            <div className="grid gap-6 sm:grid-cols-3">
              <form.Field name="spouse_name">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Nama Suami/Istri</FieldLabel>
                    <Input
                      id={field.name}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                    />
                  </Field>
                )}
              </form.Field>
              <form.Field name="spouse_age">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Umur Suami/Istri</FieldLabel>
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
              <form.Field name="spouse_occupation">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Pekerjaan Suami/Istri</FieldLabel>
                    <Input
                      id={field.name}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                    />
                  </Field>
                )}
              </form.Field>
            </div>

            <form.Field name="family_address">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Alamat Orangtua/Keluarga</FieldLabel>
                  <Input
                    id={field.name}
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                    onBlur={field.handleBlur}
                  />
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
                  <PhoneInput
                    id={field.name}
                    value={field.state.value}
                    onChange={(val) => field.handleChange(val)}
                    disabled={isSubmitting}
                    placeholder="No. HP keluarga"
                  />
                </Field>
              )}
            </form.Field>

            <form.Field name="notes">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Keterangan</FieldLabel>
                  <Input
                    id={field.name}
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
          {isSubmitting ? "Menyimpan..." : "Simpan Biodata"}
        </Button>
      </div>
    </form>
  )
}
