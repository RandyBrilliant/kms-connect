/**
 * Quick assign: add this pelamar to an OPEN job's batch from the pelamar detail page.
 * Uses the same batch assign API as the batch detail "Tambah pelamar" flow.
 */

import { useEffect, useMemo, useState } from "react"
import { Link } from "react-router-dom"
import { IconLoader, IconUserPlus } from "@tabler/icons-react"

import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Label } from "@/components/ui/label"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { joinAdminPath } from "@/contexts/admin-dashboard-context"
import {
  useAssignApplicantsToBatchMutation,
  useBatchesForJobQuery,
} from "@/hooks/use-batches-query"
import { useOpenJobsForAssignQuery } from "@/hooks/use-jobs-query"
import { toast } from "@/lib/toast"
import type { JobApplication } from "@/types/job-applications"
import { ACTIVE_APPLICATION_STATUSES } from "@/types/job-applications"

export interface ApplicantLamaranQuickAssignProps {
  applicantProfileId: number
  applications: JobApplication[]
  /** Admin dashboard base path (e.g. staff vs master prefix). */
  basePath: string
  disabled?: boolean
}

export function ApplicantLamaranQuickAssign({
  applicantProfileId,
  applications,
  basePath,
  disabled = false,
}: ApplicantLamaranQuickAssignProps) {
  const { data: jobsData, isLoading: jobsLoading } = useOpenJobsForAssignQuery(
    !disabled
  )
  const [jobIdStr, setJobIdStr] = useState("")
  const selectedJobId = jobIdStr ? Number(jobIdStr) : null

  const { data: batchesData, isLoading: batchesLoading } = useBatchesForJobQuery(
    selectedJobId,
    !disabled && selectedJobId != null
  )

  const [batchIdStr, setBatchIdStr] = useState("")
  const [note, setNote] = useState("")

  const assignMutation = useAssignApplicantsToBatchMutation()

  const jobsWithActiveApplication = useMemo(() => {
    const blocked = new Set<number>()
    for (const a of applications) {
      if (ACTIVE_APPLICATION_STATUSES.includes(a.status)) {
        blocked.add(a.job)
      }
    }
    return blocked
  }, [applications])

  const openJobs = jobsData?.results ?? []
  const assignableJobs = useMemo(
    () => openJobs.filter((j) => !jobsWithActiveApplication.has(j.id)),
    [openJobs, jobsWithActiveApplication]
  )

  const batches = batchesData?.results ?? []

  useEffect(() => {
    setBatchIdStr("")
  }, [selectedJobId])

  const handleAssign = async () => {
    const batchId = batchIdStr ? Number(batchIdStr) : null
    if (!batchId) {
      toast.error("Pilih batch", "Pilih batch lamaran terlebih dahulu.")
      return
    }
    try {
      const result = await assignMutation.mutateAsync({
        batchId,
        applicantProfileIds: [applicantProfileId],
        note,
      })
      if (result.assigned_count > 0) {
        toast.success(
          "Pelamar ditambahkan",
          "Lamaran dibuat dan pelamar masuk ke batch yang dipilih."
        )
        setNote("")
        setBatchIdStr("")
        setJobIdStr("")
        return
      }
      const skip = result.skipped?.[0]
      toast.error(
        "Tidak dapat menambahkan",
        skip?.reason ?? "Pelamar tidak memenuhi syarat atau sudah terdaftar."
      )
    } catch (err: unknown) {
      const res = err as {
        response?: { data?: { detail?: string; errors?: unknown } }
      }
      const detail = res?.response?.data?.detail
      toast.error("Gagal menambahkan ke batch", detail ?? "Coba lagi nanti.")
    }
  }

  const jobsBlocked =
    !jobsLoading && openJobs.length > 0 && assignableJobs.length === 0
  const noOpenJobs = !jobsLoading && openJobs.length === 0

  const selectedBatchId = batchIdStr ? Number(batchIdStr) : null
  const createBatchHref =
    selectedJobId != null
      ? joinAdminPath(basePath, `/lowongan-kerja/${selectedJobId}/batch/new`)
      : null

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Tambahkan ke batch lamaran</CardTitle>
        <CardDescription>
          Pilih lowongan yang statusnya dibuka, lalu batch tujuan. Alur ini sama dengan
          menambahkan pelamar dari halaman detail batch.
        </CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        {disabled ? (
          <p className="text-muted-foreground text-sm">Memuat data lamaran…</p>
        ) : jobsLoading ? (
          <div className="flex items-center gap-2 text-muted-foreground text-sm">
            <IconLoader className="size-4 animate-spin" />
            Memuat lowongan…
          </div>
        ) : noOpenJobs ? (
          <p className="text-muted-foreground text-sm">
            Tidak ada lowongan dengan status Dibuka. Buka lowongan baru atau ubah status
            lowongan di menu Lowongan Kerja.
          </p>
        ) : jobsBlocked ? (
          <p className="text-muted-foreground text-sm">
            Pelamar sudah memiliki lamaran aktif (pra-seleksi, interview, diterima, atau
            berangkat) pada semua lowongan yang sedang dibuka. Selesaikan atau tolak lamaran
            yang ada sebelum menugaskan ke lowongan yang sama.
          </p>
        ) : (
          <>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="quick-assign-job">Lowongan</Label>
              <Select
                value={jobIdStr || undefined}
                onValueChange={(v) => setJobIdStr(v)}
              >
                <SelectTrigger id="quick-assign-job" className="cursor-pointer w-full max-w-lg">
                  <SelectValue placeholder="Pilih lowongan…" />
                </SelectTrigger>
                <SelectContent>
                  {assignableJobs.map((j) => (
                    <SelectItem key={j.id} value={String(j.id)}>
                      {j.title}
                      {j.company_name ? ` — ${j.company_name}` : ""}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {selectedJobId != null && (
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="quick-assign-batch">Batch</Label>
                {batchesLoading ? (
                  <div className="flex items-center gap-2 text-muted-foreground text-sm">
                    <IconLoader className="size-4 animate-spin" />
                    Memuat batch…
                  </div>
                ) : batches.length === 0 ? (
                  <div className="rounded-md border border-dashed p-3 text-sm">
                    <p className="text-muted-foreground">
                      Belum ada batch untuk lowongan ini. Buat batch terlebih dahulu.
                    </p>
                    {createBatchHref ? (
                      <Button variant="link" className="mt-1 h-auto p-0 cursor-pointer" asChild>
                        <Link to={createBatchHref}>Buat batch baru</Link>
                      </Button>
                    ) : null}
                  </div>
                ) : (
                  <Select
                    value={batchIdStr || undefined}
                    onValueChange={(v) => setBatchIdStr(v)}
                  >
                    <SelectTrigger id="quick-assign-batch" className="cursor-pointer w-full max-w-lg">
                      <SelectValue placeholder="Pilih batch…" />
                    </SelectTrigger>
                    <SelectContent>
                      {batches.map((b) => (
                        <SelectItem key={b.id} value={String(b.id)}>
                          {b.name}
                          {typeof b.applicant_count === "number"
                            ? ` (${b.applicant_count} pelamar)`
                            : ""}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              </div>
            )}

            {selectedBatchId != null && batches.some((b) => b.id === selectedBatchId) ? (
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="quick-assign-note">
                  Catatan penugasan <span className="text-muted-foreground">(opsional)</span>
                </Label>
                <Textarea
                  id="quick-assign-note"
                  rows={2}
                  placeholder="Catatan internal untuk lamaran ini…"
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  className="max-w-lg resize-none"
                />
              </div>
            ) : null}

            {selectedJobId != null && batches.length > 0 && selectedBatchId != null ? (
              <div className="flex flex-wrap items-center gap-2">
                <Button
                  type="button"
                  className="cursor-pointer"
                  disabled={assignMutation.isPending}
                  onClick={() => void handleAssign()}
                >
                  {assignMutation.isPending ? (
                    <>
                      <IconLoader className="mr-2 size-4 animate-spin" />
                      Memproses…
                    </>
                  ) : (
                    <>
                      <IconUserPlus className="mr-2 size-4" />
                      Tambahkan ke batch
                    </>
                  )}
                </Button>
              </div>
            ) : null}
          </>
        )}
      </CardContent>
    </Card>
  )
}
