/**
 * Admin — Create or edit Interview Cohort.
 *
 * Create: `/lowongan-kerja/:id/sesi-interview/baru` — `:id` is job id.
 * Edit:   `/sesi-interview/:id/edit` — `:id` is cohort id.
 */

import { useEffect, useState } from "react"
import { useLocation, useNavigate, useParams } from "react-router-dom"
import { format } from "date-fns"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import { IconArrowLeft } from "@tabler/icons-react"

import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Switch } from "@/components/ui/switch"
import { DatePicker } from "@/components/ui/date-picker"
import { usePageTitle } from "@/hooks/use-page-title"
import { joinAdminPath, useAdminDashboard } from "@/contexts/admin-dashboard-context"
import { goBackOrDefault } from "@/lib/back-navigation"

import { getJob } from "@/api/jobs"
import {
  createInterviewCohort,
  getInterviewCohort,
  patchInterviewCohort,
} from "@/api/interview-cohorts"
import { toast } from "@/lib/toast"

function apiErrorMessage(err: unknown, fallback: string): string {
  const ax = err as {
    response?: {
      data?: { detail?: string; errors?: Record<string, unknown> }
    }
  }
  const d = ax.response?.data
  if (d?.detail && typeof d.detail === "string") return d.detail
  const errs = d?.errors
  if (errs && typeof errs === "object") {
    for (const v of Object.values(errs)) {
      if (Array.isArray(v) && v[0] != null) {
        const first = v[0]
        if (typeof first === "string") return first
      }
    }
  }
  return fallback
}

