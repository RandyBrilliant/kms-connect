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

import { useState } from "react"
import { useParams, Link, useNavigate } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import {
  IconArrowLeft,
  IconBell,
  IconCalendar,
  IconChevronRight,
  IconFileSpreadsheet,
  IconMapPin,
  IconSend,
  IconUserPlus,
  IconUsers,
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

import { BatchAssignDialog } from "@/components/batches/batch-assign-dialog"
import { Badge } from "@/components/ui/badge"
import { Checkbox } from "@/components/ui/checkbox"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { DatePicker } from "@/components/ui/date-picker"

import { getBatch, scheduleBatchStage, getBatchAnnouncements, createBatchAnnouncement, exportBatchExcel } from "@/api/batches"
import { getApplications, transitionApplication } from "@/api/applications"
import {
  APPLICATION_STATUS_LABELS,
  type ApplicationStatus,
  type JobApplication,
} from "@/types/job-applications"
import type { BatchAnnouncement, BatchStage } from "@/types/lamaran-batch"
import { usePageTitle } from "@/hooks/use-page-title"
import { joinAdminPath, useAdminDashboard } from "@/contexts/admin-dashboard-context"

function formatDate(value: string | null | undefined) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy HH:mm", { locale: idLocale })
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
  const [note, setNote] = useState("")
  const [placementDate, setPlacementDate] = useState("")
  const [loading, setLoading] = useState(false)

  const nextStatus = NEXT_FORWARD[status]
  const canReject  = CAN_REJECT.includes(status)
  const needsPlacementDate = nextStatus === "SELESAI"

  const pageIds = apps.map((a) => a.id)
  const allSelected = pageIds.length > 0 && pageIds.every((id) => selected.has(id))

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

  return (
    <div className="flex flex-col gap-4">
      {/* Action bar — only shown when there are selectable apps */}
      {apps.length > 0 && (nextStatus || canReject) && (
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
              <span className="font-medium text-foreground">{selected.size} dipilih</span>
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
              {apps.length > 0 && (nextStatus || canReject) && (
                <TableHead className="w-10">
                  <Checkbox
                    checked={allSelected}
                    onCheckedChange={toggleAll}
                    aria-label="Pilih semua"
                  />
                </TableHead>
              )}
              <TableHead>Pelamar</TableHead>
              <TableHead>Konfirmasi Pra-Sel.</TableHead>
              <TableHead>Konfirmasi Interview</TableHead>
              <TableHead>Tanggal Ditambahkan</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {apps.length ? (
              apps.map((app) => (
                <TableRow
                  key={app.id}
                  className="hover:bg-muted/50 cursor-pointer"
                  onClick={() => toggleOne(app.id)}
                >
                  {(nextStatus || canReject) && (
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
                  <TableCell className="text-sm text-muted-foreground">
                    {formatDate(app.applied_at)}
                  </TableCell>
                  <TableCell onClick={(e) => e.stopPropagation()}>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="cursor-pointer"
                      onClick={() =>
                        navigate(joinAdminPath(basePath, `/lamaran/${app.id}`))
                      }
                    >
                      Detail
                    </Button>
                  </TableCell>
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell
                  colSpan={6}
                  className="h-20 text-center text-muted-foreground"
                >
                  Tidak ada pelamar dengan status ini.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>
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
  const [isExporting, setIsExporting] = useState(false)

  async function handleExportExcel() {
    if (!batch) return
    setIsExporting(true)
    try {
      await exportBatchExcel(batchId, batch.name)
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

  const createAnno = useMutation({    mutationFn: () =>
      createBatchAnnouncement(batchId, { title: annoTitle.trim(), body: annoBody.trim() }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["batch-announcements", batchId] })
      toast.success("Pengumuman berhasil dikirim ke semua pelamar dalam batch ini.")
      setAnnoTitle("")
      setAnnoBody("")
    },
    onError: () => toast.error("Gagal mengirim pengumuman."),
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
          <Button
            variant="outline"
            className="cursor-pointer"
            onClick={handleExportExcel}
            disabled={isExporting || (apps.length === 0)}
          >
            <IconFileSpreadsheet className="mr-2 size-4" />
            {isExporting ? "Mengunduh..." : "Export Excel"}
          </Button>
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
            Kirim pengumuman ke semua pelamar sekaligus. Digunakan pada tahap
            Pra-Seleksi dan Interview sebagai pengganti chat individual.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          {/* Create form */}
          <div className="flex flex-col gap-2 rounded-lg border p-4 bg-muted/30">
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
      <Tabs defaultValue="PRA_SELEKSI">
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
