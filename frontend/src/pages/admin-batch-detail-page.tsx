/**
 * Admin — Batch Detail page.
 *
 * Sections:
 * 1. Header — batch name, job, counts, quick-action buttons.
 * 2. Schedule — set/update Pra-Seleksi and Interview dates + locations.
 * 3. Applications — table of all applicants in this batch with status badges.
 * 4. Assign — button to open BatchAssignDialog (search → select → assign).
 * 5. Bulk Transition — move all eligible applicants to next stage at once.
 */

import { useEffect, useMemo, useState } from "react"
import { useParams, Link, useNavigate } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import {
  IconArrowLeft,
  IconBell,
  IconCalendar,
  IconChevronRight,
  IconClipboardList,
  IconChevronDown,
  IconExternalLink,
  IconFileSpreadsheet,
  IconMapPin,
  IconSearch,
  IconSend,
  IconUserPlus,
  IconUsers,
  IconLoader,
  IconEye,
  IconX,
} from "@tabler/icons-react"
import { toast } from "@/lib/toast"

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
} from "@/api/batches"
import { getApplications, transitionApplication } from "@/api/applications"
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
import { joinAdminPath, useAdminDashboard } from "@/contexts/admin-dashboard-context"

function formatDate(value: string | null | undefined) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy HH:mm", { locale: idLocale })
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

const NEXT_FORWARD: Partial<Record<ApplicationStatus, ApplicationStatus>> = {
  PRA_SELEKSI: "INTERVIEW",
  INTERVIEW:   "DITERIMA",
  DITERIMA:    "BERANGKAT",
  BERANGKAT:   "SELESAI",
}
const CAN_REJECT: ApplicationStatus[] = ["PRA_SELEKSI", "INTERVIEW", "DITERIMA"]

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

// ---------------------------------------------------------------------------
// Sub-component: per-status tab with checkboxes + transition actions
// ---------------------------------------------------------------------------

