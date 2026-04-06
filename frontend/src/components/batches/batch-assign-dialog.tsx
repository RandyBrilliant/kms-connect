/**
 * BatchAssignDialog — applicant search table with checkbox multi-select.
 *
 * Workflow:
 * 1. Dialog opens for a specific batch.
 * 2. Admin types a search term (name, email, or NIK) → paginated results load.
 * 3. Each row shows is_eligible flag and ineligible_reason.
 * 4. Admin selects one or more rows with checkboxes.
 * 5. Admin clicks "Tambah ke Batch" → calls POST /api/batches/{id}/assign/.
 * 6. Response shows how many were added and how many were skipped.
 */

import { useState, useCallback } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { IconSearch, IconUserCheck } from "@tabler/icons-react"
import { toast } from "@/lib/toast"

import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
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
import { Badge } from "@/components/ui/badge"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"

import { getEligibleApplicants, assignToBatch } from "@/api/batches"
import type { ApplicantSearchRow } from "@/types/lamaran-batch"

interface BatchAssignDialogProps {
  batchId: number
  open: boolean
  onOpenChange: (open: boolean) => void
  onSuccess?: () => void
}

export function BatchAssignDialog({
  batchId,
  open,
  onOpenChange,
  onSuccess,
}: BatchAssignDialogProps) {
  const queryClient = useQueryClient()
  const [searchInput, setSearchInput] = useState("")
  const [searchQuery, setSearchQuery] = useState("")
  const [page, setPage] = useState(1)
  const [selected, setSelected] = useState<Set<number>>(new Set())
  const [note, setNote] = useState("")

  const PAGE_SIZE = 20

  const { data, isLoading, isError } = useQuery({
    queryKey: ["eligible-applicants", batchId, searchQuery, page],
    queryFn: () =>
      getEligibleApplicants(batchId, { q: searchQuery, page, page_size: PAGE_SIZE }),
    enabled: open,
  })

  const assign = useMutation({
    mutationFn: () =>
      assignToBatch(batchId, {
        applicant_ids: Array.from(selected),
        note: note.trim(),
      }),
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ["batch", batchId] })
      queryClient.invalidateQueries({ queryKey: ["eligible-applicants", batchId] })
      toast.success(
        `${result.assigned_count} pelamar berhasil ditambahkan.` +
          (result.skipped_count > 0
            ? ` ${result.skipped_count} dilewati.`
            : "")
      )
      setSelected(new Set())
      setNote("")
      onSuccess?.()
    },
    onError: () => {
      toast.error("Gagal menambahkan pelamar ke batch.")
    },
  })

  const handleSearch = useCallback(() => {
    setSearchQuery(searchInput.trim())
    setPage(1)
    setSelected(new Set())
  }, [searchInput])

  const toggleRow = (id: number) => {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const rows = data?.results ?? []
  const pageCount = data ? Math.ceil(data.count / PAGE_SIZE) : 0

  // Select all / deselect all on current page
  const pageIds = rows.map((r) => r.id)
  const allPageSelected = pageIds.length > 0 && pageIds.every((id) => selected.has(id))

  const togglePage = () => {
    setSelected((prev) => {
      const next = new Set(prev)
      if (allPageSelected) pageIds.forEach((id) => next.delete(id))
      else pageIds.forEach((id) => next.add(id))
      return next
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-3xl max-h-[90vh] flex flex-col">
        <DialogHeader>
          <DialogTitle>Tambah Pelamar ke Batch</DialogTitle>
          <DialogDescription>
            Cari pelamar berdasarkan nama, email, atau NIK. Pilih satu atau
            beberapa pelamar dengan centang, lalu klik "Tambah ke Batch".
            Hanya pelamar yang memenuhi syarat yang akan berhasil ditambahkan.
          </DialogDescription>
        </DialogHeader>

        {/* Search bar */}
        <div className="flex gap-2 shrink-0">
          <div className="relative flex-1">
            <IconSearch className="text-muted-foreground absolute left-3 top-1/2 size-4 -translate-y-1/2" />
            <Input
              placeholder="Cari nama, email, atau NIK..."
              value={searchInput}
              onChange={(e) => setSearchInput(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && handleSearch()}
              className="pl-9"
            />
          </div>
          <Button onClick={handleSearch} variant="secondary" className="cursor-pointer">
            Cari
          </Button>
        </div>

        {/* Table */}
        <div className="overflow-auto rounded-lg border flex-1 min-h-0">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : isError ? (
            <div className="flex items-center justify-center py-12 px-4 text-center text-sm text-destructive">
              Gagal memuat daftar pelamar. Tutup dialog dan coba lagi, atau cek koneksi Anda.
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-10">
                    <Checkbox
                      checked={allPageSelected}
                      onCheckedChange={togglePage}
                      aria-label="Pilih semua di halaman ini"
                    />
                  </TableHead>
                  <TableHead>Nama</TableHead>
                  <TableHead>NIK</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>Domisili</TableHead>
                  <TableHead>Status</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.length ? (
                  rows.map((row: ApplicantSearchRow) => (
                    <TableRow
                      key={row.id}
                      className={
                        row.is_eligible
                          ? "cursor-pointer hover:bg-muted/50"
                          : "opacity-50"
                      }
                      onClick={() => row.is_eligible && toggleRow(row.id)}
                    >
                      <TableCell onClick={(e) => e.stopPropagation()}>
                        <Checkbox
                          checked={selected.has(row.id)}
                          onCheckedChange={() => row.is_eligible && toggleRow(row.id)}
                          disabled={!row.is_eligible}
                          aria-label={`Pilih ${row.full_name}`}
                        />
                      </TableCell>
                      <TableCell>
                        <div className="flex flex-col">
                          <span className="font-medium">{row.full_name}</span>
                          {row.phone && (
                            <span className="text-xs text-muted-foreground">{row.phone}</span>
                          )}
                        </div>
                      </TableCell>
                      <TableCell className="text-sm">{row.nik || "-"}</TableCell>
                      <TableCell className="text-sm">{row.email}</TableCell>
                      <TableCell className="text-sm text-muted-foreground">{row.domicile || "-"}</TableCell>
                      <TableCell>
                        {row.is_eligible ? (
                          <Badge variant="default" className="text-xs">Memenuhi Syarat</Badge>
                        ) : (
                          <Badge variant="destructive" className="text-xs" title={row.ineligible_reason ?? ""}>
                            Tidak Memenuhi Syarat
                          </Badge>
                        )}
                      </TableCell>
                    </TableRow>
                  ))
                ) : (
                  <TableRow>
                    <TableCell colSpan={6} className="h-20 text-center text-muted-foreground">
                      {searchQuery
                        ? "Tidak ada pelamar yang cocok dengan pencarian."
                        : "Ketik nama, email, atau NIK untuk mencari pelamar."}
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          )}
        </div>

        {/* Pagination */}
        {pageCount > 1 && (
          <div className="flex items-center justify-between shrink-0 text-sm">
            <span className="text-muted-foreground">{data?.count ?? 0} hasil</span>
            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                className="cursor-pointer"
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page <= 1}
              >
                Sebelumnya
              </Button>
              <span>
                {page} / {pageCount}
              </span>
              <Button
                variant="outline"
                size="sm"
                className="cursor-pointer"
                onClick={() => setPage((p) => Math.min(pageCount, p + 1))}
                disabled={page >= pageCount}
              >
                Selanjutnya
              </Button>
            </div>
          </div>
        )}

        {/* Note field + selection count */}
        {selected.size > 0 && (
          <div className="flex flex-col gap-1.5 shrink-0">
            <Label>
              Catatan penugasan
              <span className="ml-1 text-muted-foreground text-xs">(opsional)</span>
            </Label>
            <Textarea
              placeholder="Catatan yang akan dicatat di riwayat status semua pelamar terpilih..."
              value={note}
              onChange={(e) => setNote(e.target.value)}
              rows={2}
            />
          </div>
        )}

        <DialogFooter className="shrink-0">
          <Button
            variant="outline"
            onClick={() => onOpenChange(false)}
            className="cursor-pointer"
          >
            Batal
          </Button>
          <Button
            onClick={() => assign.mutate()}
            disabled={selected.size === 0 || assign.isPending}
            className="cursor-pointer"
          >
            <IconUserCheck className="mr-2 size-4" />
            {assign.isPending
              ? "Menambahkan..."
              : `Tambah ${selected.size} Pelamar ke Batch`}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
