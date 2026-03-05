/**
 * Admin — Create Batch page.
 * Reached from /lowongan-kerja/:id/batch/new.
 * Pre-fills the job from the URL param; admin only sets name + notes.
 */

import { useState } from "react"
import { Link, useNavigate, useParams } from "react-router-dom"
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
import { usePageTitle } from "@/hooks/use-page-title"

import { getJob } from "@/api/jobs"
import { createBatch } from "@/api/batches"
import { toast } from "@/lib/toast"

export function AdminBatchFormPage() {
  const { id } = useParams<{ id: string }>()
  const jobId = Number(id)
  const navigate = useNavigate()

  usePageTitle("Buat Batch Baru")

  const queryClient = useQueryClient()

  const { data: job, isLoading: loadingJob } = useQuery({
    queryKey: ["job", jobId],
    queryFn: () => getJob(jobId),
  })

  const [name, setName] = useState("")
  const [notes, setNotes] = useState("")
  const [loading, setLoading] = useState(false)

  const handleSubmit = async () => {
    if (!name.trim()) return
    setLoading(true)
    try {
      const batch = await createBatch({
        job: jobId,
        name: name.trim(),
        notes: notes.trim(),
      })
      await queryClient.invalidateQueries({ queryKey: ["batches", { job: jobId }] })
      toast.success("Batch berhasil dibuat.")
      navigate(`/batch/${batch.id}`)
    } catch {
      toast.error("Gagal membuat batch.")
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex flex-col gap-6 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Lowongan Kerja", href: "/lowongan-kerja" },
          {
            label: job?.title ?? "...",
            href: `/lowongan-kerja/${jobId}`,
          },
          { label: "Buat Batch Baru" },
        ]}
      />

      <div className="flex items-center gap-3">
        <Button
          asChild
          variant="ghost"
          size="icon"
          className="cursor-pointer shrink-0"
        >
          <Link to={`/lowongan-kerja/${jobId}`}>
            <IconArrowLeft className="size-5" />
          </Link>
        </Button>
        <div>
          <h1 className="text-2xl font-bold">Buat Batch Baru</h1>
          {job && (
            <p className="text-sm text-muted-foreground">
              {job.title}
              {job.company_name ? ` — ${job.company_name}` : ""}
            </p>
          )}
        </div>
      </div>

      <Card className="max-w-lg">
        <CardHeader>
          <CardTitle>Detail Batch</CardTitle>
          <CardDescription>
            Batch mengelompokkan pelamar yang akan menjalani seleksi bersama
            untuk satu lowongan kerja.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {loadingJob ? (
            <div className="flex items-center justify-center py-8">
              <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : (
            <div className="flex flex-col gap-4">
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="batch-name">
                  Nama Batch <span className="text-destructive">*</span>
                </Label>
                <Input
                  id="batch-name"
                  placeholder="Contoh: Batch Maret 2026"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && handleSubmit()}
                />
              </div>

              <div className="flex flex-col gap-1.5">
                <Label htmlFor="batch-notes">
                  Catatan{" "}
                  <span className="text-muted-foreground text-xs">
                    (opsional)
                  </span>
                </Label>
                <Textarea
                  id="batch-notes"
                  placeholder="Catatan internal mengenai batch ini..."
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  rows={3}
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <Button
                  asChild
                  variant="outline"
                  className="cursor-pointer"
                >
                  <Link to={`/lowongan-kerja/${jobId}`}>Batal</Link>
                </Button>
                <Button
                  onClick={handleSubmit}
                  disabled={!name.trim() || loading}
                  className="cursor-pointer"
                >
                  {loading ? "Menyimpan..." : "Buat Batch"}
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
