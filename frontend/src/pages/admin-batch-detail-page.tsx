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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"

import { ApplicationStatusBadge } from "@/components/applications/application-status-badge"
import { BatchAssignDialog } from "@/components/batches/batch-assign-dialog"

import { getBatch, scheduleBatchStage, bulkTransitionBatch, getBatchAnnouncements, createBatchAnnouncement, exportBatchExcel } from "@/api/batches"
import { getApplications } from "@/api/applications"
import {
  APPLICATION_STATUS_LABELS,
  type ApplicationStatus,
} from "@/types/job-applications"
import type { BatchAnnouncement, BatchStage } from "@/types/lamaran-batch"
import { usePageTitle } from "@/hooks/use-page-title"

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
  const [date, setDate] = useState(
    currentDate ? currentDate.slice(0, 16) : ""  // datetime-local format
  )
  const [location, setLocation] = useState(currentLocation)
  const [notes, setNotes] = useState(currentNotes)
  const [editing, setEditing] = useState(!currentDate)

  const { mutate, isPending } = useMutation({
    mutationFn: () =>
      scheduleBatchStage(batchId, {
        stage,
        date: new Date(date).toISOString(),
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
            <Input
              type="datetime-local"
              value={date}
              onChange={(e) => setDate(e.target.value)}
            />
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
                onClick={() => setEditing(false)}
              >
                Batal
              </Button>
            )}
            <Button
              className="cursor-pointer"
              onClick={() => mutate()}
              disabled={!date || !location || isPending}
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
// Main page
// ---------------------------------------------------------------------------

const NEXT_STATUS_OPTIONS: Record<string, ApplicationStatus[]> = {
  PRA_SELEKSI: ["INTERVIEW", "DITOLAK"],
  INTERVIEW: ["DITERIMA", "DITOLAK"],
  DITERIMA: ["BERANGKAT", "DITOLAK"],
  BERANGKAT: ["SELESAI"],
}

export function AdminBatchDetailPage() {
  const { id } = useParams<{ id: string }>()
  const batchId = Number(id)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [assignOpen, setAssignOpen] = useState(false)
  const [bulkStatus, setBulkStatus] = useState<ApplicationStatus | "">("")
  const [bulkNote, setBulkNote] = useState("")
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

  const { data: announcements = [], isLoading: annoLoading } = useQuery({
    queryKey: ["batch-announcements", batchId],
    queryFn: () => getBatchAnnouncements(batchId),
    enabled: !!batch,
  })

  const createAnno = useMutation({
    mutationFn: () =>
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
    mutationFn: () =>
      bulkTransitionBatch(batchId, {
        status: bulkStatus as ApplicationStatus,
        note: bulkNote.trim(),
      }),
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ["applications"] })
      queryClient.invalidateQueries({ queryKey: ["batch", batchId] })
      toast.success(`${result.updated_count} lamaran berhasil dipindahkan.`)
      setBulkStatus("")
      setBulkNote("")
    },
    onError: () => toast.error("Gagal memindahkan status batch."),
  })

  const apps = appsPage?.results ?? []

  // Infer current dominant status from applications
  const statusFreq = apps.reduce(
    (acc, a) => ({ ...acc, [a.status]: (acc[a.status] ?? 0) + 1 }),
    {} as Record<string, number>
  )
  const dominantStatus = Object.entries(statusFreq).sort((a, b) => b[1] - a[1])[0]?.[0] ?? ""
  const nextOptions: ApplicationStatus[] = NEXT_STATUS_OPTIONS[dominantStatus] ?? []

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
          <Link to="/batch">
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
          { label: "Batch Lamaran", href: "/batch" },
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
            <Link to="/batch">
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

      {/* Bulk transition */}
      {nextOptions.length > 0 && apps.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Transisi Status Batch</CardTitle>
            <CardDescription>
              Pindahkan seluruh pelamar dalam batch ini ke status berikutnya sekaligus.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex flex-wrap items-end gap-3">
              <div className="flex flex-col gap-1.5">
                <Label>Status Baru</Label>
                <Select
                  value={bulkStatus}
                  onValueChange={(v) => setBulkStatus(v as ApplicationStatus)}
                >
                  <SelectTrigger className="w-[200px] cursor-pointer">
                    <SelectValue placeholder="Pilih status..." />
                  </SelectTrigger>
                  <SelectContent>
                    {nextOptions.map((s) => (
                      <SelectItem key={s} value={s}>
                        {APPLICATION_STATUS_LABELS[s]}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="flex flex-col gap-1.5 flex-1 min-w-[200px]">
                <Label>Catatan <span className="text-muted-foreground text-xs">(opsional)</span></Label>
                <Input
                  placeholder="Catatan transisi..."
                  value={bulkNote}
                  onChange={(e) => setBulkNote(e.target.value)}
                />
              </div>
              <Button
                className="cursor-pointer"
                onClick={() => bulkTransition.mutate()}
                disabled={!bulkStatus || bulkTransition.isPending}
              >
                <IconChevronRight className="mr-2 size-4" />
                {bulkTransition.isPending ? "Memproses..." : "Jalankan Transisi"}
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Applications table */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">
            Daftar Pelamar ({apps.length})
          </CardTitle>
          <CardDescription>
            Semua pelamar yang sudah ditambahkan ke batch ini.
          </CardDescription>
        </CardHeader>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Pelamar</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Konfirmasi Pra-Sel.</TableHead>
                <TableHead>Konfirmasi Interview</TableHead>
                <TableHead>Ditugaskan</TableHead>
                <TableHead />
              </TableRow>
            </TableHeader>
            <TableBody>
              {apps.length ? (
                apps.map((app) => (
                  <TableRow key={app.id} className="hover:bg-muted/50">
                    <TableCell>
                      <div className="flex flex-col">
                        <span className="font-medium">{app.applicant_name}</span>
                        <span className="text-xs text-muted-foreground">
                          {app.applicant_email}
                        </span>
                      </div>
                    </TableCell>
                    <TableCell>
                      <ApplicationStatusBadge status={app.status} />
                    </TableCell>
                    <TableCell className="text-sm">
                      {app.pra_seleksi_confirmed_at ? (
                        <span className="text-green-600">
                          {formatDate(app.pra_seleksi_confirmed_at)}
                        </span>
                      ) : (
                        <span className="text-muted-foreground">Belum</span>
                      )}
                    </TableCell>
                    <TableCell className="text-sm">
                      {app.interview_confirmed_at ? (
                        <span className="text-green-600">
                          {formatDate(app.interview_confirmed_at)}
                        </span>
                      ) : (
                        <span className="text-muted-foreground">Belum</span>
                      )}
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {formatDate(app.applied_at)}
                    </TableCell>
                    <TableCell>
                      <Button
                        variant="ghost"
                        size="sm"
                        className="cursor-pointer"
                        onClick={() => navigate(`/lamaran/${app.id}`)}
                      >
                        Detail
                      </Button>
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell colSpan={6} className="h-20 text-center text-muted-foreground">
                    Belum ada pelamar di batch ini. Klik "Tambah Pelamar" untuk memulai.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

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
