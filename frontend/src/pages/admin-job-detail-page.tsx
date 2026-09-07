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

import { lazy, Suspense, type ReactNode, useState, useEffect } from "react"
import { Navigate, useLocation, useNavigate, useParams } from "react-router-dom"
import { keepPreviousData, useQuery } from "@tanstack/react-query"
import {
  IconArrowLeft,
  IconBriefcase,
  IconBuilding,
  IconCalendar,
  IconClipboardList,
  IconEye,
  IconMapPin,
  IconPencil,
  IconPlus,
  IconUserCheck,
  IconUsers,
  IconUsersGroup,
} from "@tabler/icons-react"

import { BreadcrumbNav } from "@/components/breadcrumb-nav"
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
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { usePageTitle } from "@/hooks/use-page-title"
import { useAdminDashboard } from "@/contexts/admin-dashboard-context"
import { useAuth } from "@/hooks/use-auth"
import { isRestrictedAdmin, type UserRole } from "@/types/auth"

import { JobForm } from "@/components/jobs/job-form"
import { useUpdateJobMutation } from "@/hooks/use-jobs-query"
import { toast } from "@/lib/toast"
import { cn } from "@/lib/utils"
import { goBackOrDefault } from "@/lib/back-navigation"

import { getJob } from "@/api/jobs"
import { getBatches } from "@/api/batches"
import { getInterviewCohorts } from "@/api/interview-cohorts"
import { getApplications } from "@/api/applications"
import type { JobItem, EmploymentType, JobStatus as JobStatusType } from "@/types/jobs"
import { type ApplicationStatus } from "@/types/job-applications"
import {
  APPLICATIONS_TAB_PAGE_SIZE,
  JOB_DETAIL_TABLE_SHELL,
  JD_BODY_ROW,
  JD_HEADER_ROW,
  JobDetailPagination,
  MASTER_TAHAPAN_PAGE_SIZE,
  formatDate,
  formatDateTime,
  jdTd,
  jdTh,
} from "./admin-job-detail-shared"

const ApplicationsTab = lazy(() => import("./admin-job-detail-applications-tab"))

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
// Sub-component: Diterima pra-seleksi (job-wide pool ready for interview)
// ---------------------------------------------------------------------------

