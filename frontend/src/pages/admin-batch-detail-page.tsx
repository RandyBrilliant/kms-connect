/**
 * Admin — Batch Detail page (Pra-Seleksi tahapan).
 *
 * A batch is one tahapan pra-seleksi for a job. Interview-onwards lives on
 * `InterviewCohort`. From this page admins can:
 * 1. View batch metadata and pra-seleksi schedule.
 * 2. Assign new applicants and broadcast announcements.
 * 3. Move PRA_SELEKSI survivors → InterviewCohort (advance-to-interview)
 *    or → DITOLAK. Subsequent stages are managed inside the cohort.
 */

import { useEffect, useMemo, useState } from "react"
import { useParams, useNavigate } from "react-router-dom"
import { useQuery, useMutation, useQueries, useQueryClient } from "@tanstack/react-query"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import {
  IconArrowLeft,
  IconArrowsRightLeft,
  IconBell,
  IconCalendar,
  IconChevronRight,
  IconClipboardList,
  IconChevronDown,
  IconExternalLink,
  IconFileSpreadsheet,
  IconInfoCircle,
  IconMapPin,
  IconSearch,
  IconSend,
  IconTrash,
  IconUserPlus,
  IconUsers,
  IconLoader,
  IconEye,
  IconX,
} from "@tabler/icons-react"
import { toast } from "@/lib/toast"
import { goBackOrDefault } from "@/lib/back-navigation"

import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
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
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"

import { ApplicantAdminProcessDialog } from "@/components/applicants/applicant-admin-process-dialog"
import { ApplicantDetailPreviewDialog } from "@/components/batches/applicant-detail-preview-dialog"
import { BatchAssignDialog } from "@/components/batches/batch-assign-dialog"
import { BatchSelectField } from "@/components/batches/batch-select-field"
import { CohortSelectField } from "@/components/interview-cohorts/cohort-select-field"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Badge } from "@/components/ui/badge"
import { Checkbox } from "@/components/ui/checkbox"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { DatePicker } from "@/components/ui/date-picker"

import {
  getBatch,
  scheduleBatchStage,
  getBatchAnnouncements,
  createBatchAnnouncement,
  previewBatchAnnouncementRecipients,
  exportBatchExcel,
  advanceBatchToInterview,
  moveApplicationsToBatch,
} from "@/api/batches"
import {
  bulkTransitionApplications,
  getApplications,
} from "@/api/applications"
import {
  APPLICATION_STATUS_LABELS,
  type ApplicationStatus,
  type JobApplication,
} from "@/types/job-applications"
import type {
  BatchAnnouncement,
  BatchAnnouncementRecipientConfig,
  BatchStage,
} from "@/types/lamaran-batch"
import { usePageTitle } from "@/hooks/use-page-title"
import { useAuth } from "@/hooks/use-auth"
import { useDeleteBatchMutation } from "@/hooks/use-batches-query"
import { joinAdminPath, useAdminDashboard } from "@/contexts/admin-dashboard-context"
import { isMasterAdmin, type UserRole } from "@/types/auth"

function formatDate(value: string | null | undefined) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy HH:mm", { locale: idLocale })
}

/** Row labels for konfirmasi kehadiran — depends on which status tab is active. */
function attendanceKonfirmasiForTab(
  app: JobApplication,
  tabStatus: ApplicationStatus
): { sudah: boolean; waktuIso: string | null; applicable: boolean } {
  if (tabStatus === "PRA_SELEKSI") {
    const sudah =
      Boolean(app.pra_seleksi_confirmed_at) ||
      app.attendance_by_stage?.PRA_SELEKSI === true
    const waktuIso =
      app.pra_seleksi_confirmed_at ??
      app.attendance_marked_at_by_stage?.PRA_SELEKSI ??
      null
    return { sudah, waktuIso, applicable: true }
  }
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
  return { sudah: false, waktuIso: null, applicable: false }
}

function announcementRecipientSummary(
  cfg?: BatchAnnouncementRecipientConfig | null
): string {
  if (!cfg || cfg.selection_type === "all_active") {
    return "Semua pelamar aktif (bukan Ditolak/Selesai)"
  }
  const labels = (cfg.statuses ?? []).map((s) => APPLICATION_STATUS_LABELS[s] ?? s)
  return labels.length ? `Tahapan: ${labels.join(", ")}` : "Tahapan terpilih"
}

// ---------------------------------------------------------------------------
// Sub-component: Schedule card for one stage
// ---------------------------------------------------------------------------

interface StageScheduleCardProps {
  batchId: number
  /** Reserved for future tahapan-specific schedules. Currently always "pra_seleksi". */
  stage: BatchStage
  title: string
  currentDate: string | null
  currentLocation: string
  currentNotes: string
}

