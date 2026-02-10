/**
 * Shared job form for create and edit.
 * Fields: title, slug, company, location, description, requirements, type, salary, status, dates.
 */

import { useEffect, useMemo, useState } from "react"
import { useForm } from "@tanstack/react-form"
import { format } from "date-fns"
import { id } from "date-fns/locale"

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { DatePicker } from "@/components/ui/date-picker"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { useCompaniesQuery } from "@/hooks/use-companies-query"
import type { JobItem, JobStatus, EmploymentType } from "@/types/jobs"
import type { CompanyUser } from "@/types/company"

interface JobFormProps {
  job?: JobItem | null
  onSubmit: (values: {
    title: string
    slug: string
    company: number
    location_country: string
    location_city: string
    description: string
    requirements: string
    employment_type: EmploymentType
    salary_min: number | null
    salary_max: number | null
    currency: string
    status: JobStatus
    posted_at?: string | null
    deadline?: string | null
  }) => Promise<void>
  isSubmitting?: boolean
}

type JobFormValues = {
  title: string
  slug: string
  company_profile_id: number | null
  location_country: string
  location_city: string
  description: string
  requirements: string
  employment_type: EmploymentType
  salary_min: string
  salary_max: string
  currency: string
  status: JobStatus
  posted_at: Date | null
  deadline: Date | null
}

function formatDateTime(value: string | null) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy HH:mm", { locale: id })
}

function slugify(value: string): string {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/g, "")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
}

