/**
 * Admin — Tugaskan Pelamar page.
 * Dedicated full-page form for admin-initiated job assignment.
 * Route: /lamaran/new
 *
 * Uses AsyncSearchableSelect for server-side searchable job and applicant pickers.
 */

import { useMemo, useState } from "react"
import { Link, useNavigate } from "react-router-dom"
import { useForm } from "@tanstack/react-form"
import { z } from "zod"
import { IconArrowLeft, IconInfoCircle, IconUserPlus } from "@tabler/icons-react"

import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { AsyncSearchableSelect } from "@/components/ui/searchable-select"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Field, FieldError, FieldGroup, FieldLabel } from "@/components/ui/field"
import { Textarea } from "@/components/ui/textarea"
import { useDebounce } from "@/hooks/use-debounce"
import { useJobsQuery } from "@/hooks/use-jobs-query"
import { useApplicantsQuery } from "@/hooks/use-applicants-query"
import { useAssignApplicationMutation } from "@/hooks/use-applications-query"
import { toast } from "@/lib/toast"
import { usePageTitle } from "@/hooks/use-page-title"

const BASE_PATH = "/lamaran"

// ---------------------------------------------------------------------------
// Validation schema
// ---------------------------------------------------------------------------

const formSchema = z.object({
  job: z
    .number({ error: "Pilih sebuah lowongan" })
    .int()
    .positive("Pilih sebuah lowongan"),
  applicant: z
    .number({ error: "Pilih seorang pelamar" })
    .int()
    .positive("Pilih seorang pelamar"),
  note: z.string().max(500, "Catatan maksimal 500 karakter").optional(),
})

type FormValues = z.infer<typeof formSchema>

// ---------------------------------------------------------------------------
// Helper — coerce TanStack Form's error array to { message }[]
// ---------------------------------------------------------------------------

function fieldErrors(errors: unknown[]): Array<{ message: string }> {
  return errors.map((e) => {
    if (typeof e === "string") return { message: e }
    const err = e as { message?: string }
    return { message: err?.message ?? String(e) }
  })
}

// ---------------------------------------------------------------------------
// Page component
// ---------------------------------------------------------------------------

