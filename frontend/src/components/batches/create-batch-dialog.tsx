/**
 * Dialog to create a new LamaranBatch.
 * Admin picks a job and sets the batch name.
 */

import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { toast } from "@/lib/toast"
import { createBatch } from "@/api/batches"
import { api } from "@/lib/api"
import type { LamaranBatch } from "@/types/lamaran-batch"

import { Button } from "@/components/ui/button"
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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"

interface Job {
  id: number
  title: string
  company_name: string
}

interface CreateBatchDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  onSuccess: (batch: LamaranBatch) => void
}

export function CreateBatchDialog({
  open,
  onOpenChange,
  onSuccess,
}: CreateBatchDialogProps) {
  const [jobId, setJobId] = useState<string>("")
  const [name, setName] = useState("")
  const [notes, setNotes] = useState("")
  const [loading, setLoading] = useState(false)

  const { data: jobsPage } = useQuery({
    queryKey: ["jobs-open"],
    queryFn: async () => {
      const { data } = await api.get<{ results: Job[] }>("/api/jobs/?status=OPEN&page_size=200")
      return data
    },
    enabled: open,
  })

  const jobs = jobsPage?.results ?? []

  const handleSubmit = async () => {
    if (!jobId || !name.trim()) return
    setLoading(true)
    try {
      const batch = await createBatch({
        job: Number(jobId),
        name: name.trim(),
        notes: notes.trim(),
      })
      toast.success("Batch berhasil dibuat.")
      onSuccess(batch)
      // Reset
      setJobId("")
      setName("")
      setNotes("")
    } catch {
      toast.error("Gagal membuat batch.")
    } finally {
      setLoading(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Buat Batch Baru</DialogTitle>
          <DialogDescription>
            Batch digunakan untuk mengelompokkan pelamar yang akan melalui
            proses seleksi bersama untuk satu lowongan kerja.
          </DialogDescription>
        </DialogHeader>

        <div className="flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <Label>Lowongan Kerja</Label>
            <Select value={jobId} onValueChange={setJobId}>
              <SelectTrigger className="cursor-pointer">
                <SelectValue placeholder="Pilih lowongan..." />
              </SelectTrigger>
              <SelectContent>
                {jobs.map((j) => (
                  <SelectItem key={j.id} value={String(j.id)}>
                    {j.title}
                    {j.company_name ? ` — ${j.company_name}` : ""}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="flex flex-col gap-1.5">
            <Label>Nama Batch</Label>
            <Input
              placeholder="contoh: Batch Maret 2026"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </div>

          <div className="flex flex-col gap-1.5">
            <Label>Catatan (opsional)</Label>
            <Textarea
              placeholder="Catatan umum untuk batch ini..."
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={3}
            />
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} className="cursor-pointer">
            Batal
          </Button>
          <Button
            onClick={handleSubmit}
            disabled={!jobId || !name.trim() || loading}
            className="cursor-pointer"
          >
            {loading ? "Menyimpan..." : "Buat Batch"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
