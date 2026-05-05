/**
 * Admin — Interview Cohort detail page.
 *
 * The cohort is the operational unit for INTERVIEW → SELESAI lifecycle.
 * Tabs mirror the FSM stages owned by the cohort:
 *   Interview · Diterima · Berangkat · Selesai · Ditolak
 *
 * Bulk transitions, announcements, and export are scoped to this cohort.
 */

import { useEffect, useMemo, useState } from "react"
import { Link, useNavigate, useParams } from "react-router-dom"
import type { QueryClient } from "@tanstack/react-query"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import {
  IconArrowLeft,
  IconArrowRight,
  IconArrowsRightLeft,
  IconBell,
  IconCalendar,
  IconChevronDown,
  IconClipboardList,
  IconDownload,
  IconExternalLink,
  IconEye,
  IconFileSpreadsheet,
  IconSearch,
  IconMapPin,
  IconPencil,
  IconUsers,
  IconUserCheck,
} from "@tabler/icons-react"

import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/tabs"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { DatePicker } from "@/components/ui/date-picker"
import { Checkbox } from "@/components/ui/checkbox"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { ApplicationStatusBadge } from "@/components/applications/application-status-badge"
import { ApplicantAdminProcessDialog } from "@/components/applicants/applicant-admin-process-dialog"
import { ApplicantDetailPreviewDialog } from "@/components/batches/applicant-detail-preview-dialog"
import { DocumentCollectionProgressCell } from "@/components/applications/document-collection-progress-cell"
import { TransitionApplicationDialog } from "@/components/applications/transition-application-dialog"
import { CohortSelectField } from "@/components/interview-cohorts/cohort-select-field"

import {
  exportCohortExcel,
  getCohortAnnouncements,
  createCohortAnnouncement,
  getInterviewCohort,
  moveApplicationsToCohort,
  patchInterviewCohort,
  scheduleCohort,
} from "@/api/interview-cohorts"
import {
  bulkTransitionApplications,
  getAllApplicationsByCohort,
} from "@/api/applications"
import {
  APPLICATION_STATUS_LABELS,
  type ApplicationStatus,
  type JobApplication,
} from "@/types/job-applications"
import type { InterviewCohortAnnouncement } from "@/types/interview-cohort"

import { joinAdminPath, useAdminDashboard } from "@/contexts/admin-dashboard-context"
import { goBackOrDefault } from "@/lib/back-navigation"
import { toast } from "@/lib/toast"
import { usePageTitle } from "@/hooks/use-page-title"

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * After cohort applicant changes, refresh sesi tables, batch tahapan on the job,
 * and any admin application lists (job detail tabs use ["applications", { job, status }]).
 */
function invalidateCohortDashboardCaches(
  qc: QueryClient,
  opts: {
    cohortId: number
    jobId: number
    /** e.g. move-applicants target cohort */
    extraCohortIds?: number[]
  }
) {
  const cohortIds = new Set([
    opts.cohortId,
    ...(opts.extraCohortIds ?? []).filter((id) => id > 0),
  ])
  void qc.invalidateQueries({ queryKey: ["applications"] })
  for (const cid of cohortIds) {
    void qc.invalidateQueries({ queryKey: ["cohort-applications", cid] })
    void qc.invalidateQueries({ queryKey: ["interview-cohort", cid] })
  }
  void qc.invalidateQueries({ queryKey: ["interview-cohorts"] })
  void qc.invalidateQueries({ queryKey: ["batches", { job: opts.jobId }] })
}

function formatDate(value: string | null | undefined) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy HH:mm", { locale: idLocale })
}

function formatDateOnly(value: string | null | undefined) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy", { locale: idLocale })
}

function applicationMatchesStageSearch(app: JobApplication, q: string): boolean {
  const needle = q.trim().toLowerCase()
  if (!needle) return true
  const hay = [
    app.applicant_name,
    app.applicant_email,
    app.applicant_nik,
    app.referrer_display_name,
    app.referrer_code,
  ]
    .map((s) => (s || "").toLowerCase())
    .join(" ")
  return hay.includes(needle)
}

/** Kehadiran / dokumen per tab — mirrors batch detail semantics where relevant. */
function cohortKonfirmasiForTab(
  app: JobApplication,
  tabStatus: ApplicationStatus
): { sudah: boolean; waktuIso: string | null; applicable: boolean } {
  if (tabStatus === "INTERVIEW") {
    const sudah =
      Boolean(app.interview_confirmed_at) ||
      app.attendance_by_stage?.INTERVIEW === true
    const waktuIso =
      app.interview_confirmed_at ??
      app.attendance_marked_at_by_stage?.INTERVIEW ??
      null
    return { sudah, waktuIso, applicable: true }
  }
  if (tabStatus === "DITERIMA") {
    const sudah =
      Boolean(app.pengumpulan_dokumen_confirmed_at) ||
      app.attendance_by_stage?.DITERIMA === true ||
      app.pengumpulan_dokumen_complete === true
    const waktuIso =
      app.pengumpulan_dokumen_confirmed_at ??
      app.attendance_marked_at_by_stage?.DITERIMA ??
      null
    return { sudah, waktuIso, applicable: true }
  }
  return { sudah: false, waktuIso: null, applicable: false }
}

const COHORT_STATUS_TABS: { value: ApplicationStatus; label: string }[] = [
  { value: "INTERVIEW", label: "Interview" },
  { value: "CADANGAN", label: "Cadangan" },
  { value: "DITERIMA", label: "Diterima" },
  { value: "BERANGKAT", label: "Berangkat" },
  { value: "SELESAI", label: "Selesai" },
  { value: "DITOLAK", label: "Ditolak" },
]

