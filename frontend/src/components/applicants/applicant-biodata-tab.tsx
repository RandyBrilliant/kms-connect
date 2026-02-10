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

interface ApplicantBiodataTabProps {
  profile: ApplicantProfile
  onSubmit: (data: Partial<ApplicantProfile>) => Promise<void>
  isSubmitting?: boolean
}

type BiodataFormValues = {
  full_name: string
  nik: string
  birth_place: string
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
}

function toFormValues(p: ApplicantProfile): BiodataFormValues {
  return {
    full_name: p.full_name || "",
    nik: p.nik || "",
    birth_place: p.birth_place || "",
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

  const form = useForm({
    defaultValues: toFormValues(profile),
    onSubmit: async ({ value }) => {
      setErrors({})

      const payload = {
        full_name: value.full_name || undefined,
        birth_place: value.birth_place || undefined,
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

      await onSubmit(result.data)
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
          <CardTitle>Data CPMI</CardTitle>
          <CardDescription>
            Data utama pelamar. Field yang ditandai dengan{" "}
            <span className="text-destructive">*</span> wajib diisi.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FieldGroup>
            <form.Field
              name="full_name"
            >
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    Nama Lengkap <span className="text-destructive">*</span>
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

            <form.Field
              name="nik"
            >
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    NIK <span className="text-destructive">*</span>
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
                    <Input
                      id={field.name}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                    />
                  </Field>
                )}
              </form.Field>
              <form.Field name="birth_date">
                {(field) => {
                  const selectedDate = field.state.value
                    ? new Date(field.state.value)
                    : null
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
          <CardTitle>Data Orangtua / Keluarga</CardTitle>
          <CardDescription>Ayah, Ibu, Suami/Istri</CardDescription>
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