function BatchStatusTab({
  batchId,
  status,
  apps,
}: {
  batchId: number
  status: ApplicationStatus
  apps: JobApplication[]
}) {
  const navigate = useNavigate()
  const { basePath } = useAdminDashboard()
  const queryClient = useQueryClient()
  const [selected, setSelected] = useState<Set<number>>(new Set())
  const [stageSearch, setStageSearch] = useState("")
  const [note, setNote] = useState("")
  const [placementDate, setPlacementDate] = useState("")
  const [loading, setLoading] = useState(false)
  const [processUserId, setProcessUserId] = useState<number | null>(null)
  const [processUserLabel, setProcessUserLabel] = useState("")
  const [previewUserId, setPreviewUserId] = useState<number | null>(null)
  const [previewUserLabel, setPreviewUserLabel] = useState("")

  const nextStatus = NEXT_FORWARD[status]
  const canReject  = CAN_REJECT.includes(status)
  const needsPlacementDate = nextStatus === "SELESAI"

  const filteredApps = useMemo(
    () => apps.filter((a) => applicationMatchesStageSearch(a, stageSearch)),
    [apps, stageSearch]
  )

  const pageIds = filteredApps.map((a) => a.id)
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

  const runTransition = async (targetStatus: ApplicationStatus) => {
    const ids = Array.from(selected)
    if (!ids.length) return
    if (targetStatus === "SELESAI" && !placementDate) {
      toast.error("Masukkan tanggal selesai kerja terlebih dahulu.")
      return
    }
    setLoading(true)
    let ok = 0, fail = 0
    await Promise.allSettled(
      ids.map((id) =>
        transitionApplication(id, {
          status: targetStatus,
          note: note.trim() || undefined,
          ...(targetStatus === "SELESAI" ? { placement_end_date: placementDate } : {}),
        }).then(() => ok++).catch(() => fail++)
      )
    )
    await queryClient.invalidateQueries({ queryKey: ["applications"] })
    await queryClient.invalidateQueries({ queryKey: ["batch", batchId] })
    setSelected(new Set())
    setNote("")
    setPlacementDate("")
    setLoading(false)
    if (ok > 0) toast.success(`${ok} pelamar dipindahkan ke ${APPLICATION_STATUS_LABELS[targetStatus]}.`)
    if (fail > 0) toast.error(`${fail} pelamar gagal dipindahkan.`)
  }

  const showCheckboxCol = apps.length > 0 && !!(nextStatus || canReject)
  const showDocProgressCol = status === "DITERIMA"
  const tableColSpan = (showCheckboxCol ? 1 : 0) + 8 + (showDocProgressCol ? 1 : 0)

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

      {/* Action bar — only shown when there are selectable apps */}
      {filteredApps.length > 0 && (nextStatus || canReject) && (
        <div className="flex flex-wrap items-end gap-3 rounded-lg border bg-muted/30 p-3">
          <div className="flex flex-col gap-1 flex-1 min-w-[160px]">
            <Label className="text-xs">Catatan transisi <span className="text-muted-foreground">(opsional)</span></Label>
            <Input
              placeholder="Catatan..."
              value={note}
              onChange={(e) => setNote(e.target.value)}
              className="h-8 text-sm"
            />
          </div>
          {needsPlacementDate && (
            <div className="flex flex-col gap-1">
              <Label className="text-xs">Tanggal Selesai Kerja</Label>
              <Input
                type="date"
                value={placementDate}
                onChange={(e) => setPlacementDate(e.target.value)}
                className="h-8 text-sm w-[160px]"
              />
            </div>
          )}
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
          {nextStatus && (
            <Button
              size="sm"
              className="cursor-pointer"
              disabled={selected.size === 0 || loading}
              onClick={() => runTransition(nextStatus)}
            >
              <IconChevronRight className="mr-1 size-4" />
              {loading ? "Memproses..." : `Transisi ke ${APPLICATION_STATUS_LABELS[nextStatus]}`}
            </Button>
          )}
          {canReject && (
            <Button
              size="sm"
              variant="destructive"
              className="cursor-pointer"
              disabled={selected.size === 0 || loading}
              onClick={() => runTransition("DITOLAK")}
            >
              <IconX className="mr-1 size-4" />
              {loading ? "Memproses..." : "Tolak Terpilih"}
            </Button>
          )}
        </div>
      )}

      {/* Table */}
      <div className="overflow-hidden rounded-lg border">
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
              <TableHead>Hadir Tahap Ini</TableHead>
              <TableHead>Konfirmasi Pra-Sel.</TableHead>
              <TableHead>Konfirmasi Interview</TableHead>
              {showDocProgressCol && <TableHead>Pengumpulan Dokumen</TableHead>}
              <TableHead>Tanggal Ditambahkan</TableHead>
              <TableHead className="w-[88px] text-right">Aksi</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {apps.length ? (
              filteredApps.length ? (
              filteredApps.map((app) => (
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
                    {app.status === "SELESAI" ? (
                      <span className="text-green-600">Selesai</span>
                    ) : app.attendance_by_stage?.[app.status] ? (
                      <span className="text-green-600">Hadir</span>
                    ) : (
                      <span className="text-muted-foreground">Belum</span>
                    )}
                  </TableCell>
                  <TableCell className="text-sm">
                    {app.pra_seleksi_confirmed_at ? (
                      <span className="text-green-600">{formatDate(app.pra_seleksi_confirmed_at)}</span>
                    ) : (
                      <span className="text-muted-foreground">Belum</span>
                    )}
                  </TableCell>
                  <TableCell className="text-sm">
                    {app.interview_confirmed_at ? (
                      <span className="text-green-600">{formatDate(app.interview_confirmed_at)}</span>
                    ) : (
                      <span className="text-muted-foreground">Belum</span>
                    )}
                  </TableCell>
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
                  <TableCell onClick={(e) => e.stopPropagation()}>
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
              ))
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
  const { basePath } = useAdminDashboard()

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

  const { data: appsPage } = useQuery({
    queryKey: ["applications", { batch: batchId, page_size: 200 }],
    queryFn: () => getApplications({ batch: batchId, page_size: 200 }),
    enabled: !!batch,
  })

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

  const bulkTransition = useMutation({
    mutationFn: () => Promise.resolve({ updated_count: 0 }),
    onSuccess: () => {},
  })

  const apps = appsPage?.results ?? []

  // Group by status for tabs
  const appsByStatus = STATUS_TABS.reduce(
    (acc, t) => ({ ...acc, [t.value]: apps.filter((a) => a.status === t.value) }),
    {} as Record<ApplicationStatus, typeof apps>
  )

  // Infer dominant status (for legacy use if needed)
  const statusFreq = apps.reduce(
    (acc, a) => ({ ...acc, [a.status]: (acc[a.status] ?? 0) + 1 }),
    {} as Record<string, number>
  )
  void statusFreq
  void bulkTransition

  usePageTitle(batch ? `Batch: ${batch.name}` : "Detail Batch")

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
        <Button asChild variant="outline" className="mt-4 cursor-pointer">
          <Link to={joinAdminPath(basePath, "/lowongan-kerja")}>
            <IconArrowLeft className="mr-2 size-4" />
            Kembali
          </Link>
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
            asChild
            variant="ghost"
            size="icon"
            className="cursor-pointer"
          >
            <Link to={joinAdminPath(basePath, `/lowongan-kerja/${batch.job}`)}>
              <IconArrowLeft className="size-5" />
            </Link>
          </Button>
          <div>
            <h1 className="text-2xl font-bold">{batch.name}</h1>
            <p className="text-muted-foreground text-sm">{batch.job_title}</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button
                variant="outline"
                className="cursor-pointer"
                disabled={isExporting || apps.length === 0}
              >
                <IconFileSpreadsheet className="mr-2 size-4" />
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
              {STATUS_TABS.map((t) => (
                <DropdownMenuItem
                  key={t.value}
                  className="cursor-pointer justify-between gap-4"
                  disabled={appsByStatus[t.value].length === 0}
                  onClick={() => handleExportExcel([t.value])}
                >
                  <span>{t.label}</span>
                  <span className="text-muted-foreground tabular-nums text-xs">
                    {appsByStatus[t.value].length}
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

      {/* Stats row */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
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
              <IconCalendar className="size-5 text-muted-foreground" />
              <div>
                <p className="text-2xl font-bold">{batch.confirmed_pra_seleksi_count}</p>
                <p className="text-xs text-muted-foreground">Konfirmasi Pra-Seleksi</p>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-4 pb-4">
            <div className="flex items-center gap-3">
              <IconCalendar className="size-5 text-muted-foreground" />
              <div>
                <p className="text-2xl font-bold">{batch.confirmed_interview_count}</p>
                <p className="text-xs text-muted-foreground">Konfirmasi Interview</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Schedule cards */}
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <StageScheduleCard
          batchId={batchId}
          stage="pra_seleksi"
          title="Pra-Seleksi"
          currentDate={batch.pra_seleksi_date}
          currentLocation={batch.pra_seleksi_location}
          currentNotes={batch.pra_seleksi_notes}
        />
        <StageScheduleCard
          batchId={batchId}
          stage="interview"
          title="Interview"
          currentDate={batch.interview_date}
          currentLocation={batch.interview_location}
          currentNotes={batch.interview_notes}
        />
      </div>

      {/* Announcements panel */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-base">
            <IconBell className="size-4" />
            Pengumuman Batch
          </CardTitle>
          <CardDescription>
            Kirim pengumuman ke pelamar di batch ini. Batasi penerima berdasarkan tahapan
            lamaran; pelamar hanya melihat pengumuman yang sesuai tahapan mereka. Digunakan
            pada Pra-Seleksi dan Interview sebagai pengganti chat per-orang.
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
              {appsByStatus[t.value].length > 0 && (
                <Badge variant="secondary" className="ml-1.5 rounded-full px-1.5 py-0 text-xs">
                  {appsByStatus[t.value].length}
                </Badge>
              )}
            </TabsTrigger>
          ))}
        </TabsList>
        {STATUS_TABS.map((t) => (
          <TabsContent key={t.value} value={t.value} className="mt-4">
            <BatchStatusTab
              batchId={batchId}
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
        }}
      />
    </div>
  )
}