export function AdminInterviewCohortFormPage() {
  const { basePath } = useAdminDashboard()
  const { id } = useParams<{ id: string }>()
  const rawId = Number(id)
  const { pathname } = useLocation()
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const isEditMode =
    pathname.includes("/sesi-interview/") && pathname.endsWith("/edit")
  const cohortId = isEditMode ? rawId : 0
  const jobIdForCreate = !isEditMode ? rawId : 0

  const jobIdValid =
    !isEditMode && Number.isFinite(jobIdForCreate) && jobIdForCreate > 0
  const cohortIdValid =
    isEditMode && Number.isFinite(cohortId) && cohortId > 0

  const {
    data: cohort,
    isLoading: loadingCohort,
    isError: cohortError,
  } = useQuery({
    queryKey: ["interview-cohort", cohortId],
    queryFn: () => getInterviewCohort(cohortId),
    enabled: cohortIdValid,
  })

  const jobIdForQueries = isEditMode ? (cohort?.job ?? 0) : jobIdForCreate

  const { data: job, isLoading: loadingJob } = useQuery({
    queryKey: ["job", jobIdForQueries],
    queryFn: () => getJob(jobIdForQueries),
    enabled:
      (jobIdValid || (isEditMode && jobIdForQueries > 0)) &&
      Number.isFinite(jobIdForQueries) &&
      jobIdForQueries > 0,
  })

  const [name, setName] = useState("")
  const [notes, setNotes] = useState("")
  const [date, setDate] = useState<Date | null>(null)
  const [time, setTime] = useState("")
  const [location, setLocation] = useState("")
  const [interviewNotes, setInterviewNotes] = useState("")
  const [isActive, setIsActive] = useState(true)
  const [loading, setLoading] = useState(false)
  const [hydrated, setHydrated] = useState(false)

  useEffect(() => {
    if (!cohort || !isEditMode) return
    setName(cohort.name)
    setNotes(cohort.notes ?? "")
    setLocation(cohort.interview_location ?? "")
    setInterviewNotes(cohort.interview_notes ?? "")
    setIsActive(cohort.is_active)
    if (cohort.interview_date) {
      const d = new Date(cohort.interview_date)
      setDate(d)
      setTime(format(d, "HH:mm"))
    } else {
      setDate(null)
      setTime("")
    }
    setHydrated(true)
  }, [cohort, isEditMode])

  const fallbackBackPath = joinAdminPath(
    basePath,
    isEditMode && cohort
      ? `/sesi-interview/${cohort.id}`
      : `/lowongan-kerja/${jobIdForCreate}`
  )
  const handleBack = () => goBackOrDefault(navigate, fallbackBackPath)

  usePageTitle(
    isEditMode ? "Edit Sesi Interview" : "Buat Sesi Interview Baru"
  )

  const handleSubmitCreate = async () => {
    if (!jobIdValid || !name.trim()) return
    setLoading(true)
    try {
      let interviewDateIso: string | undefined
      if (date) {
        const [h, m] = time.split(":").map((v) => Number(v) || 0)
        const combined = new Date(date)
        combined.setHours(h || 0, m || 0, 0, 0)
        interviewDateIso = combined.toISOString()
      }

      const created = await createInterviewCohort({
        job: jobIdForCreate,
        name: name.trim(),
        notes: notes.trim(),
        interview_date: interviewDateIso ?? null,
        interview_location: location.trim(),
        interview_notes: interviewNotes.trim(),
      })
      await queryClient.invalidateQueries({
        queryKey: ["interview-cohorts", { job: jobIdForCreate }],
      })
      toast.success("Sesi interview berhasil dibuat.")
      navigate(joinAdminPath(basePath, `/sesi-interview/${created.id}`))
    } catch (e) {
      toast.error(
        "Gagal membuat sesi interview",
        apiErrorMessage(e, "Gagal membuat sesi interview.")
      )
    } finally {
      setLoading(false)
    }
  }

  const handleSubmitEdit = async () => {
    if (!cohortIdValid || !name.trim()) return
    setLoading(true)
    try {
      let interviewDateIso: string | null | undefined
      if (date) {
        const [h, m] = time.split(":").map((v) => Number(v) || 0)
        const combined = new Date(date)
        combined.setHours(h || 0, m || 0, 0, 0)
        interviewDateIso = combined.toISOString()
      } else {
        interviewDateIso = null
      }

      await patchInterviewCohort(cohortId, {
        name: name.trim(),
        notes: notes.trim(),
        interview_date: interviewDateIso,
        interview_location: location.trim(),
        interview_notes: interviewNotes.trim(),
        is_active: isActive,
      })
      await queryClient.invalidateQueries({
        queryKey: ["interview-cohort", cohortId],
      })
      await queryClient.invalidateQueries({
        queryKey: ["interview-cohorts", { job: cohort?.job }],
      })
      toast.success("Sesi interview diperbarui.")
      navigate(joinAdminPath(basePath, `/sesi-interview/${cohortId}`))
    } catch (e) {
      toast.error(
        "Gagal menyimpan",
        apiErrorMessage(e, "Gagal menyimpan perubahan.")
      )
    } finally {
      setLoading(false)
    }
  }

  const suggestName = () => {
    if (!date) return
    const d = format(date, "dd MMM yyyy")
    setName(`Interview ${d}${time ? ` ${time}` : ""}`)
  }

  const showForm =
    isEditMode
      ? cohort && hydrated && !loadingCohort
      : jobIdValid && job && !loadingJob

  const pageTitle = isEditMode ? "Edit Sesi Interview" : "Buat Sesi Interview Baru"

  if (isEditMode && cohortIdValid && !loadingCohort && (cohortError || !cohort)) {
    return (
      <div className="p-6">
        <p className="text-destructive">Sesi interview tidak ditemukan.</p>
        <Button
          variant="outline"
          className="mt-4 cursor-pointer"
          onClick={() =>
            goBackOrDefault(navigate, joinAdminPath(basePath, "/lowongan-kerja"))
          }
        >
          <IconArrowLeft className="mr-2 size-4" />
          Kembali
        </Button>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-6 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Lowongan Kerja", href: joinAdminPath(basePath, "/lowongan-kerja") },
          {
            label: job?.title ?? cohort?.job_title ?? "...",
            href: joinAdminPath(
              basePath,
              `/lowongan-kerja/${isEditMode ? cohort?.job : jobIdForCreate}`
            ),
          },
          ...(isEditMode && cohort
            ? [
                {
                  label: cohort.name,
                  href: joinAdminPath(basePath, `/sesi-interview/${cohort.id}`),
                },
              ]
            : []),
          { label: isEditMode ? "Edit" : "Buat Sesi Interview" },
        ]}
      />

      <div className="flex items-center gap-3">
        <Button
          variant="ghost"
          size="icon"
          className="cursor-pointer shrink-0"
          onClick={handleBack}
        >
          <IconArrowLeft className="size-5" />
        </Button>
        <div>
          <h1 className="text-2xl font-bold">{pageTitle}</h1>
          {job && (
            <p className="text-sm text-muted-foreground">
              {job.title}
              {job.company_name ? ` — ${job.company_name}` : ""}
            </p>
          )}
        </div>
      </div>

      <Card className="max-w-2xl">
        <CardHeader>
          <CardTitle>Detail Sesi Interview</CardTitle>
          <CardDescription>
            Sesi interview mengelompokkan pelamar untuk jadwal dan alur setelah
            pra-seleksi. Satu lowongan dapat punya banyak sesi.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {isEditMode && (loadingCohort || !cohortIdValid) ? (
            <div className="flex items-center justify-center py-8">
              <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : !isEditMode && !jobIdValid ? (
            <p className="text-sm text-destructive">
              ID lowongan tidak valid. Buka dari halaman lowongan dan pilih
              &quot;Buat Sesi Interview&quot;.
            </p>
          ) : !showForm ? (
            <div className="flex items-center justify-center py-8">
              <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : (
            <div className="flex flex-col gap-4">
              {isEditMode && (
                <div className="flex items-center justify-between rounded-lg border px-3 py-2">
                  <div className="flex flex-col gap-0.5">
                    <span className="text-sm font-medium">Sesi aktif</span>
                    <span className="text-muted-foreground text-xs">
                      Non-aktifkan jika sesi sudah tidak dipakai untuk penugasan
                      baru.
                    </span>
                  </div>
                  <Switch
                    checked={isActive}
                    onCheckedChange={setIsActive}
                    aria-label="Sesi aktif"
                  />
                </div>
              )}

              <div className="flex flex-col gap-1.5">
                <Label htmlFor="cohort-name">
                  Nama Sesi <span className="text-destructive">*</span>
                </Label>
                <div className="flex gap-2">
                  <Input
                    id="cohort-name"
                    placeholder="Contoh: Interview 5 Mei 2026 — Sesi Pagi"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                  />
                  <Button
                    type="button"
                    variant="outline"
                    className="cursor-pointer shrink-0"
                    onClick={suggestName}
                    disabled={!date}
                    title="Buat nama dari tanggal yang dipilih"
                  >
                    Auto
                  </Button>
                </div>
              </div>

              <div className="grid gap-3 sm:grid-cols-[2fr,1fr]">
                <div className="flex flex-col gap-1.5">
                  <Label>Tanggal Interview</Label>
                  <DatePicker
                    date={date}
                    onDateChange={setDate}
                    placeholder="Pilih tanggal (opsional)"
                  />
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="cohort-time">Jam</Label>
                  <Input
                    id="cohort-time"
                    type="time"
                    value={time}
                    onChange={(e) => setTime(e.target.value)}
                  />
                </div>
              </div>

              <div className="flex flex-col gap-1.5">
                <Label htmlFor="cohort-location">Lokasi</Label>
                <Input
                  id="cohort-location"
                  placeholder="Nama gedung / alamat / link online"
                  value={location}
                  onChange={(e) => setLocation(e.target.value)}
                />
              </div>

              <div className="flex flex-col gap-1.5">
                <Label htmlFor="cohort-iv-notes">
                  Informasi untuk Pelamar{" "}
                  <span className="text-muted-foreground text-xs">(opsional)</span>
                </Label>
                <Textarea
                  id="cohort-iv-notes"
                  placeholder="Dress code, dokumen yang dibawa, dll."
                  value={interviewNotes}
                  onChange={(e) => setInterviewNotes(e.target.value)}
                  rows={2}
                />
              </div>

              <div className="flex flex-col gap-1.5">
                <Label htmlFor="cohort-internal-notes">
                  Catatan Internal{" "}
                  <span className="text-muted-foreground text-xs">(opsional)</span>
                </Label>
                <Textarea
                  id="cohort-internal-notes"
                  placeholder="Catatan internal admin tentang sesi ini..."
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  rows={2}
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <Button
                  type="button"
                  variant="outline"
                  className="cursor-pointer"
                  onClick={handleBack}
                >
                  Batal
                </Button>
                <Button
                  type="button"
                  onClick={() =>
                    isEditMode ? void handleSubmitEdit() : void handleSubmitCreate()
                  }
                  disabled={!name.trim() || loading}
                  className="cursor-pointer"
                >
                  {loading
                    ? "Menyimpan..."
                    : isEditMode
                      ? "Simpan Perubahan"
                      : "Buat Sesi"}
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