function StageScheduleCard({
  batchId,
  stage,
  title,
  currentDate,
  currentLocation,
  currentNotes,
}: StageScheduleCardProps) {
  const queryClient = useQueryClient()
  const initialDate = currentDate ? new Date(currentDate) : null
  const [selectedDate, setSelectedDate] = useState<Date | null>(initialDate)
  const [time, setTime] = useState(
    initialDate ? format(initialDate, "HH:mm") : ""
  )
  const [location, setLocation] = useState(currentLocation)
  const [notes, setNotes] = useState(currentNotes)
  const [editing, setEditing] = useState(!currentDate)

  const { mutate, isPending } = useMutation({
    mutationFn: () =>
      scheduleBatchStage(batchId, {
        stage,
        date: (() => {
          if (!selectedDate || !time) {
            throw new Error("Tanggal dan waktu wajib diisi")
          }
          const [h, m] = time.split(":").map((v) => Number(v) || 0)
          const combined = new Date(selectedDate)
          combined.setHours(h, m, 0, 0)
          return combined.toISOString()
        })(),
        location,
        notes,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["batch", batchId] })
      toast.success(`Jadwal ${title} berhasil disimpan.`)
      setEditing(false)
    },
    onError: () => toast.error("Gagal menyimpan jadwal."),
  })

  if (!editing) {
    return (
      <Card>
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <CardTitle className="text-base">{title}</CardTitle>
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
              {formatDate(currentDate)}
            </div>
            {currentLocation && (
              <div className="flex items-center gap-2 text-muted-foreground">
                <IconMapPin className="size-4" />
                {currentLocation}
              </div>
            )}
            {currentNotes && (
              <p className="text-muted-foreground mt-1 text-xs">{currentNotes}</p>
            )}
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader className="pb-3">
        <CardTitle className="text-base">Jadwal {title}</CardTitle>
        <CardDescription>
          Atur tanggal, lokasi, dan informasi tambahan untuk tahap ini.
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
              placeholder="Nama gedung / alamat lengkap"
              value={location}
              onChange={(e) => setLocation(e.target.value)}
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label>Informasi Tambahan <span className="text-muted-foreground text-xs">(opsional)</span></Label>
            <Textarea
              placeholder="Dress code, dokumen yang dibawa, dll."
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={2}
            />
          </div>
          <div className="flex gap-2 justify-end">
            {currentDate && (
              <Button
                variant="ghost"
                className="cursor-pointer"
                onClick={() => {
                  setSelectedDate(initialDate)
                  setTime(initialDate ? format(initialDate, "HH:mm") : "")
                  setLocation(currentLocation)
                  setNotes(currentNotes)
                  setEditing(false)
                }}
              >
                Batal
              </Button>
            )}
            <Button
              className="cursor-pointer"
              onClick={() => mutate()}
              disabled={!selectedDate || !time || !location || isPending}
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
// Helpers / constants
// ---------------------------------------------------------------------------

/**
 * Forward bulk-transitions allowed *from a batch view*. Post-pra-seleksi stages
 * are managed via InterviewCohort, so forwards from INTERVIEW/DITERIMA/BERANGKAT
 * are intentionally absent here — the UI redirects admins to the cohort.
 */
const NEXT_FORWARD: Partial<Record<ApplicationStatus, ApplicationStatus>> = {
  PRA_SELEKSI: "INTERVIEW",
}
/** Batch view only supports rejecting applicants while still in PRA_SELEKSI. */
const CAN_REJECT: ApplicationStatus[] = ["PRA_SELEKSI"]

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

const STATUS_TABS: { value: ApplicationStatus; label: string }[] = [
  { value: "PRA_SELEKSI", label: "Pra-Seleksi" },
  { value: "INTERVIEW",   label: "Interview" },
  { value: "DITERIMA",    label: "Diterima" },
  { value: "BERANGKAT",   label: "Berangkat" },
  { value: "SELESAI",     label: "Selesai" },
  { value: "DITOLAK",     label: "Ditolak" },
]

async function getAllApplicationsByBatchAndStatus(
  batchId: number,
  status: ApplicationStatus
): Promise<JobApplication[]> {
  const pageSize = 100
  let page = 1
  const all: JobApplication[] = []
  while (true) {
    const data = await getApplications({
      batch: batchId,
      status,
      page,
      page_size: pageSize,
      ordering: "applicant_name",
    })
    all.push(...data.results)
    if (!data.next) break
    page += 1
  }
  return all
}

// ---------------------------------------------------------------------------
// Sub-component: per-status tab with checkboxes + transition actions
// ---------------------------------------------------------------------------

function BatchStatusTab({
  batchId,
  jobId,
  status,
  apps,
}: {
  batchId: number
  jobId: number
  status: ApplicationStatus
  apps: JobApplication[]
}) {
  const navigate = useNavigate()
  const { basePath } = useAdminDashboard()
  const queryClient = useQueryClient()
  const [selected, setSelected] = useState<Set<number>>(new Set())
  const [stageSearch, setStageSearch] = useState("")
  const [note, setNote] = useState("")
  const [loading, setLoading] = useState(false)
  const [processUserId, setProcessUserId] = useState<number | null>(null)
  const [processUserLabel, setProcessUserLabel] = useState("")
  const [previewUserId, setPreviewUserId] = useState<number | null>(null)
  const [previewUserLabel, setPreviewUserLabel] = useState("")
  const [advanceCohortId, setAdvanceCohortId] = useState<number | null>(null)
  const [advanceDialogOpen, setAdvanceDialogOpen] = useState(false)
  const [moveDialogOpen, setMoveDialogOpen] = useState(false)
  const [moveTargetBatchId, setMoveTargetBatchId] = useState<number | null>(null)
  const [moveNote, setMoveNote] = useState("")

  const nextStatus = NEXT_FORWARD[status]
  const canReject = CAN_REJECT.includes(status)
  const isManagedByCohort =
    status === "INTERVIEW" ||
    status === "DITERIMA" ||
    status === "BERANGKAT" ||
    status === "SELESAI"

  const filteredApps = useMemo(
    () => apps.filter((a) => applicationMatchesStageSearch(a, stageSearch)),
    [apps, stageSearch]
  )

  // Simple client-side pagination per status tab to avoid very tall tables.
  const [page, setPage] = useState(1)
  const pageSize = 50
  const pageCount = Math.max(1, Math.ceil(filteredApps.length / pageSize))
  const currentPage = Math.min(page, pageCount)
  const pagedApps = useMemo(() => {
    const start = (currentPage - 1) * pageSize
    return filteredApps.slice(start, start + pageSize)
  }, [filteredApps, currentPage])

  const pageIds = pagedApps.map((a) => a.id)
  const allSelected = pageIds.length > 0 && pageIds.every((id) => selected.has(id))

  const hiddenSelectedCount = useMemo(() => {
    if (selected.size === 0) return 0
    const visible = new Set(pageIds)
    let n = 0
    for (const id of selected) {
      if (!visible.has(id)) n++
    }
    return n
  }, [pageIds, selected])

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

  /**
   * Reject selected PRA_SELEKSI applications. Forward transitions to INTERVIEW
   * are handled separately via `runAdvanceToCohort` because they require a
   * cohort to route survivors into.
   */
  const runRejectSelected = async () => {
    const ids = Array.from(selected)
    if (!ids.length) return
    setLoading(true)
    try {
      const result = await bulkTransitionApplications({
        application_ids: ids,
        status: "DITOLAK",
        note: note.trim() || undefined,
      })
      await queryClient.invalidateQueries({ queryKey: ["applications"] })
      await queryClient.invalidateQueries({ queryKey: ["batch", batchId] })
      await queryClient.invalidateQueries({ queryKey: ["batches", { job: jobId }] })
      setSelected(new Set())
      setNote("")

      if (result.updated_count > 0) {
        toast.success(`${result.updated_count} pelamar ditolak.`)
      }
      if (result.failed_count > 0) {
        const reasonFreq = new Map<string, number>()
        for (const item of result.failed) {
          reasonFreq.set(item.reason, (reasonFreq.get(item.reason) ?? 0) + 1)
        }
        const topReason = Array.from(reasonFreq.entries()).sort(
          (a, b) => b[1] - a[1]
        )[0]?.[0]
        toast.error(
          `${result.failed_count} pelamar gagal ditolak.`,
          topReason ?? "Cek status terbaru lalu coba lagi."
        )
      }
    } catch {
      toast.error("Gagal memproses transisi massal.")
    } finally {
      setLoading(false)
    }
  }

  const runAdvanceToCohort = async () => {
    const ids = Array.from(selected)
    if (!ids.length) return
    if (advanceCohortId == null) {
      toast.error("Pilih sesi interview tujuan terlebih dahulu.")
      return
    }
    setLoading(true)
    try {
      const result = await advanceBatchToInterview(batchId, {
        interview_cohort: advanceCohortId,
        application_ids: ids,
        note: note.trim() || undefined,
      })
      await queryClient.invalidateQueries({ queryKey: ["applications"] })
      await queryClient.invalidateQueries({ queryKey: ["batch", batchId] })
      await queryClient.invalidateQueries({
        queryKey: ["interview-cohort", advanceCohortId],
      })
      // Job detail `/lowongan-kerja/:id` — Interview & Pra-Seleksi tabs use these keys
      await queryClient.invalidateQueries({ queryKey: ["interview-cohorts"] })
      await queryClient.invalidateQueries({ queryKey: ["batches", { job: jobId }] })
      await queryClient.invalidateQueries({
        queryKey: ["cohort-applications", advanceCohortId],
      })
      setSelected(new Set())
      setNote("")
      setAdvanceCohortId(null)
      setAdvanceDialogOpen(false)

      if (result.updated_count > 0) {
        toast.success(
          `${result.updated_count} pelamar dipindahkan ke sesi interview.`
        )
      }
      if (result.failed_count > 0) {
        const reasonFreq = new Map<string, number>()
        for (const item of result.failed) {
          reasonFreq.set(item.reason, (reasonFreq.get(item.reason) ?? 0) + 1)
        }
        const topReason = Array.from(reasonFreq.entries()).sort(
          (a, b) => b[1] - a[1]
        )[0]?.[0]
        toast.error(
          `${result.failed_count} pelamar gagal dipindahkan.`,
          topReason ?? "Cek status terbaru lalu coba lagi."
        )
      }
    } catch (err: unknown) {
      const detail = (err as { response?: { data?: { detail?: string } } })
        ?.response?.data?.detail
      toast.error("Gagal memindahkan ke sesi interview.", detail ?? "Coba lagi.")
    } finally {
      setLoading(false)
    }
  }

  const runMoveToBatch = async () => {
    const ids = Array.from(selected)
    if (!ids.length) return
    if (moveTargetBatchId == null) {
      toast.error("Pilih batch tujuan terlebih dahulu.")
      return
    }
    setLoading(true)
    try {
      const res = await moveApplicationsToBatch(batchId, {
        target_batch: moveTargetBatchId,
        application_ids: ids,
        note: moveNote.trim() || undefined,
      })
      await queryClient.invalidateQueries({ queryKey: ["applications"] })
      await queryClient.invalidateQueries({ queryKey: ["batch", batchId] })
      await queryClient.invalidateQueries({
        queryKey: ["batch", moveTargetBatchId],
      })
      await queryClient.invalidateQueries({ queryKey: ["batches", { job: jobId }] })
      setSelected(new Set())
      setMoveNote("")
      setMoveTargetBatchId(null)
      setMoveDialogOpen(false)
      toast.success(
        res.moved_count > 0
          ? `${res.moved_count} pelamar dipindah ke batch lain.`
          : "Tidak ada yang dipindahkan."
      )
    } catch (err: unknown) {
      const detail = (err as { response?: { data?: { detail?: string } } })
        ?.response?.data?.detail
      toast.error("Gagal memindahkan batch.", detail ?? "Coba lagi.")
    } finally {
      setLoading(false)
    }
  }

  const showCheckboxCol = apps.length > 0 && !!(nextStatus || canReject)
  const showDocProgressCol = status === "DITERIMA"
  const showCohortCol = isManagedByCohort
  const tableColSpan =
    (showCheckboxCol ? 1 : 0) +
    7 +
    (showDocProgressCol ? 1 : 0) +
    (showCohortCol ? 1 : 0)

  return (
    <div className="flex flex-col gap-4">
      {apps.length > 0 && (
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

      {/* Cohort-managed banner — INTERVIEW+ stages are now controlled inside
          the InterviewCohort, not the batch. */}
      {isManagedByCohort && apps.length > 0 && (
        <div className="flex items-start gap-3 rounded-lg border border-amber-200 bg-amber-50 dark:border-amber-900 dark:bg-amber-950/40 p-3 text-sm">
          <IconInfoCircle className="mt-0.5 size-4 shrink-0 text-amber-600" />
          <div className="flex-1">
            <p className="font-medium text-amber-900 dark:text-amber-200">
              Pelamar di tahap ini dikelola pada Sesi Interview.
            </p>
            <p className="text-xs text-amber-800/80 dark:text-amber-200/80">
              Buka detail Sesi Interview yang relevan untuk mengubah status,
              membuat pengumuman, atau memindahkan pelamar antar sesi.
            </p>
          </div>
        </div>
      )}

      {/* Action bar — only shown for PRA_SELEKSI / DITOLAK on this page */}
      {filteredApps.length > 0 && (nextStatus || canReject) && (
        <div className="flex flex-wrap items-end gap-3 rounded-lg border bg-muted/30 p-3">
          <div className="flex flex-col gap-1 flex-1 min-w-[160px]">
            <Label className="text-xs">
              Catatan transisi{" "}
              <span className="text-muted-foreground">(opsional)</span>
            </Label>
            <Input
              placeholder="Catatan..."
              value={note}
              onChange={(e) => setNote(e.target.value)}
              className="h-8 text-sm"
            />
          </div>
          <div className="flex items-center gap-2 text-xs text-muted-foreground">
            {selected.size > 0 ? (
              <span className="font-medium text-foreground">
                {selected.size} dipilih
                {hiddenSelectedCount > 0 ? (
                  <span className="ml-1 font-normal text-muted-foreground">
                    ({hiddenSelectedCount} tidak terlihat di filter)
                  </span>
                ) : null}
              </span>
            ) : (
              <span>Pilih pelamar dulu</span>
            )}
          </div>
          {nextStatus === "INTERVIEW" && (
            <Button
              size="sm"
              className="cursor-pointer"
              disabled={selected.size === 0 || loading}
              onClick={() => setAdvanceDialogOpen(true)}
            >
              <IconChevronRight className="mr-1 size-4" />
              Pindahkan ke Sesi Interview
            </Button>
          )}
          {status === "PRA_SELEKSI" && (
            <Button
              size="sm"
              variant="outline"
              className="cursor-pointer"
              disabled={selected.size === 0 || loading}
              onClick={() => setMoveDialogOpen(true)}
              title="Pindahkan ke tahapan pra-seleksi lain (status tidak berubah)"
            >
              <IconArrowsRightLeft className="mr-1 size-4" />
              Pindah ke Tahapan Lain
            </Button>
          )}
          {canReject && (
            <Button
              size="sm"
              variant="destructive"
              className="cursor-pointer"
              disabled={selected.size === 0 || loading}
              onClick={() => void runRejectSelected()}
            >
              <IconX className="mr-1 size-4" />
              {loading ? "Memproses..." : "Tolak Terpilih"}
            </Button>
          )}
        </div>
      )}

      {/* Advance-to-cohort dialog */}
      <Dialog open={advanceDialogOpen} onOpenChange={setAdvanceDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Pindahkan ke Sesi Interview</DialogTitle>
            <DialogDescription>
              Pilih sesi interview tujuan. Status pelamar yang dipilih akan
              berubah ke <span className="font-medium">Interview</span> dan
              ditautkan ke sesi tersebut. Pengumuman, jadwal, dan transisi
              berikutnya akan dikelola di sesi.
            </DialogDescription>
          </DialogHeader>
          <div className="flex flex-col gap-4">
            <div className="rounded-md border bg-muted/30 px-3 py-2 text-sm">
              <span className="font-medium">{selected.size}</span> pelamar akan
              dipindahkan.
            </div>
            <CohortSelectField
              jobId={jobId}
              value={advanceCohortId}
              onChange={setAdvanceCohortId}
              required
              helperText="Hanya sesi yang masih aktif yang ditampilkan."
            />
          </div>
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              className="cursor-pointer"
              disabled={loading}
              onClick={() => {
                setAdvanceDialogOpen(false)
                setAdvanceCohortId(null)
              }}
            >
              Batal
            </Button>
            <Button
              type="button"
              className="cursor-pointer"
              disabled={loading || advanceCohortId == null || selected.size === 0}
              onClick={() => void runAdvanceToCohort()}
            >
              {loading ? "Memproses..." : "Pindahkan"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Re-batch within pra-seleksi */}
      <Dialog
        open={moveDialogOpen}
        onOpenChange={(open) => {
          setMoveDialogOpen(open)
          if (!open) {
            setMoveTargetBatchId(null)
            setMoveNote("")
          }
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Pindah ke Tahapan Lain</DialogTitle>
            <DialogDescription>
              Pilih batch pra-seleksi tujuan di lowongan yang sama. Status
              pelamar tetap <span className="font-medium">Pra-Seleksi</span>
              — hanya wadah tahapan yang berubah.
            </DialogDescription>
          </DialogHeader>
          <div className="flex flex-col gap-4">
            <div className="rounded-md border bg-muted/30 px-3 py-2 text-sm">
              <span className="font-medium">{selected.size}</span> pelamar yang
              dipilih akan dipindahkan.
            </div>
            <BatchSelectField
              jobId={jobId}
              value={moveTargetBatchId}
              onChange={setMoveTargetBatchId}
              excludeBatchId={batchId}
              required
              helperText="Biasanya untuk memindahkan survivor ke tahapan berikutnya (mis. Psikotes)."
            />
            <div className="flex flex-col gap-1.5">
              <Label className="text-xs">
                Catatan <span className="text-muted-foreground">(opsional)</span>
              </Label>
              <Input
                placeholder="Catatan internal..."
                value={moveNote}
                onChange={(e) => setMoveNote(e.target.value)}
                className="h-8 text-sm"
              />
            </div>
          </div>
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              className="cursor-pointer"
              disabled={loading}
              onClick={() => setMoveDialogOpen(false)}
            >
              Batal
            </Button>
            <Button
              type="button"
              className="cursor-pointer"
              disabled={
                loading || moveTargetBatchId == null || selected.size === 0
              }
              onClick={() => void runMoveToBatch()}
            >
              {loading ? "Memproses..." : "Pindahkan"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Table */}
      <div className="overflow-auto rounded-lg border">
        <Table>
          <TableHeader>
            <TableRow>
              {showCheckboxCol && (
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
              <TableHead>Rujukan</TableHead>
              <TableHead className="whitespace-nowrap">Konfirmasi hadir</TableHead>
              <TableHead className="whitespace-nowrap">Waktu konfirmasi</TableHead>
              {showCohortCol && <TableHead>Sesi Interview</TableHead>}
              {showDocProgressCol && <TableHead>Pengumpulan Dokumen</TableHead>}
              <TableHead>Tanggal Ditambahkan</TableHead>
              <TableHead className="w-[88px] text-right">Aksi</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {apps.length ? (
              filteredApps.length ? (
              pagedApps.map((app) => {
                const konfirmasi = attendanceKonfirmasiForTab(app, status)
                return (
                <TableRow
                  key={app.id}
                  className="hover:bg-muted/50 cursor-pointer"
                  onClick={() => toggleOne(app.id)}
                >
                  {showCheckboxCol && (
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
                      <span className="text-xs text-muted-foreground">{app.applicant_email}</span>
                    </div>
                  </TableCell>
                  <TableCell className="text-sm text-muted-foreground">
                    {app.applicant_nik || "—"}
                  </TableCell>
                  <TableCell className="text-sm">
                    {app.referrer_display_name || app.referrer_code ? (
                      <div className="flex flex-col gap-0.5">
                        {app.referrer_display_name ? (
                          <span>{app.referrer_display_name}</span>
                        ) : null}
                        {app.referrer_code ? (
                          <span className="text-xs text-muted-foreground">{app.referrer_code}</span>
                        ) : null}
                      </div>
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
                  {showCohortCol && (
                    <TableCell
                      className="text-sm"
                      onClick={(e) => e.stopPropagation()}
                    >
                      {app.interview_cohort != null ? (
                        <button
                          type="button"
                          className="inline-flex items-center gap-1 text-primary text-sm underline-offset-2 hover:underline cursor-pointer"
                          onClick={() =>
                            navigate(
                              joinAdminPath(
                                basePath,
                                `/sesi-interview/${app.interview_cohort}`
                              )
                            )
                          }
                          title="Buka sesi interview"
                        >
                          {app.interview_cohort_name || `Sesi #${app.interview_cohort}`}
                          <IconExternalLink className="size-3" />
                        </button>
                      ) : (
                        <span className="text-muted-foreground">—</span>
                      )}
                    </TableCell>
                  )}
                  {showDocProgressCol && (
                    <TableCell className="text-sm">
                      {app.document_collection_progress ? (
                        <div className="flex flex-col gap-1">
                          <span className="font-medium">
                            {app.document_collection_progress.done_count}/
                            {app.document_collection_progress.total_count}
                          </span>
                          <span
                            className={
                              app.document_collection_progress.is_complete
                                ? "text-xs text-green-600"
                                : "text-xs text-muted-foreground"
                            }
                          >
                            {app.document_collection_progress.is_complete ? "Lengkap" : "Belum lengkap"}
                          </span>
                          {app.pengumpulan_dokumen_confirmed_at ? (
                            <span className="text-xs text-green-600">
                              Dikonfirmasi: {formatDate(app.pengumpulan_dokumen_confirmed_at)}
                            </span>
                          ) : app.document_collection_progress.is_complete ? (
                            <span className="text-xs text-amber-600">
                              Menunggu konfirmasi pelamar
                            </span>
                          ) : null}
                          {app.pengumpulan_dokumen_pending_labels?.length ? (
                            <div className="mt-0.5">
                              <p className="text-[11px] font-medium text-muted-foreground">
                                Belum terpenuhi:
                              </p>
                              <ul className="list-disc pl-4 text-[11px] text-muted-foreground space-y-0.5">
                                {app.pengumpulan_dokumen_pending_labels.slice(0, 3).map((label) => (
                                  <li key={label}>{label}</li>
                                ))}
                                {app.pengumpulan_dokumen_pending_labels.length > 3 ? (
                                  <li>+{app.pengumpulan_dokumen_pending_labels.length - 3} item lainnya</li>
                                ) : null}
                              </ul>
                            </div>
                          ) : null}
                        </div>
                      ) : (
                        <span className="text-muted-foreground">-</span>
                      )}
                    </TableCell>
                  )}
                  <TableCell className="text-sm text-muted-foreground">
                    {formatDate(app.applied_at)}
                  </TableCell>
                  <TableCell
                    onClick={(e) => e.stopPropagation()}
                    className="sticky right-0 bg-background"
                  >
                    <div className="flex items-center justify-end gap-0.5">
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
                        onClick={() =>
                          navigate(joinAdminPath(basePath, `/lamaran/${app.id}`))
                        }
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
                          navigate(joinAdminPath(basePath, `/pelamar/${app.applicant_user}`))
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
                    colSpan={tableColSpan}
                    className="h-20 text-center text-muted-foreground"
                  >
                    Tidak ada pelamar yang cocok dengan pencarian.
                  </TableCell>
                </TableRow>
              )
            ) : (
              <TableRow>
                <TableCell
                  colSpan={tableColSpan}
                  className="h-20 text-center text-muted-foreground"
                >
                  Tidak ada pelamar dengan status ini.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      {/* Pagination controls */}
      {filteredApps.length > pageSize && (
        <div className="mt-3 flex items-center justify-between text-xs text-muted-foreground">
          <div>
            Menampilkan{" "}
            <span className="font-medium">
              {(currentPage - 1) * pageSize + 1}-
              {Math.min(currentPage * pageSize, filteredApps.length)}
            </span>{" "}
            dari <span className="font-medium">{filteredApps.length}</span> pelamar
          </div>
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              className="h-7 px-2 cursor-pointer"
              disabled={currentPage <= 1}
              onClick={() => setPage((p) => Math.max(1, p - 1))}
            >
              Sebelumnya
            </Button>
            <span>
              Halaman{" "}
              <span className="font-medium">
                {currentPage} / {pageCount}
              </span>
            </span>
            <Button
              variant="outline"
              size="sm"
              className="h-7 px-2 cursor-pointer"
              disabled={currentPage >= pageCount}
              onClick={() => setPage((p) => Math.min(pageCount, p + 1))}
            >
              Berikutnya
            </Button>
          </div>
        </div>
      )}

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
            ? joinAdminPath(basePath, `/pelamar/${previewUserId}`)
            : joinAdminPath(basePath, "/pelamar")
        }
        open={previewUserId != null}
        onOpenChange={(next) => {
          if (!next) {
            setPreviewUserId(null)
            setPreviewUserLabel("")
          }
        }}
      />
    </div>
  )
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

export function AdminBatchDetailPage() {
  const { id } = useParams<{ id: string }>()
  const batchId = Number(id)
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const { basePath } = useAdminDashboard()
  const { user } = useAuth()
  const deleteBatchMutation = useDeleteBatchMutation()

  const canDeleteBatch =
    !!user && isMasterAdmin(user.role as UserRole)

  const [deleteBatchDialogOpen, setDeleteBatchDialogOpen] = useState(false)
  const [assignOpen, setAssignOpen] = useState(false)
  const [annoTitle, setAnnoTitle] = useState("")
  const [annoBody, setAnnoBody] = useState("")
  const [annoRecipientMode, setAnnoRecipientMode] = useState<"all_active" | "statuses">(
    "all_active"
  )
  const [annoSelectedStatuses, setAnnoSelectedStatuses] = useState<ApplicationStatus[]>([])
  const [annoPreviewCount, setAnnoPreviewCount] = useState<number | null>(null)
  const [isExporting, setIsExporting] = useState(false)
  const [activeStatusTab, setActiveStatusTab] =
    useState<ApplicationStatus>("PRA_SELEKSI")

  useEffect(() => {
    setAnnoPreviewCount(null)
  }, [annoRecipientMode, annoSelectedStatuses])

  async function handleExportExcel(statuses?: ApplicationStatus[]) {
    if (!batch) return
    setIsExporting(true)
    try {
      await exportBatchExcel(batchId, batch.name, statuses)
      toast.success("File Excel berhasil diunduh.")
    } catch {
      toast.error("Gagal mengunduh data Excel.")
    } finally {
      setIsExporting(false)
    }
  }

  const { data: batch, isLoading, isError } = useQuery({
    queryKey: ["batch", batchId],
    queryFn: () => getBatch(batchId),
  })

  const activeTabAppsQuery = useQuery({
    queryKey: ["applications", { batch: batchId, status: activeStatusTab, page_size: 100 }],
    queryFn: () => getAllApplicationsByBatchAndStatus(batchId, activeStatusTab),
    enabled: !!batch,
  })

  const activeTabApps = activeTabAppsQuery.data ?? []
  const statusCountQueries = useQueries({
    queries: STATUS_TABS.map((t) => ({
      queryKey: ["applications", "count", { batch: batchId, status: t.value }],
      queryFn: async () => {
        const res = await getApplications({
          batch: batchId,
          status: t.value,
          page: 1,
          page_size: 1,
        })
        return res.count
      },
      enabled: !!batch,
      staleTime: 30_000,
    })),
  })
  const statusCounts = useMemo(
    () =>
      STATUS_TABS.reduce(
        (acc, t, idx) => ({ ...acc, [t.value]: statusCountQueries[idx]?.data ?? 0 }),
        {} as Record<ApplicationStatus, number>
      ),
    [statusCountQueries]
  )

  const { data: announcements = [], isLoading: annoLoading } = useQuery({    queryKey: ["batch-announcements", batchId],
    queryFn: () => getBatchAnnouncements(batchId),
    enabled: !!batch,
  })

  const buildAnnouncementRecipientConfig = (): BatchAnnouncementRecipientConfig => {
    if (annoRecipientMode === "all_active") {
      return { selection_type: "all_active" }
    }
    return { selection_type: "statuses", statuses: [...annoSelectedStatuses] }
  }

  const previewAnno = useMutation({
    mutationFn: () =>
      previewBatchAnnouncementRecipients(batchId, buildAnnouncementRecipientConfig()),
    onSuccess: (data) => setAnnoPreviewCount(data.recipient_count),
    onError: (err: unknown) => {
      const detail = (err as { response?: { data?: { detail?: string } } })?.response?.data
        ?.detail
      toast.error("Preview gagal", detail ?? "Tidak dapat menghitung jumlah penerima.")
    },
  })

  const createAnno = useMutation({
    mutationFn: () => {
      const recipient_config = buildAnnouncementRecipientConfig()
      if (
        recipient_config.selection_type === "statuses" &&
        (!recipient_config.statuses || recipient_config.statuses.length === 0)
      ) {
        return Promise.reject(new Error("NO_STATUSES"))
      }
      return createBatchAnnouncement(batchId, {
        title: annoTitle.trim(),
        body: annoBody.trim(),
        recipient_config,
      })
    },
    onSuccess: (res) => {
      queryClient.invalidateQueries({ queryKey: ["batch-announcements", batchId] })
      toast.success("Pengumuman terkirim", res.detail ?? "Pengumuman berhasil dibuat.")
      setAnnoTitle("")
      setAnnoBody("")
      setAnnoRecipientMode("all_active")
      setAnnoSelectedStatuses([])
      setAnnoPreviewCount(null)
    },
    onError: (err: unknown) => {
      if ((err as Error)?.message === "NO_STATUSES") {
        toast.warning(
          "Pilih tahapan",
          "Pilih minimal satu tahapan pelamar sebelum mengirim pengumuman."
        )
        return
      }
      const detail = (err as { response?: { data?: { detail?: string } } })?.response?.data
        ?.detail
      toast.error("Gagal mengirim pengumuman.", detail ?? "Coba lagi.")
    },
  })

  // Group by status for tabs
  const appsByStatus = useMemo(
    () =>
      STATUS_TABS.reduce(
        (acc, t) => ({
          ...acc,
          [t.value]: t.value === activeStatusTab ? activeTabApps : [],
        }),
        {} as Record<ApplicationStatus, JobApplication[]>
      ),
    [activeStatusTab, activeTabApps]
  )

  usePageTitle(batch ? `Batch: ${batch.name}` : "Detail Batch")

  const handleConfirmDeleteBatch = async () => {
    try {
      await deleteBatchMutation.mutateAsync(batchId)
      toast.success(
        "Batch dihapus",
        "Seluruh lamaran dan data terkait batch ini telah dihapus."
      )
      setDeleteBatchDialogOpen(false)
      navigate(joinAdminPath(basePath, `/lowongan-kerja/${batch?.job ?? ""}`))
    } catch (err: unknown) {
      const res = err as { response?: { status?: number; data?: { detail?: string } } }
      if (res?.response?.status === 403) {
        toast.error(
          "Tidak diizinkan",
          "Hanya Admin Utama yang dapat menghapus batch."
        )
      } else {
        toast.error(
          "Gagal menghapus",
          res?.response?.data?.detail ?? "Coba lagi nanti."
        )
      }
    }
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-24">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    )
  }

  if (isError || !batch) {
    return (
      <div className="p-6">
        <p className="text-destructive">Batch tidak ditemukan.</p>
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
          { label: batch.job_title, href: joinAdminPath(basePath, `/lowongan-kerja/${batch.job}`) },
          { label: batch.name },
        ]}
      />

      {/* Header */}
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div className="flex items-center gap-3">
          <Button
            variant="ghost"
            size="icon"
            className="cursor-pointer"
            onClick={() =>
              goBackOrDefault(
                navigate,
                joinAdminPath(basePath, `/lowongan-kerja/${batch.job}`)
              )
            }
          >
            <IconArrowLeft className="size-5" />
          </Button>
          <div>
            <h1 className="text-2xl font-bold">{batch.name}</h1>
            <p className="text-muted-foreground text-sm">
              {batch.job_title}
              {batch.display_tahap_label ? (
                <>
                  {" · "}
                  <span className="font-medium">{batch.display_tahap_label}</span>
                </>
              ) : null}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {canDeleteBatch && (
            <Button
              type="button"
              variant="destructive"
              className="cursor-pointer"
              onClick={() => setDeleteBatchDialogOpen(true)}
            >
              <IconTrash className="mr-2 size-4" />
              Hapus batch
            </Button>
          )}
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button
                variant="outline"
                className="cursor-pointer"
                disabled={isExporting || batch.applicant_count === 0}
              >
                <IconFileSpreadsheet className="mr-2 size-4" />
                {isExporting ? "Mengunduh..." : "Export Excel"}
                <IconChevronDown className="ml-1 size-4 opacity-70" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="min-w-[240px]">
              <DropdownMenuItem
                className="cursor-pointer flex-col items-start gap-0"
                disabled={statusCounts[activeStatusTab] === 0}
                onClick={() => handleExportExcel([activeStatusTab])}
              >
                <span className="font-medium">Tahapan tab saat ini</span>
                <span className="text-muted-foreground text-xs font-normal">
                  {APPLICATION_STATUS_LABELS[activeStatusTab]} (
                  {statusCounts[activeStatusTab]} pelamar)
                </span>
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              {STATUS_TABS.map((t) => (
                <DropdownMenuItem
                  key={t.value}
                  className="cursor-pointer justify-between gap-4"
                  disabled={statusCounts[t.value] === 0}
                  onClick={() => handleExportExcel([t.value])}
                >
                  <span>{t.label}</span>
                  <span className="text-muted-foreground tabular-nums text-xs">
                    {statusCounts[t.value]}
                  </span>
                </DropdownMenuItem>
              ))}
              <DropdownMenuSeparator />
              <DropdownMenuItem
                className="cursor-pointer"
                onClick={() => handleExportExcel(undefined)}
              >
                Semua tahapan
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
          <Button className="cursor-pointer" onClick={() => setAssignOpen(true)}>
            <IconUserPlus className="mr-2 size-4" />
            Tambah Pelamar
          </Button>
        </div>
      </div>

      {/* Stats row — pra-seleksi specific. Interview/diterima/dst. tracked
          on the related InterviewCohort. */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <Card>
          <CardContent className="pt-4 pb-4">
            <div className="flex items-center gap-3">
              <IconUsers className="size-5 text-muted-foreground" />
              <div>
                <p className="text-2xl font-bold">{batch.applicant_count}</p>
                <p className="text-xs text-muted-foreground">Total Pelamar</p>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-4 pb-4">
            <div className="flex items-center gap-3">
              <IconUsers className="size-5 text-muted-foreground" />
              <div>
                <p className="text-2xl font-bold">{batch.pra_seleksi_count}</p>
                <p className="text-xs text-muted-foreground">Masih di Pra-Seleksi</p>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-4 pb-4">
            <div className="flex items-center gap-3">
              <IconChevronRight className="size-5 text-muted-foreground" />
              <div>
                <p className="text-2xl font-bold">{batch.advanced_count}</p>
                <p className="text-xs text-muted-foreground">Lanjut ke Interview</p>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-4 pb-4">
            <div className="flex items-center gap-3">
              <IconCalendar className="size-5 text-muted-foreground" />
              <div>
                <p className="text-2xl font-bold">{batch.confirmed_pra_seleksi_count}</p>
                <p className="text-xs text-muted-foreground">Konfirmasi Pra-Seleksi</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Pra-Seleksi schedule. Interview schedules now live on InterviewCohort. */}
      <StageScheduleCard
        batchId={batchId}
        stage="pra_seleksi"
        title="Pra-Seleksi"
        currentDate={batch.pra_seleksi_date}
        currentLocation={batch.pra_seleksi_location}
        currentNotes={batch.pra_seleksi_notes}
      />

      {/* Announcements panel */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-base">
            <IconBell className="size-4" />
            Pengumuman Batch
          </CardTitle>
          <CardDescription>
            Kirim pengumuman pra-seleksi ke pelamar di batch ini. Batasi
            penerima berdasarkan tahapan lamaran. Untuk pengumuman seputar
            interview, gunakan halaman <span className="font-medium">Sesi Interview</span> agar
            pelamar yang sudah terhubung ke sesi tertentu menerima informasi
            yang tepat.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          {/* Create form */}
          <div className="flex flex-col gap-3 rounded-lg border p-4 bg-muted/30">
            <Label className="font-medium">Kirim Pengumuman Baru</Label>
            <Input
              placeholder="Judul pengumuman..."
              value={annoTitle}
              onChange={(e) => setAnnoTitle(e.target.value)}
            />
            <Textarea
              placeholder="Isi pesan pengumuman (jadwal, instruksi, info penting, dll.)..."
              rows={3}
              value={annoBody}
              onChange={(e) => setAnnoBody(e.target.value)}
            />

            <div className="space-y-2">
              <Label className="text-muted-foreground text-xs font-medium uppercase tracking-wide">
                Penerima
              </Label>
              <RadioGroup
                value={annoRecipientMode}
                onValueChange={(v) => setAnnoRecipientMode(v as "all_active" | "statuses")}
              >
                <div className="flex items-center space-x-2">
                  <RadioGroupItem value="all_active" id="anno-rec-all" />
                  <Label htmlFor="anno-rec-all" className="font-normal">
                    Semua pelamar aktif (bukan Ditolak / Selesai)
                  </Label>
                </div>
                <div className="flex items-center space-x-2">
                  <RadioGroupItem value="statuses" id="anno-rec-st" />
                  <Label htmlFor="anno-rec-st" className="font-normal">
                    Berdasarkan tahapan lamaran
                  </Label>
                </div>
              </RadioGroup>
              {annoRecipientMode === "statuses" && (
                <div className="ml-1 flex flex-col gap-2 border-l pl-4">
                  {STATUS_TABS.map((t) => (
                    <div key={t.value} className="flex items-center space-x-2">
                      <Checkbox
                        id={`anno-rec-${t.value}`}
                        checked={annoSelectedStatuses.includes(t.value)}
                        onCheckedChange={(checked) => {
                          const on = Boolean(checked)
                          setAnnoSelectedStatuses((prev) =>
                            on ? [...prev, t.value] : prev.filter((s) => s !== t.value)
                          )
                        }}
                      />
                      <Label htmlFor={`anno-rec-${t.value}`} className="font-normal">
                        {t.label}
                      </Label>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                className="cursor-pointer"
                disabled={previewAnno.isPending}
                onClick={() => {
                  if (
                    annoRecipientMode === "statuses" &&
                    annoSelectedStatuses.length === 0
                  ) {
                    toast.warning(
                      "Pilih tahapan",
                      "Pilih minimal satu tahapan untuk preview jumlah penerima."
                    )
                    return
                  }
                  previewAnno.mutate()
                }}
              >
                {previewAnno.isPending ? (
                  <IconLoader className="mr-2 size-4 animate-spin" />
                ) : (
                  <IconUsers className="mr-2 size-4" />
                )}
                Preview jumlah penerima
              </Button>
              {annoPreviewCount !== null && (
                <span className="text-muted-foreground text-sm">
                  {annoPreviewCount} pelamar akan menerima notifikasi
                </span>
              )}
            </div>

            <div className="flex justify-end">
              <Button
                className="cursor-pointer"
                onClick={() => createAnno.mutate()}
                disabled={!annoTitle.trim() || !annoBody.trim() || createAnno.isPending}
              >
                <IconSend className="mr-2 size-4" />
                {createAnno.isPending ? "Mengirim..." : "Kirim Pengumuman"}
              </Button>
            </div>
          </div>

          {/* Announcements list */}
          {annoLoading ? (
            <p className="text-sm text-muted-foreground">Memuat pengumuman...</p>
          ) : announcements.length === 0 ? (
            <p className="text-sm text-muted-foreground">Belum ada pengumuman untuk batch ini.</p>
          ) : (
            <div className="flex flex-col gap-3">
              {(announcements as BatchAnnouncement[]).map((anno) => (
                <div
                  key={anno.id}
                  className="rounded-lg border bg-card p-4 flex flex-col gap-1"
                >
                  <div className="flex items-start justify-between gap-2">
                    <span className="font-semibold text-sm">{anno.title}</span>
                    <span className="text-xs text-muted-foreground whitespace-nowrap">
                      {formatDate(anno.created_at)}
                    </span>
                  </div>
                  <p className="text-xs text-muted-foreground">
                    {announcementRecipientSummary(anno.recipient_config)}
                  </p>
                  <p className="text-sm text-muted-foreground whitespace-pre-wrap">{anno.body}</p>
                  {anno.created_by_name && (
                    <p className="text-xs text-muted-foreground mt-1">oleh {anno.created_by_name}</p>
                  )}
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Status tabs — replace flat table + bulk transition */}
      <Tabs
        value={activeStatusTab}
        onValueChange={(v) => setActiveStatusTab(v as ApplicationStatus)}
      >
        <TabsList className="h-auto flex-wrap gap-1">
          {STATUS_TABS.map((t) => (
            <TabsTrigger key={t.value} value={t.value}>
              {t.label}
              {statusCounts[t.value] > 0 && (
                <Badge variant="secondary" className="ml-1.5 rounded-full px-1.5 py-0 text-xs">
                  {statusCounts[t.value]}
                </Badge>
              )}
            </TabsTrigger>
          ))}
        </TabsList>
        {STATUS_TABS.map((t) => (
          <TabsContent key={t.value} value={t.value} className="mt-4">
            <BatchStatusTab
              batchId={batchId}
              jobId={batch.job}
              status={t.value}
              apps={appsByStatus[t.value]}
            />
          </TabsContent>
        ))}
      </Tabs>

      <BatchAssignDialog
        batchId={batchId}
        open={assignOpen}
        onOpenChange={setAssignOpen}
        onSuccess={() => {
          queryClient.invalidateQueries({ queryKey: ["applications"] })
          queryClient.invalidateQueries({ queryKey: ["batch", batchId] })
          queryClient.invalidateQueries({ queryKey: ["batches", { job: batch.job }] })
        }}
      />

      <AlertDialog open={deleteBatchDialogOpen} onOpenChange={setDeleteBatchDialogOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Hapus batch permanen?</AlertDialogTitle>
            <AlertDialogDescription asChild>
              <div className="space-y-3 text-muted-foreground text-sm">
                <p>
                  Tindakan ini tidak dapat dibatalkan. Batch{" "}
                  <span className="font-medium text-foreground">{batch.name}</span> dan
                  semua isinya akan dihapus, termasuk:
                </p>
                <ul className="list-disc space-y-1 pl-4">
                  <li>
                    Seluruh lamaran (job applications) dalam batch ini — beserta riwayat
                    status dan chat
                  </li>
                  <li>Pengumuman batch yang terkait</li>
                  <li>Jadwal pra-seleksi yang tercatat pada batch ini</li>
                </ul>
                <p>
                  Catatan: <span className="font-medium text-foreground">Sesi Interview</span> yang
                  terkait dengan pelamar di batch ini tidak ikut terhapus — sesi
                  dapat dipakai juga oleh batch lain dalam lowongan yang sama.
                </p>
                <p>
                  Akun pelamar <span className="font-medium text-foreground">tidak</span>{" "}
                  dihapus; hanya data lamaran mereka pada batch ini.
                </p>
              </div>
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel
              type="button"
              className="cursor-pointer"
              disabled={deleteBatchMutation.isPending}
            >
              Batal
            </AlertDialogCancel>
            <Button
              type="button"
              variant="destructive"
              className="cursor-pointer"
              disabled={deleteBatchMutation.isPending}
              onClick={() => void handleConfirmDeleteBatch()}
            >
              {deleteBatchMutation.isPending ? "Menghapus..." : "Ya, hapus batch"}
            </Button>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}