export function AdminAssignApplicationPage() {
  usePageTitle("Tugaskan Pelamar")
  const navigate = useNavigate()

  // --- Job search ---
  const [jobSearchInput, setJobSearchInput] = useState("")
  const deferredJobSearch = useDebounce(jobSearchInput, 300)
  const { data: jobsData, isFetching: jobsFetching } = useJobsQuery({
    search: deferredJobSearch || undefined,
    status: "OPEN",
    page_size: 20,
  })

  // --- Applicant search ---
  const [applicantSearchInput, setApplicantSearchInput] = useState("")
  const deferredApplicantSearch = useDebounce(applicantSearchInput, 300)
  const { data: applicantsData, isFetching: applicantsFetching } =
    useApplicantsQuery({
      search: deferredApplicantSearch || undefined,
      page_size: 20,
    })

  // --- Mutation ---
  const assignMutation = useAssignApplicationMutation()

  // --- Map API results to SearchableSelectItem lists ---
  const jobItems = useMemo(
    () =>
      (jobsData?.results ?? []).map((j) => ({
        id: j.id,
        name: j.company_name ? `${j.title} — ${j.company_name}` : j.title,
      })),
    [jobsData]
  )

  const applicantItems = useMemo(
    () =>
      (applicantsData?.results ?? []).map((a) => ({
        // The assign endpoint expects ApplicantProfile.id, NOT ApplicantUser.id
        id: a.applicant_profile.id,
        name: a.applicant_profile?.full_name
          ? `${a.applicant_profile.full_name} (${a.email})`
          : a.email,
      })),
    [applicantsData]
  )

  // --- Form ---
  const form = useForm({
    defaultValues: {
      job: null as number | null,
      applicant: null as number | null,
      note: "",
    },
    onSubmit: async ({ value }) => {
      const result = formSchema.safeParse(value)
      if (!result.success) {
        // Zod errors surface through field-level meta — this branch handles
        // edge cases where validation passes field-level but fails at schema level.
        toast.error("Validasi gagal", "Periksa kembali isian form")
        return
      }

      try {
        await assignMutation.mutateAsync(result.data as FormValues)
        toast.success("Berhasil ditugaskan", "Lamaran baru telah dibuat")
        navigate(BASE_PATH)
      } catch (err: unknown) {
        const res = err as {
          response?: {
            data?: { errors?: Record<string, string[]>; detail?: string }
          }
        }
        const errors = res?.response?.data?.errors
        const detail = res?.response?.data?.detail
        if (errors) {
          toast.error("Validasi gagal", Object.values(errors).flat().join(". "))
        } else {
          toast.error("Gagal menyimpan", detail ?? "Coba lagi nanti")
        }
      }
    },
  })

  const isSubmitting = assignMutation.isPending

  return (
    <div className="w-full px-6 py-6 md:px-8 md:py-8">
      <div className="w-full">
        {/* Page header */}
        <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div className="flex flex-col gap-2">
            <BreadcrumbNav
              items={[
                { label: "Dashboard", href: "/" },
                { label: "Manajemen Lamaran", href: BASE_PATH },
                { label: "Tugaskan Pelamar" },
              ]}
            />
            <h1 className="text-2xl font-bold">Tugaskan Pelamar</h1>
            <p className="text-muted-foreground">
              Buat penugasan lamaran baru untuk pelamar ke sebuah lowongan
            </p>
          </div>
          <Button
            variant="ghost"
            size="sm"
            className="w-fit cursor-pointer"
            asChild
          >
            <Link to={BASE_PATH}>
              <IconArrowLeft className="mr-2 size-4" />
              Kembali
            </Link>
          </Button>
        </div>

        {/* Content: form + sidebar */}
        <div className="grid gap-8 lg:grid-cols-[1fr_360px]">
          {/* ---- Left: form ---- */}
          <div className="min-w-0">
            <Card>
              <CardHeader>
                <CardTitle>Data Penugasan</CardTitle>
                <CardDescription>
                  Pilih lowongan dan pelamar, lalu tambahkan catatan opsional
                </CardDescription>
              </CardHeader>
              <CardContent>
                <form
                  onSubmit={(e) => {
                    e.preventDefault()
                    e.stopPropagation()
                    form.handleSubmit()
                  }}
                  className="flex flex-col gap-6"
                >
                  <FieldGroup>
                    {/* Job field */}
                    <form.Field
                      name="job"
                      validators={{
                        onBlur: ({ value }) => {
                          if (!value || value <= 0) return "Pilih sebuah lowongan"
                          return undefined
                        },
                      }}
                    >
                      {(field) => (
                        <Field>
                          <FieldLabel htmlFor={field.name}>
                            Lowongan <span className="text-destructive">*</span>
                          </FieldLabel>
                          <AsyncSearchableSelect
                            items={jobItems}
                            value={field.state.value}
                            onChange={(id) => {
                              field.handleChange(id)
                              field.handleBlur()
                            }}
                            onSearchChange={setJobSearchInput}
                            loading={jobsFetching}
                            placeholder="Cari lowongan kerja..."
                            emptyMessage={
                              deferredJobSearch
                                ? "Lowongan tidak ditemukan"
                                : "Ketik untuk mencari lowongan"
                            }
                            clearable={false}
                          />
                          {field.state.meta.isTouched && (
                            <FieldError
                              errors={fieldErrors(field.state.meta.errors)}
                            />
                          )}
                        </Field>
                      )}
                    </form.Field>

                    {/* Applicant field */}
                    <form.Field
                      name="applicant"
                      validators={{
                        onBlur: ({ value }) => {
                          if (!value || value <= 0) return "Pilih seorang pelamar"
                          return undefined
                        },
                      }}
                    >
                      {(field) => (
                        <Field>
                          <FieldLabel htmlFor={field.name}>
                            Pelamar <span className="text-destructive">*</span>
                          </FieldLabel>
                          <AsyncSearchableSelect
                            items={applicantItems}
                            value={field.state.value}
                            onChange={(id) => {
                              field.handleChange(id)
                              field.handleBlur()
                            }}
                            onSearchChange={setApplicantSearchInput}
                            loading={applicantsFetching}
                            placeholder="Cari nama atau email pelamar..."
                            emptyMessage={
                              deferredApplicantSearch
                                ? "Pelamar tidak ditemukan"
                                : "Ketik untuk mencari pelamar"
                            }
                            clearable={false}
                          />
                          {field.state.meta.isTouched && (
                            <FieldError
                              errors={fieldErrors(field.state.meta.errors)}
                            />
                          )}
                        </Field>
                      )}
                    </form.Field>

                    {/* Note field */}
                    <form.Field
                      name="note"
                      validators={{
                        onChange: ({ value }) => {
                          if (value && value.length > 500)
                            return "Catatan maksimal 500 karakter"
                          return undefined
                        },
                      }}
                    >
                      {(field) => (
                        <Field>
                          <FieldLabel htmlFor={field.name}>
                            Catatan{" "}
                            <span className="text-muted-foreground font-normal">
                              (opsional)
                            </span>
                          </FieldLabel>
                          <Textarea
                            id={field.name}
                            name={field.name}
                            value={field.state.value}
                            onBlur={field.handleBlur}
                            onChange={(e) => field.handleChange(e.target.value)}
                            placeholder="Tambahkan catatan penugasan, misal: kandidat referral dari manajer..."
                            rows={4}
                            maxLength={500}
                            className="resize-none"
                          />
                          <p className="text-muted-foreground text-xs text-right">
                            {(field.state.value ?? "").length}/500
                          </p>
                          {field.state.meta.isTouched && (
                            <FieldError
                              errors={fieldErrors(field.state.meta.errors)}
                            />
                          )}
                        </Field>
                      )}
                    </form.Field>
                  </FieldGroup>

                  {/* Submit */}
                  <div className="flex items-center gap-3">
                    <Button
                      type="submit"
                      disabled={isSubmitting}
                      className="cursor-pointer"
                    >
                      <IconUserPlus className="mr-2 size-4" />
                      {isSubmitting ? "Menyimpan..." : "Tugaskan Pelamar"}
                    </Button>
                    <Button
                      type="button"
                      variant="ghost"
                      className="cursor-pointer"
                      asChild
                    >
                      <Link to={BASE_PATH}>Batal</Link>
                    </Button>
                  </div>
                </form>
              </CardContent>
            </Card>
          </div>

          {/* ---- Right: info sidebar ---- */}
          <div className="flex flex-col gap-6 lg:min-w-0">
            <Card>
              <CardHeader>
                <div className="flex items-center gap-2">
                  <IconInfoCircle className="text-muted-foreground size-5" />
                  <CardTitle className="text-base">Tentang Penugasan</CardTitle>
                </div>
              </CardHeader>
              <CardContent className="flex flex-col gap-3 text-sm text-muted-foreground">
                <p>
                  Penugasan memungkinkan admin untuk secara langsung
                  mendaftarkan seorang pelamar ke sebuah lowongan tanpa melalui
                  proses self-apply.
                </p>
                <ul className="list-disc list-inside space-y-1">
                  <li>Hanya lowongan dengan status <strong>Buka</strong> yang tersedia.</li>
                  <li>
                    Lamaran akan dibuat dengan status{" "}
                    <strong>Menunggu Tinjauan</strong>.
                  </li>
                  <li>
                    Pelamar tidak dapat mendaftar ulang ke lowongan yang sama.
                  </li>
                  <li>Chat thread akan otomatis dibuat setelah penugasan.</li>
                </ul>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </div>
  )
}
