/**
 * Admin — Job Detail page.
 *
 * Tabs (re-organised around the new Pra-Seleksi / InterviewCohort split):
 *  - Info        — job metadata
 *  - Edit        — edit form (gated)
 *  - Pra-Seleksi — list of pra-seleksi tahapan (LamaranBatch) for this job.
 *                  Each row shows the tahapan's progress (counts).
 *  - Interview   — list of InterviewCohort sessions for this job. Each row
 *                  shows interview counts and downstream progress.
 *  - Diterima    — applications at DITERIMA across all cohorts.
 *  - Berangkat   — applications at BERANGKAT across all cohorts.
 *  - Selesai     — applications at SELESAI across all cohorts.
 *  - Ditolak     — applications at DITOLAK across all batches/cohorts.
 *
 * The PRA_SELEKSI / INTERVIEW status lists are intentionally absent here —
 * they are managed inside their owning batch / cohort detail pages.
 */

import { type ReactNode, useState, useEffect, useMemo } from "react"
import { Navigate, useLocation, useNavigate, useParams } from "react-router-dom"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import {
  IconArrowLeft,
  IconBriefcase,
  IconBuilding,
  IconCalendar,
  IconCircleCheck,
  IconClipboardList,
  IconExternalLink,
  IconEye,
  IconFileSpreadsheet,
  IconMapPin,
  IconPencil,
  IconPlus,
  IconSearch,
  IconUserCheck,
  IconUsers,
  IconUsersGroup,
} from "@tabler/icons-react"

import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { ApplicantAdminProcessDialog } from "@/components/applicants/applicant-admin-process-dialog"
import { ApplicantDetailPreviewDialog } from "@/components/batches/applicant-detail-preview-dialog"
import { ApplicationStatusBadge } from "@/components/applications/application-status-badge"
import { DocumentCollectionProgressCell } from "@/components/applications/document-collection-progress-cell"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Checkbox } from "@/components/ui/checkbox"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { usePageTitle } from "@/hooks/use-page-title"
import { useAdminDashboard } from "@/contexts/admin-dashboard-context"
import { useAuth } from "@/hooks/use-auth"
import { isRestrictedAdmin, type UserRole } from "@/types/auth"

import { JobForm } from "@/components/jobs/job-form"
import { useUpdateJobMutation } from "@/hooks/use-jobs-query"
import { toast } from "@/lib/toast"
import { goBackOrDefault } from "@/lib/back-navigation"

import { getJob } from "@/api/jobs"
import { getBatches } from "@/api/batches"
import { getInterviewCohorts } from "@/api/interview-cohorts"
import { exportApplicationsExcel, getApplications } from "@/api/applications"
import { createBroadcast, sendBroadcast } from "@/api/notifications"
import type { JobItem, EmploymentType, JobStatus as JobStatusType } from "@/types/jobs"
import type { ApplicationStatus } from "@/types/job-applications"

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatDate(v: string | null | undefined) {
  if (!v) return "-"
  return format(new Date(v), "dd MMM yyyy", { locale: idLocale })
}

function formatDateTime(v: string | null | undefined) {
  if (!v) return "-"
  return format(new Date(v), "dd MMM yyyy HH:mm", { locale: idLocale })
}

const JOB_STATUS_MAP: Record<
  string,
  { label: string; variant: "default" | "secondary" | "outline" | "destructive" }
> = {
  OPEN: { label: "Dibuka", variant: "default" },
  DRAFT: { label: "Draf", variant: "secondary" },
  CLOSED: { label: "Ditutup", variant: "outline" },
  ARCHIVED: { label: "Diarsipkan", variant: "destructive" },
}

const EMPLOYMENT_TYPE_MAP: Record<string, string> = {
  FULL_TIME: "Penuh Waktu",
  PART_TIME: "Paruh Waktu",
  CONTRACT: "Kontrak",
  INTERNSHIP: "Magang",
}

/**
 * Status tabs surfaced at the job level. PRA_SELEKSI and INTERVIEW are
 * intentionally excluded — admins manage those inside the owning batch /
 * cohort detail pages. CADANGAN is included as it is a post-interview holding
 * state visible at the job level.
 */
const DOWNSTREAM_STATUS_TABS: { value: ApplicationStatus; label: string }[] = [
  { value: "CADANGAN", label: "Cadangan" },
  { value: "DITERIMA", label: "Diterima" },
  { value: "BERANGKAT", label: "Berangkat" },
  { value: "SELESAI", label: "Selesai" },
  { value: "DITOLAK", label: "Ditolak" },
]
const MASTER_TAHAPAN_PAGE_SIZE = 20

// ---------------------------------------------------------------------------
// Sub-component: Edit form
// ---------------------------------------------------------------------------

