/**
 * Admin — Job Detail page.
 *
 * Tabs:
 *  - Info        — job metadata (editable via Edit button)
 *  - Batch       — list of batches for this job + create new
 *  - Pra-Seleksi — applications at PRA_SELEKSI
 *  - Interview   — applications at INTERVIEW
 *  - Diterima    — applications at DITERIMA
 *  - Berangkat   — applications at BERANGKAT
 *  - Selesai     — applications at SELESAI
 *  - Ditolak     — applications at DITOLAK
 */

import { type ReactNode, useState, useEffect } from "react"
import { Link, Navigate, useLocation, useNavigate, useParams } from "react-router-dom"
import { useQuery } from "@tanstack/react-query"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
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
  IconUsers,
} from "@tabler/icons-react"

import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { ApplicationStatusBadge } from "@/components/applications/application-status-badge"
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

import { getJob } from "@/api/jobs"
import { getBatches } from "@/api/batches"
import { getApplications } from "@/api/applications"
import type { JobItem, EmploymentType, JobStatus as JobStatusType } from "@/types/jobs"
import type { ApplicationStatus } from "@/types/job-applications"

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatDate(v: string | null | undefined) {
  if (!v) return "-"
  return format(new Date(v), "dd MMM yyyy", { locale: idLocale })
}

const JOB_STATUS_MAP: Record<string, { label: string; variant: "default" | "secondary" | "outline" | "destructive" }> = {
  OPEN:     { label: "Dibuka",       variant: "default" },
  DRAFT:    { label: "Draf",         variant: "secondary" },
  CLOSED:   { label: "Ditutup",      variant: "outline" },
  ARCHIVED: { label: "Diarsipkan",   variant: "destructive" },
}

const EMPLOYMENT_TYPE_MAP: Record<string, string> = {
  FULL_TIME:   "Penuh Waktu",
  PART_TIME:   "Paruh Waktu",
  CONTRACT:    "Kontrak",
  INTERNSHIP:  "Magang",
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
// Sub-component: Batch list
// ---------------------------------------------------------------------------

function BatchListTab({
  jobId,
  jobsBase,
  batchBase,
}: {
  jobId: number
  jobsBase: string
  batchBase: string
}) {
  const navigate = useNavigate()

  const { data, isLoading } = useQuery({
    queryKey: ["batches", { job: jobId }],
    queryFn: () => getBatches({ job: jobId, page_size: 100 }),
  })

  const batches = data?.results ?? []

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">
          {batches.length} batch ditemukan
        </p>
        <Button
          size="sm"
          className="cursor-pointer"
          onClick={() => navigate(`${jobsBase}/${jobId}/batch/new`)}
        >
          <IconPlus className="mr-2 size-4" />
          Buat Batch Baru
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
                <TableHead>Nama Batch</TableHead>
                <TableHead className="text-center">Pelamar</TableHead>
                <TableHead>Jadwal Pra-Seleksi</TableHead>
                <TableHead>Jadwal Interview</TableHead>
                <TableHead>Dibuat</TableHead>
                <TableHead />
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
                      <div className="flex items-center gap-2">
                        <IconClipboardList className="size-4 shrink-0 text-muted-foreground" />
                        <span className="font-medium">{batch.name}</span>
                      </div>
                    </TableCell>
                    <TableCell className="text-center">
                      <div className="flex items-center justify-center gap-1">
                        <IconUsers className="size-3.5 text-muted-foreground" />
                        {batch.applicant_count}
                      </div>
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {batch.pra_seleksi_date
                        ? format(new Date(batch.pra_seleksi_date), "dd MMM yyyy", { locale: idLocale })
                        : "-"}
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {batch.interview_date
                        ? format(new Date(batch.interview_date), "dd MMM yyyy", { locale: idLocale })
                        : "-"}
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {formatDate(batch.created_at)}
                    </TableCell>
                    <TableCell onClick={(e) => e.stopPropagation()}>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="size-8 cursor-pointer"
                        onClick={() => navigate(`${batchBase}/${batch.id}`)}
                        title="Lihat detail batch"
                      >
                        <IconEye className="size-4" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell colSpan={6} className="h-24 text-center text-muted-foreground">
                    Belum ada batch untuk lowongan ini.{" "}
                    <button
                      className="text-primary underline-offset-2 hover:underline cursor-pointer"
                      onClick={() => navigate(`${jobsBase}/${jobId}/batch/new`)}
                    >
                      Buat batch pertama
                    </button>
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        )}
      </div>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Sub-component: Applications per status
// ---------------------------------------------------------------------------