const NEXT_FORWARD: Partial<Record<ApplicationStatus, ApplicationStatus>> = {
  INTERVIEW: "DITERIMA",
  CADANGAN: "DITERIMA",
  DITERIMA: "BERANGKAT",
  BERANGKAT: "SELESAI",
}

const CAN_REJECT_FROM: ApplicationStatus[] = ["INTERVIEW", "CADANGAN", "DITERIMA"]
const COHORT_TAB_PAGE_SIZE = 20

// ---------------------------------------------------------------------------
// Schedule + edit card
// ---------------------------------------------------------------------------

interface ScheduleCardProps {
  cohortId: number
  jobId: number
  date: string | null
  location: string
  notes: string
}

function ScheduleCard({
  cohortId,
  jobId,
  date: initialDate,
  location: initialLocation,
  notes: initialNotes,
}: ScheduleCardProps) {
  const queryClient = useQueryClient()
  const initialDateObj = initialDate ? new Date(initialDate) : null
  const [editing, setEditing] = useState(!initialDate)
  const [selectedDate, setSelectedDate] = useState<Date | null>(initialDateObj)
  const [time, setTime] = useState(initialDateObj ? format(initialDateObj, "HH:mm") : "")
  const [location, setLocation] = useState(initialLocation)
  const [notes, setNotes] = useState(initialNotes)

  const { mutate, isPending } = useMutation({
    mutationFn: () => {
      let interviewDateIso: string | null = null
      if (selectedDate) {
        const [h, m] = time.split(":").map((v) => Number(v) || 0)
        const combined = new Date(selectedDate)
        combined.setHours(h || 0, m || 0, 0, 0)
        interviewDateIso = combined.toISOString()
      }
      return scheduleCohort(cohortId, {
        interview_date: interviewDateIso,
        interview_location: location,
        interview_notes: notes,
      })
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["interview-cohort", cohortId] })
      queryClient.invalidateQueries({ queryKey: ["interview-cohorts"] })
      queryClient.invalidateQueries({ queryKey: ["batches", { job: jobId }] })
      toast.success("Jadwal interview tersimpan.")
      setEditing(false)
    },
    onError: () => toast.error("Gagal menyimpan jadwal."),
  })

  if (!editing) {
    return (
      <Card>
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <CardTitle className="text-base">Jadwal Interview</CardTitle>
            <Button
              variant="ghost"
              size="sm"
              className="cursor-pointer"
              onClick={() => setEditing(true)}
            >
              Ubah
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="flex flex-col gap-2 text-sm">
            <div className="flex items-center gap-2 text-muted-foreground">
              <IconCalendar className="size-4" />
              {formatDate(initialDate)}
            </div>
            {initialLocation && (
              <div className="flex items-center gap-2 text-muted-foreground">
                <IconMapPin className="size-4" />
                {initialLocation}
              </div>
            )}
            {initialNotes && (
              <p className="text-muted-foreground mt-1 text-xs whitespace-pre-wrap">
                {initialNotes}
              </p>
            )}
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader className="pb-3">
        <CardTitle className="text-base">Jadwal Interview</CardTitle>
        <CardDescription>
          Atur tanggal, lokasi, dan informasi tambahan untuk sesi ini.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <div className="flex flex-col gap-3">
          <div className="flex flex-col gap-1.5">
            <Label>Tanggal & Waktu</Label>
            <div className="grid gap-2 sm:grid-cols-[2fr,1fr]">
              <DatePicker
                date={selectedDate}
                onDateChange={setSelectedDate}
                placeholder="Pilih tanggal"
              />
              <Input
                type="time"
                value={time}
                onChange={(e) => setTime(e.target.value)}
              />
            </div>
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Lokasi</Label>
            <Input
              placeholder="Nama gedung / alamat / link"
              value={location}
              onChange={(e) => setLocation(e.target.value)}
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>
              Informasi Tambahan{" "}
              <span className="text-muted-foreground text-xs">(opsional)</span>
            </Label>
            <Textarea
              placeholder="Dress code, dokumen yang dibawa, dll."
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={2}
            />
          </div>
          <div className="flex gap-2 justify-end">
            {initialDate && (
              <Button
                variant="ghost"
                className="cursor-pointer"
                onClick={() => {
                  setSelectedDate(initialDateObj)
                  setTime(initialDateObj ? format(initialDateObj, "HH:mm") : "")
                  setLocation(initialLocation)
                  setNotes(initialNotes)
                  setEditing(false)
                }}
              >
                Batal
              </Button>
            )}
            <Button
              className="cursor-pointer"
              onClick={() => mutate()}
              disabled={isPending}
            >
              {isPending ? "Menyimpan..." : "Simpan Jadwal"}
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Status tab — list + bulk transition for one status within the cohort
// ---------------------------------------------------------------------------

function CohortStatusTab({
  cohortId,
  jobId,
  batchBase,
  lamaranBase,
  pelamarBase,
  status,
  apps,
}: {
  cohortId: number
  jobId: number
  batchBase: string
  lamaranBase: string
  pelamarBase: string
  status: ApplicationStatus
  apps: JobApplication[]
}) {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [note, setNote] = useState("")
  const [placementDate, setPlacementDate] = useState("")
  const [confirmTarget, setConfirmTarget] = useState<ApplicationStatus | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [selected, setSelected] = useState<Set<number>>(new Set())
  const [moveDialogOpen, setMoveDialogOpen] = useState(false)
  const [moveTargetCohortId, setMoveTargetCohortId] = useState<number | null>(
    null
  )
  const [moveNote, setMoveNote] = useState("")
  const [moving, setMoving] = useState(false)
  const [previewUserId, setPreviewUserId] = useState<number | null>(null)
  const [previewUserLabel, setPreviewUserLabel] = useState("")
  const [processUserId, setProcessUserId] = useState<number | null>(null)
  const [processUserLabel, setProcessUserLabel] = useState("")
  const [currentPage, setCurrentPage] = useState(1)
  const [stageSearch, setStageSearch] = useState("")

  const nextStatus = NEXT_FORWARD[status]
  const canReject = CAN_REJECT_FROM.includes(status)
  const needsPlacementDate = nextStatus === "SELESAI"

  const eligibleCount = apps.filter((a) => a.status === status).length
  const sortedApps = useMemo(
    () =>
      [...apps].sort((a, b) =>
        (a.applicant_name || "").localeCompare(b.applicant_name || "", "id", {
          sensitivity: "base",
        })
      ),
    [apps]
  )
  const filteredApps = useMemo(
    () => sortedApps.filter((a) => applicationMatchesStageSearch(a, stageSearch)),
    [sortedApps, stageSearch]
  )
  const pageCount = Math.max(1, Math.ceil(filteredApps.length / COHORT_TAB_PAGE_SIZE))
  const safePage = Math.min(currentPage, pageCount)
  const pageStart = (safePage - 1) * COHORT_TAB_PAGE_SIZE
  const pagedApps = filteredApps.slice(pageStart, pageStart + COHORT_TAB_PAGE_SIZE)

  useEffect(() => {
    setCurrentPage(1)
  }, [status, apps.length])

  useEffect(() => {
    setCurrentPage(1)
  }, [stageSearch])

  useEffect(() => {
    if (currentPage > pageCount) {
      setCurrentPage(pageCount)
    }
  }, [currentPage, pageCount])

  const pageIds = pagedApps.map((a) => a.id)
  const allSelected =
    pageIds.length > 0 && pageIds.every((id) => selected.has(id))

  const toggleAll = () => {
    setSelected((prev) => {
      const next = new Set(prev)
      if (allSelected) pageIds.forEach((id) => next.delete(id))
      else pageIds.forEach((id) => next.add(id))
      return next
    })
  }

  const toggleOne = (id: number) => {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const runMoveToCohort = async () => {
    const ids = Array.from(selected)
    if (!ids.length || moveTargetCohortId == null) return
    setMoving(true)
    try {
      await moveApplicationsToCohort(cohortId, {
        target_cohort: moveTargetCohortId,
        application_ids: ids,
        note: moveNote.trim() || undefined,
      })
      toast.success(`${ids.length} pelamar dipindah ke sesi lain.`)
      invalidateCohortDashboardCaches(queryClient, {
        cohortId,
        jobId,
        extraCohortIds: [moveTargetCohortId],
      })
      setSelected(new Set())
      setMoveNote("")
      setMoveTargetCohortId(null)
      setMoveDialogOpen(false)
    } catch (e: unknown) {
      const ax = e as { response?: { data?: { detail?: string } } }
      toast.error(
        "Gagal memindahkan",
        ax.response?.data?.detail ?? "Coba lagi."
      )
    } finally {
      setMoving(false)
    }
  }

  const runBulk = async (target: ApplicationStatus) => {
    if (!confirmTarget) return
    const ids = Array.from(selected).filter((id) =>
      apps.some((a) => a.id === id && a.status === status)
    )
    if (ids.length === 0) {
      toast.error("Pilih minimal satu pelamar di tabel (centang baris).")
      setConfirmTarget(null)
      return
    }
    setIsSubmitting(true)
    try {
      const res = await bulkTransitionApplications({
        application_ids: ids,
        status: target,
        note: note.trim() || undefined,
        placement_end_date:
          target === "SELESAI"
            ? placementDate || new Date().toISOString().slice(0, 10)
            : undefined,
      })
      invalidateCohortDashboardCaches(queryClient, { cohortId, jobId })
      setConfirmTarget(null)
      setNote("")
      setPlacementDate("")
      setSelected(new Set())
      if (res.updated_count > 0) {
        toast.success(
          `${res.updated_count} pelamar dipindahkan ke "${APPLICATION_STATUS_LABELS[target]}".`
        )
      }
      if (res.failed_count > 0) {
        const top =
          res.failed[0]?.reason ??
          `${res.failed_count} lamaran tidak bisa dipindahkan.`
        toast.error(
          `${res.failed_count} gagal dipindahkan.`,
          top
        )
      }
    } catch (e: unknown) {
      const ax = e as { response?: { data?: { detail?: string } } }
      toast.error(
        "Gagal memindahkan pelamar",
        ax.response?.data?.detail ?? "Coba lagi nanti."
      )
    } finally {
      setIsSubmitting(false)
    }
  }

  const showMoveColumn = apps.length > 0
  const showDocProgressCol = status === "DITERIMA"

  return (
    <div className="flex flex-col gap-4">
      {showMoveColumn && (
        <div className="flex flex-wrap items-center gap-2 rounded-lg border bg-muted/30 p-3">
          <Button
            size="sm"
            variant="outline"
            className="cursor-pointer"
            disabled={selected.size === 0 || moving}
            onClick={() => setMoveDialogOpen(true)}
          >
            <IconArrowsRightLeft className="mr-2 size-4" />
            Pindah ke Sesi Lain ({selected.size} dipilih)
          </Button>
          <span className="text-muted-foreground text-xs">
            Pilih baris di bawah, lalu pindahkan ke sesi interview lain untuk
            lowongan ini (status tidak berubah).
          </span>
        </div>
      )}

      <Dialog
        open={moveDialogOpen}
        onOpenChange={(open) => {
          setMoveDialogOpen(open)
          if (!open) {
            setMoveTargetCohortId(null)
            setMoveNote("")
          }
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Pindah ke Sesi Lain</DialogTitle>
            <DialogDescription>
              Pilih sesi tujuan. Pelamar tetap pada tahapan lamaran yang sama;
              hanya kelompok sesi interview yang berubah.
            </DialogDescription>
          </DialogHeader>
          <div className="flex flex-col gap-4">
            <CohortSelectField
              jobId={jobId}
              value={moveTargetCohortId}
              onChange={setMoveTargetCohortId}
              excludeCohortId={cohortId}
              required
              hideCreateLink
              helperText="Hanya sesi aktif yang dapat dipilih sebagai tujuan."
            />
            <div className="flex flex-col gap-1.5">
              <Label className="text-xs">
                Catatan <span className="text-muted-foreground">(opsional)</span>
              </Label>
              <Textarea
                value={moveNote}
                onChange={(e) => setMoveNote(e.target.value)}
                rows={2}
                className="text-sm"
              />
            </div>
          </div>
          <DialogFooter>
            <Button
              variant="outline"
              className="cursor-pointer"
              disabled={moving}
              onClick={() => setMoveDialogOpen(false)}
            >
              Batal
            </Button>
            <Button
              className="cursor-pointer"
              disabled={
                moving ||
                moveTargetCohortId == null ||
                selected.size === 0
              }
              onClick={() => void runMoveToCohort()}
            >
              {moving ? "Memproses..." : "Pindahkan"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <ApplicantAdminProcessDialog
        applicantUserId={processUserId}
        open={processUserId != null}
        onOpenChange={(next) => {
          if (!next) {
            setProcessUserId(null)
            setProcessUserLabel("")
          }
        }}
        applicantLabel={processUserLabel}
      />
      <ApplicantDetailPreviewDialog
        applicantUserId={previewUserId}
        applicantLabel={previewUserLabel}
        applicantDetailPath={
          previewUserId != null
            ? `${pelamarBase}/${previewUserId}`
            : pelamarBase
        }
        open={previewUserId != null}
        onOpenChange={(next) => {
          if (!next) {
            setPreviewUserId(null)
            setPreviewUserLabel("")
          }
        }}
      />

      {sortedApps.length > 0 && (
        <div className="relative max-w-md">
          <IconSearch className="text-muted-foreground absolute left-3 top-1/2 size-4 -translate-y-1/2" />
          <Input
            placeholder="Cari nama, email, NIK, atau rujukan..."
            value={stageSearch}
            onChange={(e) => setStageSearch(e.target.value)}
            className="pl-9 h-9 text-sm"
            aria-label="Filter pelamar di tahap ini"
          />
        </div>
      )}

      <p className="text-sm text-muted-foreground">
        {filteredApps.length} pelamar
        {filteredApps.length > 0 ? (
          <span className="text-muted-foreground/80">
            {" "}
            (menampilkan {pageStart + 1}–
            {Math.min(pageStart + COHORT_TAB_PAGE_SIZE, filteredApps.length)})
          </span>
        ) : null}
      </p>

      {/* Bulk action bar — transitions only checked rows */}
      {(nextStatus || canReject) && eligibleCount > 0 && (
        <Card>
          <CardContent className="flex flex-col gap-3 py-4 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p className="text-sm font-medium">
                {eligibleCount} pelamar di tahap {APPLICATION_STATUS_LABELS[status]}
                {selected.size > 0 ? (
                  <span className="text-muted-foreground font-normal">
                    {" "}
                    · {selected.size} terpilih
                  </span>
                ) : null}
              </p>
              <p className="text-muted-foreground text-xs">
                Centang pelamar di tabel, lalu gunakan tombol di bawah — hanya baris
                terpilih yang dipindahkan statusnya.
              </p>
            </div>
            <div className="flex flex-wrap gap-2">
              {nextStatus && (
                <Button
                  className="cursor-pointer"
                  disabled={selected.size === 0}
                  onClick={() => setConfirmTarget(nextStatus)}
                >
                  <IconArrowRight className="mr-2 size-4" />
                  Pindahkan ke {APPLICATION_STATUS_LABELS[nextStatus]}
                </Button>
              )}
              {/* INTERVIEW tab: also allow bulk-marking as CADANGAN */}
              {status === "INTERVIEW" && (
                <Button
                  variant="outline"
                  className="cursor-pointer"
                  disabled={selected.size === 0}
                  onClick={() => setConfirmTarget("CADANGAN")}
                >
                  <IconArrowRight className="mr-2 size-4" />
                  Tandai sebagai Cadangan
                </Button>
              )}
              {canReject && (
                <Button
                  variant="destructive"
                  className="cursor-pointer"
                  disabled={selected.size === 0}
                  onClick={() => setConfirmTarget("DITOLAK")}
                >
                  Tolak terpilih
                </Button>
              )}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Applicants table */}
      <div className="overflow-hidden rounded-lg border">
        <Table>
          <TableHeader>
            <TableRow>
              {showMoveColumn && (
                <TableHead className="w-10">
                  <Checkbox
                    checked={allSelected}
                    onCheckedChange={toggleAll}
                    aria-label="Pilih semua"
                  />
                </TableHead>
              )}
              <TableHead>Pelamar</TableHead>
              <TableHead>NIK</TableHead>
              <TableHead>Status</TableHead>
              <TableHead className="whitespace-nowrap min-w-[10rem]">
                Tahapan pra-seleksi
              </TableHead>
              <TableHead className="whitespace-nowrap">
                {status === "INTERVIEW"
                  ? "Konfirmasi kehadiran"
                  : status === "DITERIMA"
                    ? "Konfirmasi dokumen"
                    : status === "CADANGAN"
                      ? "Konfirmasi interview"
                      : "Konfirmasi"}
              </TableHead>
              <TableHead className="whitespace-nowrap">Tanggal konfirmasi</TableHead>
              {showDocProgressCol && (
                <TableHead className="min-w-[11rem]">Pengumpulan Dokumen</TableHead>
              )}
              <TableHead className="text-right sticky right-0 bg-background z-10">
                Aksi
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {pagedApps.length ? (
              pagedApps.map((app) => {
                const konfirmasi = cohortKonfirmasiForTab(app, status)
                return (
                <TableRow
                  key={app.id}
                  className="hover:bg-muted/50 cursor-pointer"
                  onClick={() => toggleOne(app.id)}
                >
                  {showMoveColumn && (
                    <TableCell onClick={(e) => e.stopPropagation()}>
                      <Checkbox
                        checked={selected.has(app.id)}
                        onCheckedChange={() => toggleOne(app.id)}
                        aria-label={`Pilih ${app.applicant_name}`}
                      />
                    </TableCell>
                  )}
                  <TableCell>
                    <div className="flex flex-col">
                      <span className="font-medium">{app.applicant_name}</span>
                      <span className="text-muted-foreground text-xs">
                        {app.applicant_email}
                      </span>
                    </div>
                  </TableCell>
                  <TableCell className="text-muted-foreground text-xs">
                    {app.applicant_nik || "-"}
                  </TableCell>
                  <TableCell>
                    <ApplicationStatusBadge status={app.status} />
                  </TableCell>
                  <TableCell
                    className="text-sm"
                    onClick={(e) => e.stopPropagation()}
                  >
                    {app.batch != null ? (
                      <button
                        type="button"
                        className="inline-flex items-center gap-1 text-primary text-sm underline-offset-2 hover:underline cursor-pointer text-left"
                        onClick={() => navigate(`${batchBase}/${app.batch}`)}
                        title="Buka tahapan pra-seleksi (batch)"
                      >
                        {app.batch_tahap_label ??
                          app.batch_name ??
                          `Batch #${app.batch}`}
                        <IconExternalLink className="size-3 shrink-0" />
                      </button>
                    ) : (
                      <span className="text-muted-foreground">—</span>
                    )}
                  </TableCell>
                  <TableCell className="text-sm">
                    {!konfirmasi.applicable ? (
                      <span className="text-muted-foreground">—</span>
                    ) : konfirmasi.sudah ? (
                      <Badge
                        variant="outline"
                        className="border-green-600/40 bg-green-50 text-green-800 font-normal"
                      >
                        Sudah
                      </Badge>
                    ) : (
                      <Badge variant="secondary" className="font-normal">
                        Belum
                      </Badge>
                    )}
                  </TableCell>
                  <TableCell className="text-sm text-muted-foreground whitespace-nowrap">
                    {!konfirmasi.applicable || !konfirmasi.waktuIso
                      ? "—"
                      : formatDate(konfirmasi.waktuIso)}
                  </TableCell>
                  {showDocProgressCol && (
                    <TableCell
                      className="text-sm align-top"
                      onClick={(e) => e.stopPropagation()}
                    >
                      <DocumentCollectionProgressCell app={app} />
                    </TableCell>
                  )}
                  <TableCell
                    className="text-right sticky right-0 bg-background"
                    onClick={(e) => e.stopPropagation()}
                  >
                    <div className="flex items-center justify-end gap-0.5">
                      <TransitionApplicationDialog
                        application={app}
                        onSuccess={() => {
                          invalidateCohortDashboardCaches(queryClient, {
                            cohortId,
                            jobId,
                          })
                        }}
                      />
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                        title="Lihat detail pelamar"
                        disabled={!app.applicant_user}
                        onClick={() => {
                          if (!app.applicant_user) return
                          setPreviewUserId(app.applicant_user)
                          setPreviewUserLabel(app.applicant_name)
                        }}
                      >
                        <IconEye className="size-4" />
                        <span className="sr-only">Lihat detail pelamar</span>
                      </Button>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                        title="Buka halaman lamaran"
                        onClick={() => navigate(`${lamaranBase}/${app.id}`)}
                      >
                        <IconExternalLink className="size-4" />
                        <span className="sr-only">Buka halaman lamaran</span>
                      </Button>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                        title="Kelola dokumen pelamar"
                        disabled={!app.applicant_user}
                        onClick={() => {
                          if (!app.applicant_user) return
                          navigate(`${pelamarBase}/${app.applicant_user}`)
                        }}
                      >
                        <IconFileSpreadsheet className="size-4" />
                        <span className="sr-only">Kelola dokumen pelamar</span>
                      </Button>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                        title="Edit data proses"
                        disabled={!app.applicant_user}
                        onClick={() => {
                          if (!app.applicant_user) return
                          setProcessUserId(app.applicant_user)
                          setProcessUserLabel(app.applicant_name)
                        }}
                      >
                        <IconClipboardList className="size-4" />
                        <span className="sr-only">Edit data proses</span>
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
                )
              })
            ) : (
              <TableRow>
                <TableCell
                  colSpan={
                    showMoveColumn
                      ? showDocProgressCol
                        ? 9
                        : 8
                      : showDocProgressCol
                        ? 8
                        : 7
                  }
                  className="h-20 text-center text-muted-foreground"
                >
                  Tidak ada pelamar di tahap ini.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      {pageCount > 1 && (
        <div className="flex items-center justify-between gap-2 flex-wrap text-xs text-muted-foreground">
          <div>
            Halaman{" "}
            <span className="font-medium text-foreground">
              {safePage} / {pageCount}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="h-7 px-2 cursor-pointer"
              disabled={safePage <= 1}
              onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
            >
              Sebelumnya
            </Button>
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="h-7 px-2 cursor-pointer"
              disabled={safePage >= pageCount}
              onClick={() => setCurrentPage((p) => Math.min(pageCount, p + 1))}
            >
              Berikutnya
            </Button>
          </div>
        </div>
      )}

      {/* Confirm dialog for bulk transition */}
      <Dialog
        open={confirmTarget !== null}
        onOpenChange={(o) => !o && setConfirmTarget(null)}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              Pindahkan ke {confirmTarget ? APPLICATION_STATUS_LABELS[confirmTarget] : ""}
            </DialogTitle>
            <DialogDescription>
              Anda akan memindahkan{" "}
              <span className="font-medium text-foreground">{selected.size}</span>{" "}
              pelamar terpilih dari tahap {APPLICATION_STATUS_LABELS[status]} ke{" "}
              {confirmTarget ? APPLICATION_STATUS_LABELS[confirmTarget] : ""}. Aturan FSM,
              kuota, dan kelengkapan dokumen tetap diberlakukan per lamaran.
            </DialogDescription>
          </DialogHeader>
          <div className="flex flex-col gap-3">
            {needsPlacementDate && confirmTarget === "SELESAI" && (
              <div className="flex flex-col gap-1.5">
                <Label>Tanggal Selesai Kerja</Label>
                <Input
                  type="date"
                  value={placementDate}
                  onChange={(e) => setPlacementDate(e.target.value)}
                />
                <p className="text-muted-foreground text-xs">
                  Default: hari ini.
                </p>
              </div>
            )}
            <div className="flex flex-col gap-1.5">
              <Label>
                Catatan{" "}
                <span className="text-muted-foreground text-xs">(opsional)</span>
              </Label>
              <Textarea
                value={note}
                onChange={(e) => setNote(e.target.value)}
                rows={2}
              />
            </div>
          </div>
          <DialogFooter>
            <Button
              variant="outline"
              className="cursor-pointer"
              onClick={() => setConfirmTarget(null)}
            >
              Batal
            </Button>
            <Button
              className="cursor-pointer"
              disabled={isSubmitting || selected.size === 0}
              onClick={() => confirmTarget && runBulk(confirmTarget)}
            >
              {isSubmitting ? "Memproses..." : "Konfirmasi"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Announcements card
// ---------------------------------------------------------------------------

function AnnouncementsCard({ cohortId }: { cohortId: number }) {
  const queryClient = useQueryClient()
  const [open, setOpen] = useState(false)
  const [title, setTitle] = useState("")
  const [body, setBody] = useState("")

  const { data: announcements = [] } = useQuery({
    queryKey: ["cohort-announcements", cohortId],
    queryFn: () => getCohortAnnouncements(cohortId),
  })

  const { mutate, isPending } = useMutation({
    mutationFn: () =>
      createCohortAnnouncement(cohortId, {
        title: title.trim(),
        body: body.trim(),
      }),
    onSuccess: ({ detail }) => {
      toast.success("Pengumuman dibuat.", detail)
      setOpen(false)
      setTitle("")
      setBody("")
      queryClient.invalidateQueries({ queryKey: ["cohort-announcements", cohortId] })
    },
    onError: () => toast.error("Gagal membuat pengumuman."),
  })

  return (
    <Card>
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between gap-2">
          <CardTitle className="text-base flex items-center gap-2">
            <IconBell className="size-4" />
            Pengumuman Sesi Interview
          </CardTitle>
          <Button
            size="sm"
            className="cursor-pointer"
            onClick={() => setOpen(true)}
          >
            Buat Pengumuman
          </Button>
        </div>
        <CardDescription>
          Pengumuman dibroadcast ke semua pelamar aktif di sesi ini.
        </CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {announcements.length ? (
          announcements.map((ann: InterviewCohortAnnouncement) => (
            <div
              key={ann.id}
              className="rounded-md border bg-muted/40 p-3 text-sm"
            >
              <div className="flex items-start justify-between gap-3">
                <p className="font-medium">{ann.title}</p>
                <span className="text-muted-foreground text-xs whitespace-nowrap">
                  {format(new Date(ann.created_at), "dd MMM yyyy HH:mm", {
                    locale: idLocale,
                  })}
                </span>
              </div>
              <p className="text-muted-foreground mt-1 whitespace-pre-wrap text-sm">
                {ann.body}
              </p>
              {ann.created_by_name && (
                <p className="text-muted-foreground mt-2 text-xs">
                  Oleh {ann.created_by_name}
                </p>
              )}
            </div>
          ))
        ) : (
          <p className="text-muted-foreground text-sm">
            Belum ada pengumuman untuk sesi ini.
          </p>
        )}
      </CardContent>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Buat Pengumuman</DialogTitle>
            <DialogDescription>
              Pengumuman akan dikirim ke semua pelamar aktif di sesi ini.
            </DialogDescription>
          </DialogHeader>
          <div className="flex flex-col gap-3">
            <div className="flex flex-col gap-1.5">
              <Label>Judul</Label>
              <Input
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="Misal: Konfirmasi Kehadiran Interview"
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label>Isi Pesan</Label>
              <Textarea
                value={body}
                onChange={(e) => setBody(e.target.value)}
                rows={5}
              />
            </div>
          </div>
          <DialogFooter>
            <Button
              variant="outline"
              className="cursor-pointer"
              onClick={() => setOpen(false)}
            >
              Batal
            </Button>
            <Button
              className="cursor-pointer"
              disabled={isPending || !title.trim() || !body.trim()}
              onClick={() => mutate()}
            >
              {isPending ? "Mengirim..." : "Kirim"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

export function AdminInterviewCohortDetailPage() {
  const { id } = useParams<{ id: string }>()
  const cohortId = Number(id)
  const navigate = useNavigate()
  const { basePath } = useAdminDashboard()
  const queryClient = useQueryClient()

  const cohortQuery = useQuery({
    queryKey: ["interview-cohort", cohortId],
    queryFn: () => getInterviewCohort(cohortId),
    enabled: Number.isFinite(cohortId) && cohortId > 0,
  })

  const applicationsQuery = useQuery({
    queryKey: ["cohort-applications", cohortId],
    queryFn: () => getAllApplicationsByCohort(cohortId),
    enabled: Number.isFinite(cohortId) && cohortId > 0,
  })

  usePageTitle(cohortQuery.data ? cohortQuery.data.name : "Detail Sesi Interview")

  const apps = useMemo(() => applicationsQuery.data ?? [], [applicationsQuery.data])
  const [activeStatusTab, setActiveStatusTab] =
    useState<ApplicationStatus>("INTERVIEW")
  const [isExporting, setIsExporting] = useState(false)
  const appsByStatus = useMemo(() => {
    const map: Record<ApplicationStatus, JobApplication[]> = {
      PRA_SELEKSI: [],
      INTERVIEW: [],
      CADANGAN: [],
      DITERIMA: [],
      DITOLAK: [],
      BERANGKAT: [],
      SELESAI: [],
    }
    for (const a of apps) map[a.status]?.push(a)
    return map
  }, [apps])

  const exportStatusChoices: { label: string; value?: ApplicationStatus }[] = [
    { label: "Diterima", value: "DITERIMA" },
    { label: "Ditolak", value: "DITOLAK" },
    { label: "Cadangan", value: "CADANGAN" },
    { label: "Semua" },
  ]

  async function handleExportExcel(statuses?: ApplicationStatus[]) {
    setIsExporting(true)
    try {
      await exportCohortExcel(cohortId, cohortQuery.data?.name ?? "sesi_interview", statuses)
      toast.success("File Excel berhasil diunduh.")
    } catch {
      toast.error("Gagal mengunduh Excel.")
    } finally {
      setIsExporting(false)
    }
  }

  const toggleActiveMutation = useMutation({
    mutationFn: (next: boolean) =>
      patchInterviewCohort(cohortId, { is_active: next }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["interview-cohort", cohortId] })
      queryClient.invalidateQueries({ queryKey: ["interview-cohorts"] })
      toast.success("Status sesi diperbarui.")
    },
    onError: () => toast.error("Gagal memperbarui status sesi."),
  })

  if (cohortQuery.isLoading || applicationsQuery.isLoading) {
    return (
      <div className="flex items-center justify-center py-24">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    )
  }

  if (cohortQuery.isError || !cohortQuery.data) {
    return (
      <div className="p-6">
        <p className="text-destructive">Sesi interview tidak ditemukan.</p>
        <Button
          variant="outline"
          className="mt-4 cursor-pointer"
          onClick={() => goBackOrDefault(navigate, basePath)}
        >
          <IconArrowLeft className="mr-2 size-4" />
          Kembali
        </Button>
      </div>
    )
  }

  const cohort = cohortQuery.data
  const jobsBase = joinAdminPath(basePath, "/lowongan-kerja")
  const batchBase = joinAdminPath(basePath, "/batch")
  const lamaranBase = joinAdminPath(basePath, "/lamaran")
  const pelamarBase = joinAdminPath(basePath, "/pelamar")

  return (
    <div className="flex flex-col gap-6 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: basePath || "/" },
          { label: "Lowongan Kerja", href: jobsBase },
          {
            label: cohort.job_title,
            href: `${jobsBase}/${cohort.job}`,
          },
          { label: cohort.name },
        ]}
      />

      {/* Header */}
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex items-center gap-3">
          <Button
            variant="ghost"
            size="icon"
            className="cursor-pointer shrink-0"
            onClick={() => goBackOrDefault(navigate, `${jobsBase}/${cohort.job}`)}
          >
            <IconArrowLeft className="size-5" />
          </Button>
          <div>
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-2xl font-bold">{cohort.name}</h1>
              <Badge variant={cohort.is_active ? "default" : "outline"}>
                {cohort.is_active ? "Aktif" : "Non-aktif"}
              </Badge>
            </div>
            <p className="text-muted-foreground text-sm mt-0.5">
              <Link
                to={`${jobsBase}/${cohort.job}`}
                className="hover:underline underline-offset-2"
              >
                {cohort.job_title}
              </Link>{" "}
              · {cohort.applicant_count} pelamar
            </p>
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Button
            variant="outline"
            className="cursor-pointer"
            asChild
          >
            <Link
              to={joinAdminPath(basePath, `/sesi-interview/${cohort.id}/edit`)}
            >
              <IconPencil className="mr-2 size-4" />
              Edit Sesi
            </Link>
          </Button>
          <Button
            variant="outline"
            className="cursor-pointer"
            onClick={() =>
              toggleActiveMutation.mutate(!cohort.is_active)
            }
            disabled={toggleActiveMutation.isPending}
          >
            {cohort.is_active ? "Tandai Non-aktif" : "Aktifkan Kembali"}
          </Button>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button
                variant="outline"
                className="cursor-pointer"
                disabled={isExporting || apps.length === 0}
              >
                <IconDownload className="mr-2 size-4" />
                {isExporting ? "Mengunduh..." : "Export Excel"}
                <IconChevronDown className="ml-1 size-4 opacity-70" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="min-w-[240px]">
              <DropdownMenuItem
                className="cursor-pointer flex-col items-start gap-0"
                disabled={appsByStatus[activeStatusTab].length === 0}
                onClick={() => handleExportExcel([activeStatusTab])}
              >
                <span className="font-medium">Tahapan tab saat ini</span>
                <span className="text-muted-foreground text-xs font-normal">
                  {APPLICATION_STATUS_LABELS[activeStatusTab]} (
                  {appsByStatus[activeStatusTab].length} pelamar)
                </span>
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              {exportStatusChoices.map((opt) => {
                const count = opt.value ? appsByStatus[opt.value].length : apps.length
                return (
                  <DropdownMenuItem
                    key={opt.label}
                    className="cursor-pointer justify-between gap-4"
                    disabled={count === 0}
                    onClick={() => handleExportExcel(opt.value ? [opt.value] : undefined)}
                  >
                    <span>{opt.label}</span>
                    <span className="text-muted-foreground tabular-nums text-xs">
                      {count}
                    </span>
                  </DropdownMenuItem>
                )
              })}
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>

      {/* Summary cards */}
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
        <SummaryCard
          icon={<IconUsers className="size-4" />}
          label="Total Pelamar"
          value={cohort.applicant_count}
        />
        <SummaryCard
          icon={<IconUserCheck className="size-4" />}
          label="Interview"
          value={cohort.interview_count}
        />
        <SummaryCard
          icon={<IconUserCheck className="size-4" />}
          label="Cadangan"
          value={cohort.cadangan_count}
        />
        <SummaryCard
          icon={<IconUserCheck className="size-4" />}
          label="Diterima"
          value={cohort.diterima_count}
        />
        <SummaryCard
          icon={<IconCalendar className="size-4" />}
          label="Berangkat / Selesai"
          value={`${cohort.berangkat_count} / ${cohort.selesai_count}`}
        />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <ScheduleCard
          cohortId={cohort.id}
          jobId={cohort.job}
          date={cohort.interview_date}
          location={cohort.interview_location}
          notes={cohort.interview_notes}
        />
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-base">Info Sesi</CardTitle>
          </CardHeader>
          <CardContent className="text-sm flex flex-col gap-2">
            <Row label="Lowongan">
              <Link
                to={`${jobsBase}/${cohort.job}`}
                className="text-primary underline-offset-2 hover:underline"
              >
                {cohort.job_title}
              </Link>
            </Row>
            <Row label="Dibuat">{formatDateOnly(cohort.created_at)}</Row>
            <Row label="Dibuat Oleh">{cohort.created_by_name ?? "-"}</Row>
            {cohort.notes && (
              <Row label="Catatan Internal">
                <span className="whitespace-pre-wrap">{cohort.notes}</span>
              </Row>
            )}
          </CardContent>
        </Card>
      </div>

      <AnnouncementsCard cohortId={cohort.id} />

      <Tabs
        value={activeStatusTab}
        onValueChange={(v) => setActiveStatusTab(v as ApplicationStatus)}
      >
        <TabsList className="h-auto flex-wrap gap-1">
          {COHORT_STATUS_TABS.map((t) => (
            <TabsTrigger key={t.value} value={t.value}>
              {t.label}
              <span className="ml-1.5 text-muted-foreground text-xs">
                ({appsByStatus[t.value].length})
              </span>
            </TabsTrigger>
          ))}
        </TabsList>

        {COHORT_STATUS_TABS.map((t) => (
          <TabsContent key={t.value} value={t.value} className="mt-4">
            <CohortStatusTab
              cohortId={cohort.id}
              jobId={cohort.job}
              batchBase={batchBase}
              lamaranBase={lamaranBase}
              pelamarBase={pelamarBase}
              status={t.value}
              apps={appsByStatus[t.value]}
            />
          </TabsContent>
        ))}
      </Tabs>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Tiny subcomponents
// ---------------------------------------------------------------------------

function SummaryCard({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode
  label: string
  value: number | string
}) {
  return (
    <Card>
      <CardContent className="flex items-center justify-between p-4">
        <div>
          <p className="text-muted-foreground text-xs">{label}</p>
          <p className="text-2xl font-bold">{value}</p>
        </div>
        <div className="text-muted-foreground">{icon}</div>
      </CardContent>
    </Card>
  )
}

function Row({
  label,
  children,
}: {
  label: string
  children: React.ReactNode
}) {
  return (
    <div className="flex gap-2">
      <span className="w-32 shrink-0 text-muted-foreground">{label}</span>
      <span>{children}</span>
    </div>
  )
}