function EditTab({
  jobId,
  job,
  jobsBase,
}: {
  jobId: number
  job: JobItem
  jobsBase: string
}) {
  const navigate = useNavigate()
  const updateMutation = useUpdateJobMutation(jobId)

  const handleSubmit = async (values: {
    title: string
    slug: string
    company: number | null
    location_country: string
    location_city: string
    description: string
    requirements: string
    employment_type: EmploymentType
    salary_min: number | null
    salary_max: number | null
    currency: string
    status: JobStatusType
    posted_at?: string | null
    deadline?: string | null
    start_date?: string | null
    quota?: number | null
  }) => {
    try {
      await updateMutation.mutateAsync(values)
      toast.success("Lowongan diperbarui", "Perubahan berhasil disimpan")
      navigate(`${jobsBase}/${jobId}`)
    } catch (err: unknown) {
      const res = err as {
        response?: { data?: { errors?: Record<string, string[]>; detail?: string } }
      }
      const errors = res?.response?.data?.errors
      const detail = res?.response?.data?.detail
      if (errors) {
        toast.error("Validasi gagal", Object.values(errors).flat().join(". "))
      } else {
        toast.error("Gagal menyimpan", detail ?? "Coba lagi nanti")
      }
      throw err
    }
  }

  return (
    <div className="max-w-3xl">
      <JobForm
        job={job}
        onSubmit={handleSubmit}
        isSubmitting={updateMutation.isPending}
      />
    </div>
  )
}

// ---------------------------------------------------------------------------
// Sub-component: Pra-Seleksi (batches/tahapan) tab
// ---------------------------------------------------------------------------