function JobPraSeleksiPassedTab({
  jobId,
  batchBase,
  pelamarBase,
  enabled = true,
}: {
  jobId: number
  batchBase: string
  pelamarBase: string
  enabled?: boolean
}) {
  const navigate = useNavigate()
  const [page, setPage] = useState(1)

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ["applications", { job: jobId, praPassed: true, page }],
    queryFn: () =>
      getApplications({
        job: jobId,
        status: "PRA_SELEKSI",
        pra_seleksi_passed: true,
        page,
        page_size: APPLICATIONS_TAB_PAGE_SIZE,
        ordering: "applicant_name",
      }),
    enabled,
    placeholderData: keepPreviousData,
  })

  const apps = data?.results ?? []
  const totalCount = data?.count ?? 0
  const pageCount = Math.max(1, Math.ceil(totalCount / APPLICATIONS_TAB_PAGE_SIZE))
  const currentPage = Math.min(page, pageCount)

  useEffect(() => {
    setPage((p) => Math.min(p, pageCount))
  }, [pageCount])

  return (
    <div className="flex flex-col gap-4">
      <p className="text-sm text-muted-foreground">
        {totalCount} pelamar ditandai diterima pra-seleksi dan siap dipindahkan ke
        sesi interview. Kelola per batch dari halaman detail tahapan.
      </p>
      <div className={JOB_DETAIL_TABLE_SHELL}>
        {isLoading && !data ? (
          <div className="flex min-h-[14rem] items-center justify-center">
            <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          </div>
        ) : (
          <Table className="border-collapse">
            <TableHeader>
              <TableRow className={JD_HEADER_ROW}>
                <TableHead className={jdTh()}>Pelamar</TableHead>
                <TableHead className={jdTh()}>Tahapan</TableHead>
                <TableHead className={jdTh()}>Diterima pada</TableHead>
                <TableHead className={jdTh("w-[60px]")} />
              </TableRow>
            </TableHeader>
            <TableBody>
              {apps.length ? (
                apps.map((app) => (
                  <TableRow key={app.id} className={JD_BODY_ROW}>
                    <TableCell className={jdTd()}>
                      <div className="flex flex-col gap-0.5">
                        <span className="font-medium">{app.applicant_name}</span>
                        <span className="text-xs text-muted-foreground">
                          {app.applicant_nik || app.applicant_email}
                        </span>
                      </div>
                    </TableCell>
                    <TableCell className={jdTd()}>
                      {app.batch ? (
                        <button
                          type="button"
                          className="text-primary text-sm underline-offset-2 hover:underline cursor-pointer"
                          onClick={() => navigate(`${batchBase}/${app.batch}`)}
                        >
                          {app.batch_tahap_label || app.batch_name || `Batch #${app.batch}`}
                        </button>
                      ) : (
                        "—"
                      )}
                    </TableCell>
                    <TableCell className={jdTd("text-sm text-muted-foreground")}>
                      {app.pra_seleksi_passed_at
                        ? formatDate(app.pra_seleksi_passed_at)
                        : "—"}
                    </TableCell>
                    <TableCell className={jdTd()}>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="size-8 cursor-pointer"
                        onClick={() =>
                          navigate(`${pelamarBase}/${app.applicant_user ?? app.applicant}`)
                        }
                        title="Lihat pelamar"
                      >
                        <IconEye className="size-4" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow className="hover:bg-transparent">
                  <TableCell
                    colSpan={4}
                    className={jdTd("h-24 text-center text-muted-foreground")}
                  >
                    Belum ada pelamar yang ditandai diterima pra-seleksi.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        )}
      </div>
      <JobDetailPagination
        pageSize={APPLICATIONS_TAB_PAGE_SIZE}
        currentPage={currentPage}
        pageCount={pageCount}
        totalCount={totalCount}
        isFetching={isFetching}
        itemLabel="pelamar"
        onPrev={() => setPage((p) => Math.max(1, p - 1))}
        onNext={() => setPage((p) => p + 1)}
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
  pelamarBase,
  enabled = true,
}: {
  jobId: number
  jobsBase: string
  batchBase: string
  pelamarBase: string
  enabled?: boolean
}) {
  const navigate = useNavigate()
  const [page, setPage] = useState(1)
  const [innerTab, setInnerTab] = useState<"tahapan" | "passed">("tahapan")

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ["batches", { job: jobId, page, mode: "job-detail-master" }],
    queryFn: () =>
      getBatches({
        job: jobId,
        page,
        page_size: MASTER_TAHAPAN_PAGE_SIZE,
        ordering: "tahap_order,created_at",
      }),
    enabled,
    placeholderData: keepPreviousData,
  })

  const batches = data?.results ?? []
  const totalCount = data?.count ?? 0
  const pageCount = Math.max(1, Math.ceil(totalCount / MASTER_TAHAPAN_PAGE_SIZE))
  const currentPage = Math.min(page, pageCount)

  useEffect(() => {
    setPage((p) => Math.min(p, pageCount))
  }, [pageCount])

  return (
    <Tabs
      value={innerTab}
      onValueChange={(v) => setInnerTab(v as "tahapan" | "passed")}
      className="flex flex-col gap-4"
    >
      <TabsList>
        <TabsTrigger value="tahapan">Tahapan Pra-Seleksi</TabsTrigger>
        <TabsTrigger value="passed">Diterima Pra-Seleksi</TabsTrigger>
      </TabsList>

      <TabsContent value="passed" className="mt-0">
        <JobPraSeleksiPassedTab
          jobId={jobId}
          batchBase={batchBase}
          pelamarBase={pelamarBase}
          enabled={enabled && innerTab === "passed"}
        />
      </TabsContent>

      <TabsContent value="tahapan" className="mt-0 flex flex-col gap-4">
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

      <div className={JOB_DETAIL_TABLE_SHELL}>
        {isLoading && !data ? (
          <div className="flex min-h-[14rem] items-center justify-center">
            <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          </div>
        ) : (
          <Table className="border-collapse">
            <TableHeader>
              <TableRow className={JD_HEADER_ROW}>
                <TableHead className={jdTh()}>Nama Tahapan</TableHead>
                <TableHead className={jdTh("text-center")}>Total</TableHead>
                <TableHead className={jdTh("text-center")}>Diterima</TableHead>
                <TableHead className={jdTh("text-center")}>Lanjut Interview</TableHead>
                <TableHead className={jdTh("text-center")}>Ditolak</TableHead>
                <TableHead className={jdTh()}>Jadwal</TableHead>
                <TableHead className={jdTh("w-[60px]")} />
              </TableRow>
            </TableHeader>
            <TableBody>
              {batches.length ? (
                batches.map((batch) => (
                  <TableRow
                    key={batch.id}
                    className={cn(JD_BODY_ROW, "cursor-pointer")}
                    onClick={() => navigate(`${batchBase}/${batch.id}`)}
                  >
                    <TableCell className={jdTd()}>
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
                    <TableCell className={jdTd("text-center tabular-nums")}>
                      <span className="inline-flex items-center justify-center gap-1">
                        <IconUsers className="size-3.5 text-muted-foreground" />
                        {batch.applicant_count}
                      </span>
                    </TableCell>
                    <TableCell className={jdTd("text-center tabular-nums")}>
                      <Badge
                        variant="outline"
                        className="font-mono border-emerald-500/40 text-emerald-700 dark:text-emerald-400"
                      >
                        {batch.passed_pra_seleksi_count ?? 0}
                      </Badge>
                    </TableCell>
                    <TableCell className={jdTd("text-center tabular-nums")}>
                      <Badge
                        variant="default"
                        className="font-mono"
                        title="Sudah dipindahkan ke Sesi Interview / di tahap setelah pra-seleksi"
                      >
                        {batch.advanced_count}
                      </Badge>
                    </TableCell>
                    <TableCell className={jdTd("text-center tabular-nums")}>
                      <Badge
                        variant={batch.rejected_count ? "destructive" : "outline"}
                        className="font-mono"
                      >
                        {batch.rejected_count}
                      </Badge>
                    </TableCell>
                    <TableCell className={jdTd("text-sm text-muted-foreground")}>
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
                    <TableCell className={jdTd()} onClick={(e) => e.stopPropagation()}>
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
                <TableRow className="hover:bg-transparent">
                  <TableCell
                    colSpan={7}
                    className={jdTd("h-24 text-center text-muted-foreground")}
                  >
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

      <JobDetailPagination
        pageSize={MASTER_TAHAPAN_PAGE_SIZE}
        currentPage={currentPage}
        pageCount={pageCount}
        totalCount={totalCount}
        isFetching={isFetching}
        itemLabel="tahapan"
        onPrev={() => setPage((p) => Math.max(1, p - 1))}
        onNext={() => setPage((p) => p + 1)}
      />
      </TabsContent>
    </Tabs>
  )
}

// ---------------------------------------------------------------------------
// Sub-component: Interview cohorts tab
// ---------------------------------------------------------------------------

function InterviewCohortsTab({
  jobId,
  jobsBase,
  cohortBase,
  enabled = true,
}: {
  jobId: number
  jobsBase: string
  cohortBase: string
  enabled?: boolean
}) {
  const navigate = useNavigate()
  const [page, setPage] = useState(1)

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ["interview-cohorts", { job: jobId, page, mode: "job-detail" }],
    queryFn: () =>
      getInterviewCohorts({
        job: jobId,
        page,
        page_size: MASTER_TAHAPAN_PAGE_SIZE,
        ordering: "-interview_date,-created_at",
      }),
    enabled,
    placeholderData: keepPreviousData,
  })

  const cohorts = data?.results ?? []
  const totalCount = data?.count ?? 0
  const pageCount = Math.max(1, Math.ceil(totalCount / MASTER_TAHAPAN_PAGE_SIZE))
  const currentPage = Math.min(page, pageCount)

  useEffect(() => {
    setPage((p) => Math.min(p, pageCount))
  }, [pageCount])

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

      <div className={JOB_DETAIL_TABLE_SHELL}>
        {isLoading && !data ? (
          <div className="flex min-h-[14rem] items-center justify-center">
            <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          </div>
        ) : (
          <Table className="border-collapse">
            <TableHeader>
              <TableRow className={JD_HEADER_ROW}>
                <TableHead className={jdTh()}>Nama Sesi</TableHead>
                <TableHead className={jdTh()}>Jadwal Interview</TableHead>
                <TableHead className={jdTh("text-center")}>Total</TableHead>
                <TableHead className={jdTh("text-center")}>Interview</TableHead>
                <TableHead className={jdTh("text-center")}>Cadangan</TableHead>
                <TableHead className={jdTh("text-center")}>Diterima</TableHead>
                <TableHead className={jdTh("text-center")}>Ditolak</TableHead>
                <TableHead className={jdTh("w-[60px]")} />
              </TableRow>
            </TableHeader>
            <TableBody>
              {cohorts.length ? (
                cohorts.map((cohort) => (
                  <TableRow
                    key={cohort.id}
                    className={cn(JD_BODY_ROW, "cursor-pointer")}
                    onClick={() => navigate(`${cohortBase}/${cohort.id}`)}
                  >
                    <TableCell className={jdTd()}>
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
                    <TableCell className={jdTd("text-sm text-muted-foreground")}>
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
                    <TableCell className={jdTd("text-center tabular-nums")}>
                      <span className="inline-flex items-center justify-center gap-1">
                        <IconUsers className="size-3.5 text-muted-foreground" />
                        {cohort.applicant_count}
                      </span>
                    </TableCell>
                    <TableCell className={jdTd("text-center tabular-nums")}>
                      <Badge variant="secondary" className="font-mono">
                        {cohort.interview_count}
                      </Badge>
                    </TableCell>
                    <TableCell className={jdTd("text-center tabular-nums")}>
                      <Badge variant="outline" className="font-mono">
                        {cohort.cadangan_count}
                      </Badge>
                    </TableCell>
                    <TableCell className={jdTd("text-center tabular-nums")}>
                      <Badge
                        variant="outline"
                        className="font-mono border-emerald-500/40 text-emerald-700 dark:text-emerald-400"
                      >
                        {cohort.diterima_count}
                      </Badge>
                    </TableCell>
                    <TableCell className={jdTd("text-center tabular-nums")}>
                      <Badge
                        variant={cohort.ditolak_count ? "destructive" : "outline"}
                        className="font-mono"
                      >
                        {cohort.ditolak_count}
                      </Badge>
                    </TableCell>
                    <TableCell className={jdTd()} onClick={(e) => e.stopPropagation()}>
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
                <TableRow className="hover:bg-transparent">
                  <TableCell
                    colSpan={8}
                    className={jdTd("h-24 text-center text-muted-foreground")}
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

      <JobDetailPagination
        pageSize={MASTER_TAHAPAN_PAGE_SIZE}
        currentPage={currentPage}
        pageCount={pageCount}
        totalCount={totalCount}
        isFetching={isFetching}
        itemLabel="sesi"
        onPrev={() => setPage((p) => Math.max(1, p - 1))}
        onNext={() => setPage((p) => p + 1)}
      />
    </div>
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
            pelamarBase={pelamarBase}
            enabled={activeTab === "pra_seleksi"}
          />
        </TabsContent>

        {/* ── Interview tab (cohorts) ───────────────────────────────────── */}
        <TabsContent value="interview" className="mt-4">
          <InterviewCohortsTab
            jobId={jobId}
            jobsBase={jobsBase}
            cohortBase={cohortBase}
            enabled={activeTab === "interview"}
          />
        </TabsContent>

        {/* ── Downstream per-status tabs ────────────────────────────────── */}
        {DOWNSTREAM_STATUS_TABS.map((t) => (
          <TabsContent key={t.value} value={t.value} className="mt-4">
            <Suspense
              fallback={
                <div className="flex min-h-[12rem] items-center justify-center text-sm text-muted-foreground">
                  Memuat pelamar…
                </div>
              }
            >
              <ApplicationsTab
                jobId={jobId}
                status={t.value}
                batchBase={batchBase}
                cohortBase={cohortBase}
                pelamarBase={pelamarBase}
                enabled={activeTab === t.value}
              />
            </Suspense>
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