function ApplicationsTab({
  jobId,
  status,
  batchBase,
  lamaranBase,
  pelamarBase,
}: {
  jobId: number
  status: ApplicationStatus
  batchBase: string
  lamaranBase: string
  pelamarBase: string
}) {
  const navigate = useNavigate()

  const { data, isLoading } = useQuery({
    queryKey: ["applications", { job: jobId, status }],
    queryFn: () => getApplications({ job: jobId, status, page_size: 100 }),
  })

  const apps = data?.results ?? []

  return (
    <div className="flex flex-col gap-4">
      <p className="text-sm text-muted-foreground">
        {data?.count ?? 0} pelamar
      </p>

      <div className="overflow-hidden rounded-lg border">
        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          </div>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Pelamar</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Batch</TableHead>
                <TableHead>Tanggal Lamar</TableHead>
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
                    <TableCell className="text-sm text-muted-foreground">
                      {app.batch ? (
                        <button
                          className="text-primary underline-offset-2 hover:underline cursor-pointer"
                          onClick={() => navigate(`${batchBase}/${app.batch}`)}
                        >
                          {app.batch_name ?? `Batch #${app.batch}`}
                        </button>
                      ) : (
                        "-"
                      )}
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {formatDate(app.applied_at)}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-1">
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-8 cursor-pointer"
                          onClick={() => navigate(`${lamaranBase}/${app.id}`)}
                          title="Lihat detail lamaran"
                        >
                          <IconEye className="size-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-8 cursor-pointer"
                          onClick={() => navigate(`${pelamarBase}/${app.applicant}`)}
                          title="Edit profil pelamar"
                        >
                          <IconPencil className="size-4" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell
                    colSpan={5}
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
  const lamaranBase = `${basePath}/lamaran`
  const pelamarBase = `${basePath}/pelamar`
  const readOnlyJob = user ? isRestrictedAdmin(user.role as UserRole) : false
  const pathIsEdit = location.pathname.endsWith("/edit")
  const initialTab = readOnlyJob ? "batch" : pathIsEdit ? "edit" : "batch"
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
        <Button asChild variant="outline" className="mt-4 cursor-pointer">
          <Link to={jobsBase}>
            <IconArrowLeft className="mr-2 size-4" />
            Kembali
          </Link>
        </Button>
      </div>
    )
  }

  if (readOnlyJob && location.pathname.endsWith("/edit")) {
    return <Navigate to={`${jobsBase}/${jobId}`} replace />
  }

  const statusInfo = JOB_STATUS_MAP[job.status] ?? { label: job.status, variant: "outline" as const }

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
            asChild
            variant="ghost"
            size="icon"
            className="cursor-pointer shrink-0"
          >
            <Link to={jobsBase}>
              <IconArrowLeft className="size-5" />
            </Link>
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
      <Tabs value={activeTab} onValueChange={(tab) => {
        setActiveTab(tab)
        if (readOnlyJob) return
        // keep URL in sync: edit tab → /edit path, others → base path
        if (tab === "edit") {
          navigate(`${jobsBase}/${jobId}/edit`, { replace: true })
        } else if (location.pathname.endsWith("/edit")) {
          navigate(`${jobsBase}/${jobId}`, { replace: true })
        }
      }}>
        <TabsList className="h-auto flex-wrap gap-1">
          <TabsTrigger value="info">Info</TabsTrigger>
          {!readOnlyJob && <TabsTrigger value="edit">Edit</TabsTrigger>}
          <TabsTrigger value="batch">Batch</TabsTrigger>
          {STATUS_TABS.map((t) => (
            <TabsTrigger key={t.value} value={t.value}>
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
                <Row label="Tipe">{EMPLOYMENT_TYPE_MAP[job.employment_type] ?? job.employment_type}</Row>
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
              <CardContent className="text-sm">
                {job.company_name ?? "-"}
              </CardContent>
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

        {/* ── Batch tab ─────────────────────────────────────────────────── */}
        <TabsContent value="batch" className="mt-4">
          <BatchListTab jobId={jobId} jobsBase={jobsBase} batchBase={batchBase} />
        </TabsContent>

        {/* ── Per-status tabs ────────────────────────────────────────────── */}
        {STATUS_TABS.map((t) => (
          <TabsContent key={t.value} value={t.value} className="mt-4">
            <ApplicationsTab
              jobId={jobId}
              status={t.value}
              batchBase={batchBase}
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

function Row({
  label,
  children,
}: {
  label: string
  children: ReactNode
}) {
  return (
    <div className="flex gap-2">
      <span className="w-32 shrink-0 text-muted-foreground">{label}</span>
      <span>{children}</span>
    </div>
  )
}