export function JobForm({
  job,
  onSubmit,
  isSubmitting = false,
}: JobFormProps) {
  const isEdit = !!job
  const [errors, setErrors] = useState<Partial<Record<keyof JobFormValues, string>>>({})

  const { data: companiesData } = useCompaniesQuery({
    page: 1,
    page_size: 100,
    ordering: "company_profile__company_name",
  })

  const companyOptions = useMemo(
    () =>
      (companiesData?.results ?? []).filter(
        (c): c is CompanyUser & { company_profile: NonNullable<CompanyUser["company_profile"]> } =>
          !!c.company_profile
      ),
    [companiesData]
  )

  const form = useForm({
    defaultValues: {
      title: job?.title ?? "",
      slug: job?.slug ?? "",
      company_profile_id: job?.company ?? null,
      location_country: job?.location_country ?? "",
      location_city: job?.location_city ?? "",
      description: job?.description ?? "",
      requirements: job?.requirements ?? "",
      employment_type: job?.employment_type ?? "FULL_TIME",
      salary_min: job?.salary_min != null ? String(job.salary_min) : "",
      salary_max: job?.salary_max != null ? String(job.salary_max) : "",
      currency: job?.currency ?? "IDR",
      status: job?.status ?? "DRAFT",
      posted_at: job?.posted_at ? new Date(job.posted_at) : null,
      deadline: job?.deadline ? new Date(job.deadline) : null,
    },
    onSubmit: async ({ value }) => {
      setErrors({})

      const newErrors: Partial<Record<keyof JobFormValues, string>> = {}
      if (!value.title.trim()) newErrors.title = "Judul wajib diisi"
      if (!value.slug.trim()) newErrors.slug = "Slug wajib diisi"
      if (!value.company_profile_id) newErrors.company_profile_id = "Perusahaan wajib dipilih"
      if (!value.description.trim()) newErrors.description = "Deskripsi wajib diisi"
      if (value.posted_at && value.deadline && value.deadline < value.posted_at) {
        newErrors.deadline = "Batas akhir tidak boleh sebelum tanggal mulai diposting"
      }

      if (Object.keys(newErrors).length > 0) {
        setErrors(newErrors)
        return
      }

      const salaryMin = value.salary_min.trim()
      const salaryMax = value.salary_max.trim()

      await onSubmit({
        title: value.title.trim(),
        slug: value.slug.trim(),
        company: value.company_profile_id!,
        location_country: value.location_country.trim(),
        location_city: value.location_city.trim(),
        description: value.description,
        requirements: value.requirements,
        employment_type: value.employment_type,
        salary_min: salaryMin ? Number(salaryMin) : null,
        salary_max: salaryMax ? Number(salaryMax) : null,
        currency: value.currency.trim() || "IDR",
        status: value.status,
        posted_at: value.posted_at ? value.posted_at.toISOString() : null,
        deadline: value.deadline ? value.deadline.toISOString() : null,
      })
    },
  })

  // Ensure company_profile_id aligns with loaded companies when editing
  useEffect(() => {
    if (isEdit && job && job.company && !form.state.values.company_profile_id) {
      form.setFieldValue("company_profile_id", job.company)
    }
  }, [isEdit, job, form])

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
          <CardTitle>Informasi Lowongan</CardTitle>
          <CardDescription>
            {isEdit
              ? "Perbarui judul, perusahaan, dan detail lowongan kerja."
              : "Masukkan informasi untuk lowongan kerja baru. Field dengan * wajib diisi."}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FieldGroup>
            <form.Field name="title">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    Judul Lowongan <span className="text-destructive">*</span>
                  </FieldLabel>
                  <Input
                    id={field.name}
                    type="text"
                    placeholder="Contoh: Caregiver Taiwan"
                    value={field.state.value}
                    onChange={(e) => {
                      const nextTitle = e.target.value
                      field.handleChange(nextTitle)
                      const currentSlug = form.state.values.slug
                      if (!currentSlug || currentSlug === slugify(field.state.value)) {
                        form.setFieldValue("slug", slugify(nextTitle))
                      }
                    }}
                  />
                  <FieldError
                    errors={errors.title ? [{ message: errors.title }] : []}
                  />
                </Field>
              )}
            </form.Field>

            <form.Field name="slug">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    Slug <span className="text-destructive">*</span>
                  </FieldLabel>
                  <Input
                    id={field.name}
                    type="text"
                    placeholder="contoh: caregiver-taiwan"
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                  />
                  <FieldError
                    errors={errors.slug ? [{ message: errors.slug }] : []}
                  />
                </Field>
              )}
            </form.Field>

            <form.Field name="company_profile_id">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    Perusahaan <span className="text-destructive">*</span>
                  </FieldLabel>
                  <Select
                    value={field.state.value ? String(field.state.value) : ""}
                    onValueChange={(v) => field.handleChange(Number(v))}
                  >
                    <SelectTrigger id={field.name} className="w-full cursor-pointer">
                      <SelectValue placeholder="Pilih perusahaan" />
                    </SelectTrigger>
                    <SelectContent>
                      {companyOptions.map((company) => (
                        <SelectItem
                          key={company.company_profile.id}
                          value={String(company.company_profile.id)}
                        >
                          {company.company_profile.company_name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FieldError
                    errors={
                      errors.company_profile_id
                        ? [{ message: errors.company_profile_id }]
                        : []
                    }
                  />
                </Field>
              )}
            </form.Field>

            <form.Field name="location_country">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Negara Penempatan</FieldLabel>
                  <Input
                    id={field.name}
                    type="text"
                    placeholder="Contoh: Taiwan"
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                  />
                </Field>
              )}
            </form.Field>

            <form.Field name="location_city">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Kota / Area</FieldLabel>
                  <Input
                    id={field.name}
                    type="text"
                    placeholder="Contoh: Taipei"
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                  />
                </Field>
              )}
            </form.Field>

            <form.Field name="description">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    Deskripsi Pekerjaan <span className="text-destructive">*</span>
                  </FieldLabel>
                  <Textarea
                    id={field.name}
                    placeholder="Jelaskan tugas utama dan tanggung jawab pekerja."
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                    rows={6}
                  />
                  <FieldError
                    errors={errors.description ? [{ message: errors.description }] : []}
                  />
                </Field>
              )}
            </form.Field>

            <form.Field name="requirements">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Persyaratan</FieldLabel>
                  <Textarea
                    id={field.name}
                    placeholder="Tuliskan kualifikasi, pengalaman, dan syarat khusus lainnya."
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                    rows={4}
                  />
                </Field>
              )}
            </form.Field>
          </FieldGroup>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Pengaturan & Benefit</CardTitle>
          <CardDescription>
            Atur jenis hubungan kerja, gaji, mata uang, dan status lowongan.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FieldGroup>
            <form.Field name="employment_type">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Jenis Kerja</FieldLabel>
                  <Select
                    value={field.state.value}
                    onValueChange={(v) => field.handleChange(v as EmploymentType)}
                  >
                    <SelectTrigger id={field.name} className="w-[200px] cursor-pointer">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="FULL_TIME">Penuh waktu</SelectItem>
                      <SelectItem value="PART_TIME">Paruh waktu</SelectItem>
                      <SelectItem value="CONTRACT">Kontrak</SelectItem>
                      <SelectItem value="INTERNSHIP">Magang</SelectItem>
                    </SelectContent>
                  </Select>
                </Field>
              )}
            </form.Field>

            <div className="grid gap-4 md:grid-cols-3">
              <form.Field name="salary_min">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Gaji Minimum</FieldLabel>
                    <Input
                      id={field.name}
                      type="number"
                      min={0}
                      placeholder="Contoh: 8000000"
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                    />
                  </Field>
                )}
              </form.Field>
              <form.Field name="salary_max">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Gaji Maksimum</FieldLabel>
                    <Input
                      id={field.name}
                      type="number"
                      min={0}
                      placeholder="Opsional"
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                    />
                  </Field>
                )}
              </form.Field>
              <form.Field name="currency">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Mata Uang</FieldLabel>
                    <Input
                      id={field.name}
                      type="text"
                      placeholder="Contoh: IDR, TWD"
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value.toUpperCase())}
                    />
                  </Field>
                )}
              </form.Field>
            </div>

            <form.Field name="status">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Status</FieldLabel>
                  <Select
                    value={field.state.value}
                    onValueChange={(v) => field.handleChange(v as JobStatus)}
                  >
                    <SelectTrigger id={field.name} className="w-[200px] cursor-pointer">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="DRAFT">Draf</SelectItem>
                      <SelectItem value="OPEN">Dibuka</SelectItem>
                      <SelectItem value="CLOSED">Ditutup</SelectItem>
                      <SelectItem value="ARCHIVED">Diarsipkan</SelectItem>
                    </SelectContent>
                  </Select>
                </Field>
              )}
            </form.Field>

            <div className="grid gap-4 md:grid-cols-2">
              <form.Field name="posted_at">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Tanggal Mulai Diposting</FieldLabel>
                    <DatePicker
                      date={field.state.value}
                      onDateChange={(d) => field.handleChange(d)}
                      placeholder="Pilih tanggal mulai"
                    />
                    <p className="text-muted-foreground mt-1 text-xs">
                      Opsional. Jika dikosongkan dan status diubah menjadi Dibuka,
                      sistem akan mengisi otomatis.
                    </p>
                  </Field>
                )}
              </form.Field>

              <form.Field name="deadline">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Batas Akhir Lamaran</FieldLabel>
                    <DatePicker
                      date={field.state.value}
                      onDateChange={(d) => field.handleChange(d)}
                      placeholder="Pilih tanggal akhir"
                    />
                    <p className="text-muted-foreground mt-1 text-xs">
                      Setelah melewati tanggal ini, lowongan akan otomatis ditutup
                      oleh scheduler.
                    </p>
                    <FieldError
                      errors={errors.deadline ? [{ message: errors.deadline }] : []}
                    />
                  </Field>
                )}
              </form.Field>
            </div>

            {job && (
              <div className="grid gap-2 text-sm text-muted-foreground">
                <div className="flex justify-between">
                  <span>Dibuat oleh</span>
                  <span className="font-medium">
                    {job.created_by_name || "-"}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span>Dibuat pada</span>
                  <span className="font-medium">
                    {formatDateTime(job.created_at)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span>Diperbarui pada</span>
                  <span className="font-medium">
                    {formatDateTime(job.updated_at)}
                  </span>
                </div>
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
              : "Tambah Lowongan"}
        </Button>
      </div>
    </form>
  )
}