function PraSeleksiTab({
  jobId,
  jobsBase,
  batchBase,
}: {
  jobId: number
  jobsBase: string
  batchBase: string
}) {
  const navigate = useNavigate()
  const [page, setPage] = useState(1)

  const { data, isLoading } = useQuery({
    queryKey: ["batches", { job: jobId, page, mode: "job-detail-master" }],
    queryFn: () =>
      getBatches({
        job: jobId,
        page,
        page_size: MASTER_TAHAPAN_PAGE_SIZE,
        ordering: "tahap_order,created_at",
      }),
  })

  const batches = data?.results ?? []
  const totalCount = data?.count ?? 0
  const pageCount = Math.max(1, Math.ceil(totalCount / MASTER_TAHAPAN_PAGE_SIZE))
  const currentPage = Math.min(page, pageCount)

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-2 flex-wrap">
        <p className="text-sm text-muted-foreground">
          {totalCount} tahapan pra-seleksi.{" "}
          {totalCount > 0 ? (
            <span className="text-muted-foreground/80">
              (menampilkan{" "}
              {(currentPage - 1) * MASTER_TAHAPAN_PAGE_SIZE + 1}–
              {Math.min(currentPage * MASTER_TAHAPAN_PAGE_SIZE, totalCount)}){" "}
            </span>
          ) : null}
          <span className="text-xs">
            Setiap tahapan adalah batch pelamar yang diseleksi sebelum interview.
          </span>
        </p>
        <Button
          size="sm"
          className="cursor-pointer"
          onClick={() => navigate(`${jobsBase}/${jobId}/batch/new`)}
        >
          <IconPlus className="mr-2 size-4" />
          Buat Tahapan Baru
        </Button>
      </div>

      <div className="overflow-hidden rounded-lg border">
        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          </div>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-[80px]">Urutan</TableHead>
                <TableHead>Nama Tahapan</TableHead>
                <TableHead className="text-center">Total</TableHead>
                <TableHead className="text-center">Pra-Seleksi</TableHead>
                <TableHead className="text-center">Lanjut Interview</TableHead>
                <TableHead className="text-center">Ditolak</TableHead>
                <TableHead>Jadwal</TableHead>
                <TableHead className="w-[60px]" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {batches.length ? (
                batches.map((batch) => (
                  <TableRow
                    key={batch.id}
                    className="cursor-pointer hover:bg-muted/50"
                    onClick={() => navigate(`${batchBase}/${batch.id}`)}
                  >
                    <TableCell>
                      <Badge variant="outline" className="font-mono">
                        Tahap {batch.tahap_order}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <div className="flex flex-col gap-0.5">
                        <span className="font-medium flex items-center gap-2">
                          <IconClipboardList className="size-4 shrink-0 text-muted-foreground" />
                          {batch.name}
                        </span>
                        {batch.tahap_label ? (
                          <span className="text-xs text-muted-foreground">
                            {batch.tahap_label}
                          </span>
                        ) : null}
                      </div>
                    </TableCell>
                    <TableCell className="text-center tabular-nums">
                      <span className="inline-flex items-center justify-center gap-1">
                        <IconUsers className="size-3.5 text-muted-foreground" />
                        {batch.applicant_count}
                      </span>
                    </TableCell>
                    <TableCell className="text-center tabular-nums">
                      <Badge variant="secondary" className="font-mono">
                        {batch.pra_seleksi_count}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-center tabular-nums">
                      <Badge
                        variant="default"
                        className="font-mono"
                        title="Sudah dipindahkan ke Sesi Interview / di tahap setelah pra-seleksi"
                      >
                        {batch.advanced_count}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-center tabular-nums">
                      <Badge
                        variant={batch.rejected_count ? "destructive" : "outline"}
                        className="font-mono"
                      >
                        {batch.rejected_count}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {batch.pra_seleksi_date ? (
                        <div className="flex flex-col">
                          <span>{formatDate(batch.pra_seleksi_date)}</span>
                          {batch.pra_seleksi_location ? (
                            <span className="text-xs">
                              {batch.pra_seleksi_location}
                            </span>
                          ) : null}
                        </div>
                      ) : (
                        <span className="text-xs italic">Belum dijadwalkan</span>
                      )}
                    </TableCell>
                    <TableCell onClick={(e) => e.stopPropagation()}>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="size-8 cursor-pointer"
                        onClick={() => navigate(`${batchBase}/${batch.id}`)}
                        title="Lihat detail tahapan"
                      >
                        <IconEye className="size-4" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell colSpan={8} className="h-24 text-center text-muted-foreground">
                    Belum ada tahapan pra-seleksi untuk lowongan ini.{" "}
                    <button
                      type="button"
                      className="text-primary underline-offset-2 hover:underline cursor-pointer"
                      onClick={() => navigate(`${jobsBase}/${jobId}/batch/new`)}
                    >
                      Buat tahapan pertama
                    </button>
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        )}
      </div>

      {pageCount > 1 && (
        <div className="flex items-center justify-between gap-2 flex-wrap text-xs text-muted-foreground">
          <div>
            Halaman{" "}
            <span className="font-medium text-foreground">
              {currentPage} / {pageCount}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="h-7 px-2 cursor-pointer"
              disabled={currentPage <= 1 || isLoading}
              onClick={() => setPage((p) => Math.max(1, p - 1))}
            >
              Sebelumnya
            </Button>
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="h-7 px-2 cursor-pointer"
              disabled={currentPage >= pageCount || isLoading}
              onClick={() => setPage((p) => Math.min(pageCount, p + 1))}
            >
              Berikutnya
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Sub-component: Interview cohorts tab
// ---------------------------------------------------------------------------

function InterviewCohortsTab({
  jobId,
  jobsBase,
  cohortBase,
}: {
  jobId: number
  jobsBase: string
  cohortBase: string
}) {
  const navigate = useNavigate()
  const [page, setPage] = useState(1)

  const { data, isLoading } = useQuery({
    queryKey: ["interview-cohorts", { job: jobId, page, mode: "job-detail" }],
    queryFn: () =>
      getInterviewCohorts({
        job: jobId,
        page,
        page_size: MASTER_TAHAPAN_PAGE_SIZE,
        ordering: "-interview_date,-created_at",
      }),
  })

  const cohorts = data?.results ?? []
  const totalCount = data?.count ?? 0
  const pageCount = Math.max(1, Math.ceil(totalCount / MASTER_TAHAPAN_PAGE_SIZE))
  const currentPage = Math.min(page, pageCount)

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-2 flex-wrap">
        <p className="text-sm text-muted-foreground">
          {totalCount} sesi interview.{" "}
          {totalCount > 0 ? (
            <span className="text-muted-foreground/80">
              (menampilkan{" "}
              {(currentPage - 1) * MASTER_TAHAPAN_PAGE_SIZE + 1}–
              {Math.min(currentPage * MASTER_TAHAPAN_PAGE_SIZE, totalCount)}){" "}
            </span>
          ) : null}
          <span className="text-xs">
            Sesi mengelola tahap Interview hingga Selesai. Pelamar dirutekan ke
            sesi dari batch pra-seleksi.
          </span>
        </p>
        <Button
          size="sm"
          className="cursor-pointer"
          onClick={() => navigate(`${jobsBase}/${jobId}/sesi-interview/baru`)}
        >
          <IconPlus className="mr-2 size-4" />
          Buat Sesi Interview
        </Button>
      </div>

      <div className="overflow-hidden rounded-lg border">
        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          </div>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Nama Sesi</TableHead>
                <TableHead>Jadwal Interview</TableHead>
                <TableHead className="text-center">Total</TableHead>
                <TableHead className="text-center">Interview</TableHead>
                <TableHead className="text-center">Diterima</TableHead>
                <TableHead className="text-center">Berangkat</TableHead>
                <TableHead className="text-center">Selesai</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="w-[60px]" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {cohorts.length ? (
                cohorts.map((cohort) => (
                  <TableRow
                    key={cohort.id}
                    className="cursor-pointer hover:bg-muted/50"
                    onClick={() => navigate(`${cohortBase}/${cohort.id}`)}
                  >
                    <TableCell>
                      <div className="flex flex-col gap-0.5">
                        <span className="font-medium flex items-center gap-2">
                          <IconUsersGroup className="size-4 shrink-0 text-muted-foreground" />
                          {cohort.name}
                        </span>
                        {cohort.notes ? (
                          <span className="text-xs text-muted-foreground line-clamp-1">
                            {cohort.notes}
                          </span>
                        ) : null}
                      </div>
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {cohort.interview_date ? (
                        <div className="flex flex-col">
                          <span className="flex items-center gap-1">
                            <IconCalendar className="size-3.5" />
                            {formatDateTime(cohort.interview_date)}
                          </span>
                          {cohort.interview_location ? (
                            <span className="text-xs flex items-center gap-1">
                              <IconMapPin className="size-3" />
                              {cohort.interview_location}
                            </span>
                          ) : null}
                        </div>
                      ) : (
                        <span className="text-xs italic">Belum dijadwalkan</span>
                      )}
                    </TableCell>
                    <TableCell className="text-center tabular-nums">
                      <span className="inline-flex items-center justify-center gap-1">
                        <IconUsers className="size-3.5 text-muted-foreground" />
                        {cohort.applicant_count}
                      </span>
                    </TableCell>
                    <TableCell className="text-center tabular-nums">
                      <Badge variant="secondary" className="font-mono">
                        {cohort.interview_count}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-center tabular-nums">
                      <Badge variant="default" className="font-mono">
                        {cohort.diterima_count}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-center tabular-nums">
                      <Badge variant="default" className="font-mono">
                        {cohort.berangkat_count}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-center tabular-nums">
                      <Badge variant="outline" className="font-mono">
                        {cohort.selesai_count}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      {cohort.is_active ? (
                        <Badge variant="default" className="gap-1">
                          <IconCircleCheck className="size-3" /> Aktif
                        </Badge>
                      ) : (
                        <Badge variant="outline">Non-aktif</Badge>
                      )}
                    </TableCell>
                    <TableCell onClick={(e) => e.stopPropagation()}>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="size-8 cursor-pointer"
                        onClick={() => navigate(`${cohortBase}/${cohort.id}`)}
                        title="Lihat detail sesi"
                      >
                        <IconEye className="size-4" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell
                    colSpan={9}
                    className="h-24 text-center text-muted-foreground"
                  >
                    Belum ada sesi interview untuk lowongan ini.{" "}
                    <button
                      type="button"
                      className="text-primary underline-offset-2 hover:underline cursor-pointer"
                      onClick={() =>
                        navigate(`${jobsBase}/${jobId}/sesi-interview/baru`)
                      }
                    >
                      Buat sesi pertama
                    </button>
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        )}
      </div>

      {pageCount > 1 && (
        <div className="flex items-center justify-between gap-2 flex-wrap text-xs text-muted-foreground">
          <div>
            Halaman{" "}
            <span className="font-medium text-foreground">
              {currentPage} / {pageCount}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="h-7 px-2 cursor-pointer"
              disabled={currentPage <= 1 || isLoading}
              onClick={() => setPage((p) => Math.max(1, p - 1))}
            >
              Sebelumnya
            </Button>
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="h-7 px-2 cursor-pointer"
              disabled={currentPage >= pageCount || isLoading}
              onClick={() => setPage((p) => Math.min(pageCount, p + 1))}
            >
              Berikutnya
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Sub-component: Applications per status (downstream stages only)
// ---------------------------------------------------------------------------

const APPLICATIONS_TAB_PAGE_SIZE = 20

function ApplicationsTab({
  jobId,
  status,
  batchBase,
  cohortBase,
  lamaranBase,
  pelamarBase,
}: {
  jobId: number
  status: ApplicationStatus
  batchBase: string
  cohortBase: string
  lamaranBase: string
  pelamarBase: string
}) {
  const navigate = useNavigate()
  const [page, setPage] = useState(1)
  const [stageSearch, setStageSearch] = useState("")
  const [previewUserId, setPreviewUserId] = useState<number | null>(null)
  const [previewUserLabel, setPreviewUserLabel] = useState("")
  const [processUserId, setProcessUserId] = useState<number | null>(null)
  const [processUserLabel, setProcessUserLabel] = useState("")
  const [selectedApplicantUsers, setSelectedApplicantUsers] = useState<Set<number>>(
    new Set()
  )
  const [announcementTitle, setAnnouncementTitle] = useState("")
  const [announcementBody, setAnnouncementBody] = useState("")
  const [confirmAnnouncementOpen, setConfirmAnnouncementOpen] = useState(false)
  const [isExporting, setIsExporting] = useState(false)
  const queryClient = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ["applications", { job: jobId, status, page, search: stageSearch }],
    queryFn: () =>
      getApplications({
        job: jobId,
        status,
        page,
        page_size: APPLICATIONS_TAB_PAGE_SIZE,
        search: stageSearch.trim() || undefined,
        ordering: "applicant_name",
      }),
  })

  const totalCount = data?.count ?? 0
  const pageCount = Math.max(1, Math.ceil(totalCount / APPLICATIONS_TAB_PAGE_SIZE))
  const currentPage = Math.min(page, pageCount)

  const sortedApps = useMemo(
    () =>
      [...(data?.results ?? [])].sort((a, b) =>
        (a.applicant_name || "").localeCompare(b.applicant_name || "", "id", {
          sensitivity: "base",
        })
      ),
    [data?.results]
  )
  const filteredApps = sortedApps
  const showCohortCol = status !== "DITOLAK"
  const showDocCol = status === "DITERIMA"
  const enableAcceptedAnnouncement = status === "DITERIMA"
  const selectableApplicantUsers = filteredApps
    .map((a) => a.applicant_user)
    .filter((v): v is number => typeof v === "number")
  const allSelectableChecked =
    selectableApplicantUsers.length > 0 &&
    selectableApplicantUsers.every((id) => selectedApplicantUsers.has(id))
  const selectedRecipientIds = Array.from(selectedApplicantUsers)
  const selectedRecipientNames = filteredApps
    .filter(
      (app) =>
        typeof app.applicant_user === "number" &&
        selectedApplicantUsers.has(app.applicant_user)
    )
    .map((app) => app.applicant_name)
  const canSendAnnouncement =
    selectedRecipientIds.length > 0 &&
    announcementTitle.trim().length > 0 &&
    announcementBody.trim().length > 0
  const emptyColSpan = 5 + (showCohortCol ? 1 : 0) + (showDocCol ? 1 : 0)

  const handleExportExcel = async () => {
    setIsExporting(true)
    try {
      await exportApplicationsExcel(
        {
          job: jobId,
          status,
          search: stageSearch.trim() || undefined,
          ordering: "applicant_name",
        },
        `pelamar_${status.toLowerCase()}.xlsx`
      )
      toast.success("File Excel berhasil diunduh.")
    } catch {
      toast.error("Gagal mengunduh data Excel.")
    } finally {
      setIsExporting(false)
    }
  }

  const sendAnnouncementMutation = useMutation({
    mutationFn: async () => {
      const created = await createBroadcast({
        title: announcementTitle.trim(),
        message: announcementBody.trim(),
        notification_type: "BROADCAST",
        priority: "NORMAL",
        recipient_config: {
          selection_type: "users",
          user_ids: selectedRecipientIds,
        },
        send_email: false,
        send_in_app: true,
        send_push: true,
      })
      return sendBroadcast(created.id)
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["broadcasts"] })
      toast.success(
        "Pengumuman dikirim",
        `Pengumuman dikirim ke ${selectedRecipientIds.length} pelamar terpilih.`
      )
      setAnnouncementTitle("")
      setAnnouncementBody("")
      setSelectedApplicantUsers(new Set())
    },
    onError: (err: unknown) => {
      const detail = (err as { response?: { data?: { detail?: string } } })?.response
        ?.data?.detail
      toast.error("Gagal mengirim pengumuman", detail ?? "Coba lagi nanti.")
    },
  })

  const toggleSelectAllApplicants = () => {
    setSelectedApplicantUsers((prev) => {
      const next = new Set(prev)
      if (allSelectableChecked) {
        selectableApplicantUsers.forEach((id) => next.delete(id))
      } else {
        selectableApplicantUsers.forEach((id) => next.add(id))
      }
      return next
    })
  }

  const toggleSelectApplicant = (applicantUserId: number) => {
    setSelectedApplicantUsers((prev) => {
      const next = new Set(prev)
      if (next.has(applicantUserId)) {
        next.delete(applicantUserId)
      } else {
        next.add(applicantUserId)
      }
      return next
    })
  }

  return (
    <>
      <div className="flex flex-col gap-4">
        <div className="flex items-center justify-between gap-2 flex-wrap">
          <p className="text-sm text-muted-foreground">
            {totalCount} pelamar
            {totalCount > 0 ? (
              <span className="text-muted-foreground/80">
                {" "}
                (menampilkan{" "}
                {(currentPage - 1) * APPLICATIONS_TAB_PAGE_SIZE + 1}–
                {Math.min(currentPage * APPLICATIONS_TAB_PAGE_SIZE, totalCount)})
              </span>
            ) : null}
          </p>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="cursor-pointer"
            disabled={isExporting || totalCount === 0}
            onClick={() => void handleExportExcel()}
          >
            <IconFileSpreadsheet className="mr-2 size-4" />
            {isExporting ? "Mengunduh..." : "Export Excel"}
          </Button>
        </div>

        {enableAcceptedAnnouncement && (
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-base">Pengumuman Tahap Diterima</CardTitle>
              <p className="text-sm text-muted-foreground">
                Pilih pelamar pada tabel, lalu kirim pengumuman hanya ke pelamar terpilih.
              </p>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="grid gap-3 md:grid-cols-2">
                <div className="space-y-1.5 md:col-span-2">
                  <Label htmlFor="accepted-announcement-title">Judul</Label>
                  <Input
                    id="accepted-announcement-title"
                    value={announcementTitle}
                    onChange={(e) => setAnnouncementTitle(e.target.value)}
                    placeholder="Contoh: Info pemberkasan tahap diterima"
                    maxLength={200}
                  />
                </div>
                <div className="space-y-1.5 md:col-span-2">
                  <Label htmlFor="accepted-announcement-body">Isi pengumuman</Label>
                  <Textarea
                    id="accepted-announcement-body"
                    value={announcementBody}
                    onChange={(e) => setAnnouncementBody(e.target.value)}
                    placeholder="Tulis isi pengumuman untuk pelamar yang dipilih..."
                    rows={4}
                    maxLength={3000}
                  />
                </div>
              </div>
              <div className="flex items-center justify-between gap-2 flex-wrap">
                <span className="text-xs text-muted-foreground">
                  {selectedRecipientIds.length} pelamar terpilih
                </span>
                <Button
                  type="button"
                  size="sm"
                  className="cursor-pointer"
                  disabled={!canSendAnnouncement || sendAnnouncementMutation.isPending}
                  onClick={() => setConfirmAnnouncementOpen(true)}
                >
                  {sendAnnouncementMutation.isPending
                    ? "Mengirim..."
                    : "Kirim Pengumuman"}
                </Button>
              </div>
              {selectedRecipientNames.length > 0 && (
                <div className="rounded-md border bg-muted/30 p-3">
                  <p className="mb-1 text-xs font-medium text-foreground">
                    Preview penerima:
                  </p>
                  <p className="text-xs text-muted-foreground">
                    {selectedRecipientNames.slice(0, 8).join(", ")}
                    {selectedRecipientNames.length > 8
                      ? `, dan ${selectedRecipientNames.length - 8} pelamar lainnya`
                      : ""}
                  </p>
                </div>
              )}
            </CardContent>
          </Card>
        )}

        <div className="relative max-w-md">
          <IconSearch className="text-muted-foreground absolute left-3 top-1/2 size-4 -translate-y-1/2" />
          <Input
            placeholder="Cari nama, email, NIK, atau rujukan..."
            value={stageSearch}
            onChange={(e) => {
              setStageSearch(e.target.value)
              setPage(1)
            }}
            className="pl-9 h-9 text-sm"
            aria-label="Filter pelamar di tahap ini"
          />
        </div>

        <div className="overflow-hidden rounded-lg border">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  {enableAcceptedAnnouncement && (
                    <TableHead className="w-[42px]">
                      <Checkbox
                        checked={allSelectableChecked}
                        onCheckedChange={toggleSelectAllApplicants}
                        aria-label="Pilih semua pelamar di tabel"
                      />
                    </TableHead>
                  )}
                  <TableHead>Pelamar</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Tahapan / Batch</TableHead>
                  {showCohortCol && <TableHead>Sesi Interview</TableHead>}
                  {showDocCol && (
                    <TableHead className="min-w-[11rem]">
                      Pengumpulan Dokumen
                    </TableHead>
                  )}
                  <TableHead>Tanggal Lamar</TableHead>
                  <TableHead className="text-right w-[180px] sticky right-0 bg-background z-10">
                    Aksi
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredApps.length ? (
                  filteredApps.map((app) => (
                    <TableRow key={app.id} className="hover:bg-muted/50">
                      {enableAcceptedAnnouncement && (
                        <TableCell>
                          {app.applicant_user ? (
                            <Checkbox
                              checked={selectedApplicantUsers.has(app.applicant_user)}
                              onCheckedChange={() =>
                                toggleSelectApplicant(app.applicant_user as number)
                              }
                              aria-label={`Pilih ${app.applicant_name}`}
                            />
                          ) : null}
                        </TableCell>
                      )}
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
                      <TableCell className="text-sm text-muted-foreground">
                        {app.batch ? (
                          <button
                            type="button"
                            className="inline-flex items-center gap-1 text-primary underline-offset-2 hover:underline cursor-pointer"
                            onClick={() => navigate(`${batchBase}/${app.batch}`)}
                          >
                            {app.batch_tahap_label ?? app.batch_name ?? `Batch #${app.batch}`}
                            <IconExternalLink className="size-3" />
                          </button>
                        ) : (
                          "—"
                        )}
                      </TableCell>
                      {showCohortCol && (
                        <TableCell className="text-sm text-muted-foreground">
                          {app.interview_cohort != null ? (
                            <button
                              type="button"
                              className="inline-flex items-center gap-1 text-primary underline-offset-2 hover:underline cursor-pointer"
                              onClick={() =>
                                navigate(`${cohortBase}/${app.interview_cohort}`)
                              }
                            >
                              {app.interview_cohort_name ??
                                `Sesi #${app.interview_cohort}`}
                              <IconExternalLink className="size-3" />
                            </button>
                          ) : (
                            "—"
                          )}
                        </TableCell>
                      )}
                      {showDocCol && (
                        <TableCell className="text-sm align-top">
                          <DocumentCollectionProgressCell app={app} />
                        </TableCell>
                      )}
                      <TableCell className="text-sm text-muted-foreground">
                        {formatDate(app.applied_at)}
                      </TableCell>
                      <TableCell className="text-right sticky right-0 bg-background">
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
                  ))
                ) : (
                  <TableRow>
                    <TableCell
                      colSpan={emptyColSpan + (enableAcceptedAnnouncement ? 1 : 0)}
                      className="h-20 text-center text-muted-foreground"
                    >
                      Tidak ada pelamar dengan status ini.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          )}
        </div>

        {pageCount > 1 && (
          <div className="flex items-center justify-between gap-2 flex-wrap text-xs text-muted-foreground">
            <div>
              Halaman{" "}
              <span className="font-medium text-foreground">
                {currentPage} / {pageCount}
              </span>
            </div>
            <div className="flex items-center gap-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                className="h-7 px-2 cursor-pointer"
                disabled={currentPage <= 1 || isLoading}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
              >
                Sebelumnya
              </Button>
              <Button
                type="button"
                variant="outline"
                size="sm"
                className="h-7 px-2 cursor-pointer"
                disabled={currentPage >= pageCount || isLoading}
                onClick={() => setPage((p) => Math.min(pageCount, p + 1))}
              >
                Berikutnya
              </Button>
            </div>
          </div>
        )}
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
      <AlertDialog
        open={confirmAnnouncementOpen}
        onOpenChange={setConfirmAnnouncementOpen}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Kirim pengumuman ke pelamar terpilih?</AlertDialogTitle>
            <AlertDialogDescription asChild>
              <div className="space-y-2 text-sm text-muted-foreground">
                <p>
                  Pengumuman akan dikirim ke{" "}
                  <span className="font-medium text-foreground">
                    {selectedRecipientIds.length}
                  </span>{" "}
                  pelamar di tahap Diterima.
                </p>
                {selectedRecipientNames.length > 0 && (
                  <p className="text-xs">
                    {selectedRecipientNames.slice(0, 10).join(", ")}
                    {selectedRecipientNames.length > 10
                      ? `, dan ${selectedRecipientNames.length - 10} lainnya`
                      : ""}
                  </p>
                )}
              </div>
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel
              type="button"
              className="cursor-pointer"
              disabled={sendAnnouncementMutation.isPending}
            >
              Batal
            </AlertDialogCancel>
            <AlertDialogAction
              type="button"
              className="cursor-pointer"
              disabled={!canSendAnnouncement || sendAnnouncementMutation.isPending}
              onClick={(e) => {
                e.preventDefault()
                sendAnnouncementMutation.mutate()
              }}
            >
              {sendAnnouncementMutation.isPending
                ? "Mengirim..."
                : "Ya, Kirim Pengumuman"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  )
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

export function AdminJobDetailPage() {
  const { id } = useParams<{ id: string }>()
  const jobId = Number(id)
  const navigate = useNavigate()
  const location = useLocation()
  const { basePath } = useAdminDashboard()
  const { user } = useAuth()
  const jobsBase = `${basePath}/lowongan-kerja`
  const batchBase = `${basePath}/batch`
  const cohortBase = `${basePath}/sesi-interview`
  const lamaranBase = `${basePath}/lamaran`
  const pelamarBase = `${basePath}/pelamar`
  const readOnlyJob = user ? isRestrictedAdmin(user.role as UserRole) : false
  const pathIsEdit = location.pathname.endsWith("/edit")
  const initialTab = readOnlyJob ? "pra_seleksi" : pathIsEdit ? "edit" : "pra_seleksi"
  const [activeTab, setActiveTab] = useState(initialTab)

  // Sync tab when URL changes (e.g. browser back/forward)
  useEffect(() => {
    if (readOnlyJob) return
    setActiveTab(location.pathname.endsWith("/edit") ? "edit" : activeTab)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [location.pathname, readOnlyJob])

  const {
    data: job,
    isLoading,
    isError,
  } = useQuery({
    queryKey: ["job", jobId],
    queryFn: () => getJob(jobId),
  })

  usePageTitle(job ? job.title : "Detail Lowongan")

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-24">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    )
  }

  if (isError || !job) {
    return (
      <div className="p-6">
        <p className="text-destructive">Lowongan tidak ditemukan.</p>
        <Button
          variant="outline"
          className="mt-4 cursor-pointer"
          onClick={() => goBackOrDefault(navigate, jobsBase)}
        >
          <IconArrowLeft className="mr-2 size-4" />
          Kembali
        </Button>
      </div>
    )
  }

  if (readOnlyJob && location.pathname.endsWith("/edit")) {
    return <Navigate to={`${jobsBase}/${jobId}`} replace />
  }

  const statusInfo =
    JOB_STATUS_MAP[job.status] ?? { label: job.status, variant: "outline" as const }

  return (
    <div className="flex flex-col gap-6 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: basePath || "/" },
          { label: "Lowongan Kerja", href: jobsBase },
          { label: job.title },
        ]}
      />

      {/* Header */}
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div className="flex items-center gap-3">
          <Button
            variant="ghost"
            size="icon"
            className="cursor-pointer shrink-0"
            onClick={() => goBackOrDefault(navigate, jobsBase)}
          >
            <IconArrowLeft className="size-5" />
          </Button>
          <div>
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-2xl font-bold">{job.title}</h1>
              <Badge variant={statusInfo.variant}>{statusInfo.label}</Badge>
            </div>
            <p className="text-muted-foreground text-sm mt-0.5">
              {job.company_name ?? "—"}
            </p>
          </div>
        </div>
        {!readOnlyJob && (
          <Button
            variant="outline"
            className="cursor-pointer"
            onClick={() => {
              setActiveTab("edit")
              navigate(`${jobsBase}/${jobId}/edit`, { replace: true })
            }}
          >
            <IconPencil className="mr-2 size-4" />
            Edit Lowongan
          </Button>
        )}
      </div>

      {/* Tabs */}
      <Tabs
        value={activeTab}
        onValueChange={(tab) => {
          setActiveTab(tab)
          if (readOnlyJob) return
          if (tab === "edit") {
            navigate(`${jobsBase}/${jobId}/edit`, { replace: true })
          } else if (location.pathname.endsWith("/edit")) {
            navigate(`${jobsBase}/${jobId}`, { replace: true })
          }
        }}
      >
        <TabsList className="h-auto flex-wrap gap-1">
          <TabsTrigger value="info">Info</TabsTrigger>
          {!readOnlyJob && <TabsTrigger value="edit">Edit</TabsTrigger>}
          <TabsTrigger value="pra_seleksi" className="gap-1.5">
            <IconClipboardList className="size-4" />
            Pra-Seleksi
          </TabsTrigger>
          <TabsTrigger value="interview" className="gap-1.5">
            <IconUsersGroup className="size-4" />
            Interview
          </TabsTrigger>
          {DOWNSTREAM_STATUS_TABS.map((t) => (
            <TabsTrigger key={t.value} value={t.value} className="gap-1.5">
              {t.value === "DITERIMA" ? <IconUserCheck className="size-4" /> : null}
              {t.label}
            </TabsTrigger>
          ))}
        </TabsList>

        {/* ── Info tab ──────────────────────────────────────────────────── */}
        <TabsContent value="info" className="mt-4">
          <div className="grid gap-4 md:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle className="text-base flex items-center gap-2">
                  <IconBriefcase className="size-4" />
                  Detail Pekerjaan
                </CardTitle>
              </CardHeader>
              <CardContent className="flex flex-col gap-3 text-sm">
                <Row label="Negara">
                  <div className="flex items-center gap-1">
                    <IconMapPin className="size-3.5 text-muted-foreground" />
                    {job.location_country || "-"}
                  </div>
                </Row>
                <Row label="Kota">{job.location_city || "-"}</Row>
                <Row label="Tipe">
                  {EMPLOYMENT_TYPE_MAP[job.employment_type] ?? job.employment_type}
                </Row>
                {(job.salary_min || job.salary_max) && (
                  <Row label="Gaji">
                    {job.salary_min?.toLocaleString("id") ?? "?"} –{" "}
                    {job.salary_max?.toLocaleString("id") ?? "?"} {job.currency}
                  </Row>
                )}
                <Row label="Kuota">{job.quota ?? "-"}</Row>
                <Row label="Mulai Bekerja">
                  <div className="flex items-center gap-1">
                    <IconCalendar className="size-3.5 text-muted-foreground" />
                    {formatDate(job.start_date)}
                  </div>
                </Row>
                <Row label="Deadline">{formatDate(job.deadline)}</Row>
                <Row label="Diposting">{formatDate(job.posted_at)}</Row>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="text-base flex items-center gap-2">
                  <IconBuilding className="size-4" />
                  Perusahaan
                </CardTitle>
              </CardHeader>
              <CardContent className="text-sm">{job.company_name ?? "-"}</CardContent>
            </Card>

            <Card className="md:col-span-2">
              <CardHeader>
                <CardTitle className="text-base">Deskripsi</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-sm whitespace-pre-wrap">
                  {job.description || "-"}
                </p>
              </CardContent>
            </Card>

            <Card className="md:col-span-2">
              <CardHeader>
                <CardTitle className="text-base">Persyaratan</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-sm whitespace-pre-wrap">
                  {job.requirements || "-"}
                </p>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* ── Edit tab ──────────────────────────────────────────────────── */}
        <TabsContent value="edit" className="mt-4">
          <EditTab jobId={jobId} job={job} jobsBase={jobsBase} />
        </TabsContent>

        {/* ── Pra-Seleksi tab (batches/tahapan) ─────────────────────────── */}
        <TabsContent value="pra_seleksi" className="mt-4">
          <PraSeleksiTab
            jobId={jobId}
            jobsBase={jobsBase}
            batchBase={batchBase}
          />
        </TabsContent>

        {/* ── Interview tab (cohorts) ───────────────────────────────────── */}
        <TabsContent value="interview" className="mt-4">
          <InterviewCohortsTab
            jobId={jobId}
            jobsBase={jobsBase}
            cohortBase={cohortBase}
          />
        </TabsContent>

        {/* ── Downstream per-status tabs ────────────────────────────────── */}
        {DOWNSTREAM_STATUS_TABS.map((t) => (
          <TabsContent key={t.value} value={t.value} className="mt-4">
            <ApplicationsTab
              jobId={jobId}
              status={t.value}
              batchBase={batchBase}
              cohortBase={cohortBase}
              lamaranBase={lamaranBase}
              pelamarBase={pelamarBase}
            />
          </TabsContent>
        ))}
      </Tabs>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Tiny helper
// ---------------------------------------------------------------------------

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex gap-2">
      <span className="w-32 shrink-0 text-muted-foreground">{label}</span>
      <span>{children}</span>
    </div>
  )
}
