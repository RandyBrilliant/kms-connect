/**
 * BatchAssignDialog — applicant search table with checkbox multi-select.
 *
 * Workflow:
 * 1. Dialog opens for a specific batch.
 * 2. Admin searches (nama, email, NIK, rujukan) and optionally filters biodata.
 * 3. Each row shows is_eligible flag and ineligible_reason.
 * 4. Admin selects rows → "Tambah ke Batch" → POST /api/batches/{id}/assign/.
 */

import { useState, useCallback, useEffect, useMemo } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { IconFilter, IconSearch, IconUserCheck } from "@tabler/icons-react"
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"

import {
  getEligibleApplicants,
  assignToBatch,
  eligibleFilterStateToParams,
} from "@/api/batches"
import type {
  ApplicantSearchRow,
  EligibleApplicantsFilterState,
} from "@/types/lamaran-batch"
import { DEFAULT_ELIGIBLE_APPLICANTS_FILTER } from "@/types/lamaran-batch"
import {
  EDUCATION_LEVEL_LABELS,
  GENDER_LABELS,
  MARITAL_STATUS_LABELS,
  RELIGION_LABELS,
  WRITING_HAND_LABELS,
} from "@/constants/applicant"
import type {
  Religion,
  Gender,
  EducationLevel,
  MaritalStatus,
  WritingHand,
} from "@/types/applicant"
import { cn } from "@/lib/utils"

interface BatchAssignDialogProps {
  batchId: number
  open: boolean
  onOpenChange: (open: boolean) => void
  onSuccess?: () => void
}

const PAGE_SIZE = 20

const ORDERING_OPTIONS: { value: string; label: string }[] = [
  { value: "name", label: "Nama (A → Z)" },
  { value: "-name", label: "Nama (Z → A)" },
  { value: "height_cm", label: "Tinggi badan (rendah → tinggi)" },
  { value: "-height_cm", label: "Tinggi badan (tinggi → rendah)" },
  { value: "weight_kg", label: "Berat badan (ringan → berat)" },
  { value: "-weight_kg", label: "Berat badan (berat → ringan)" },
  { value: "birth_date", label: "Tanggal lahir (paling tua dulu)" },
  { value: "-birth_date", label: "Tanggal lahir (paling muda dulu)" },
  { value: "registration_date", label: "Tanggal daftar (lama → baru)" },
  { value: "-registration_date", label: "Tanggal daftar (baru → lama)" },
  { value: "nik", label: "NIK (naik)" },
  { value: "-nik", label: "NIK (turun)" },
  { value: "religion", label: "Agama (A → Z)" },
  { value: "-religion", label: "Agama (Z → A)" },
]

function TriStateSelect({
  id,
  label,
  value,
  onChange,
  options,
}: {
  id: string
  label: string
  value: "" | "true" | "false"
  onChange: (v: "" | "true" | "false") => void
  options: { value: "" | "true" | "false"; label: string }[]
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <Label htmlFor={id} className="text-xs">
        {label}
      </Label>
      <Select
        value={value === "" ? "__all__" : value}
        onValueChange={(v) =>
          onChange(v === "__all__" ? "" : (v as "true" | "false"))
        }
      >
        <SelectTrigger id={id} size="sm" className="w-full">
          <SelectValue placeholder="Semua" />
        </SelectTrigger>
        <SelectContent>
          {options.map((o) => (
            <SelectItem
              key={o.value === "" ? "__all__" : o.value}
              value={o.value === "" ? "__all__" : o.value}
            >
              {o.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  )
}

export function BatchAssignDialog({
  batchId,
  open,
  onOpenChange,
  onSuccess,
}: BatchAssignDialogProps) {
  const queryClient = useQueryClient()
  const [searchInput, setSearchInput] = useState("")
  const [appliedSearch, setAppliedSearch] = useState("")
  const [filters, setFilters] = useState<EligibleApplicantsFilterState>(() => ({
    ...DEFAULT_ELIGIBLE_APPLICANTS_FILTER,
  }))
  const [appliedFilters, setAppliedFilters] = useState<EligibleApplicantsFilterState>(() => ({
    ...DEFAULT_ELIGIBLE_APPLICANTS_FILTER,
  }))
  const [filtersOpen, setFiltersOpen] = useState(false)
  const [page, setPage] = useState(1)
  const [selected, setSelected] = useState<Set<number>>(new Set())
  const [note, setNote] = useState("")

  useEffect(() => {
    if (!open) return
    setSearchInput("")
    setAppliedSearch("")
    const initial = { ...DEFAULT_ELIGIBLE_APPLICANTS_FILTER }
    setFilters(initial)
    setAppliedFilters(initial)
    setPage(1)
    setSelected(new Set())
    setNote("")
    setFiltersOpen(false)
  }, [open])

  const queryParamsSerialized = useMemo(
    () => JSON.stringify({ s: appliedSearch, f: appliedFilters }),
    [appliedSearch, appliedFilters]
  )

  const { data, isLoading, isError } = useQuery({
    queryKey: ["eligible-applicants", batchId, queryParamsSerialized, page],
    queryFn: () =>
      getEligibleApplicants(batchId, {
        q: appliedSearch || undefined,
        page,
        page_size: PAGE_SIZE,
        ...eligibleFilterStateToParams(appliedFilters),
      }),
    enabled: open,
  })

  const assign = useMutation({
    mutationFn: () =>
      assignToBatch(batchId, {
        applicant_ids: Array.from(selected),
        note: note.trim(),
      }),
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ["eligible-applicants", batchId] })
      queryClient.invalidateQueries({ queryKey: ["batch", batchId] })
      toast.success(
        `${result.assigned_count} pelamar berhasil ditambahkan.` +
          (result.skipped_count > 0 ? ` ${result.skipped_count} dilewati.` : "")
      )
      setSelected(new Set())
      setNote("")
      onSuccess?.()
    },
    onError: () => {
      toast.error("Gagal menambahkan pelamar ke batch.")
    },
  })

  const applySearchAndFilters = useCallback(() => {
    setAppliedSearch(searchInput.trim())
    setAppliedFilters({ ...filters })
    setPage(1)
  }, [searchInput, filters])

  const resetFilters = useCallback(() => {
    const initial = { ...DEFAULT_ELIGIBLE_APPLICANTS_FILTER }
    setFilters(initial)
    setAppliedFilters(initial)
    setPage(1)
  }, [])

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

  const selectedIdsNotOnCurrentPage = useMemo(() => {
    if (selected.size === 0) return 0
    const onPage = new Set(rows.map((r) => r.id))
    let n = 0
    for (const id of selected) {
      if (!onPage.has(id)) n++
    }
    return n
  }, [rows, selected])

  const eligiblePageIds = rows.filter((r) => r.is_eligible).map((r) => r.id)
  const allPageSelected =
    eligiblePageIds.length > 0 && eligiblePageIds.every((id) => selected.has(id))

  const togglePage = () => {
    setSelected((prev) => {
      const next = new Set(prev)
      if (allPageSelected) eligiblePageIds.forEach((id) => next.delete(id))
      else eligiblePageIds.forEach((id) => next.add(id))
      return next
    })
  }

  const tableColCount = 11

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-5xl max-h-[92vh] flex flex-col gap-0 p-0">
        <div className="px-6 pt-6 pb-4 border-b">
          <DialogHeader>
            <DialogTitle>Tambah Pelamar ke Batch</DialogTitle>
            <DialogDescription>
              Cari pelamar (nama, email, NIK, rujukan), lalu saring berdasarkan biodata
              atau wilayah bila perlu. Pilih baris yang memenuhi syarat, lalu tambahkan ke
              batch. Centangan tetap tersimpan saat Anda mengganti halaman atau mencari lagi.
            </DialogDescription>
          </DialogHeader>
        </div>

        <div className="flex flex-col gap-3 px-6 py-4 overflow-y-auto flex-1 min-h-0">
          {/* Search + apply */}
          <div className="flex flex-col gap-2 shrink-0">
            <div className="flex gap-2 flex-wrap">
              <div className="relative flex-1 min-w-[200px]">
                <IconSearch className="text-muted-foreground absolute left-3 top-1/2 size-4 -translate-y-1/2" />
                <Input
                  placeholder="Cari nama, email, NIK, atau rujukan..."
                  value={searchInput}
                  onChange={(e) => setSearchInput(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && applySearchAndFilters()}
                  className="pl-9"
                />
              </div>
              <Button
                type="button"
                onClick={applySearchAndFilters}
                className="cursor-pointer shrink-0"
              >
                Terapkan
              </Button>
              <Button
                type="button"
                variant={filtersOpen ? "secondary" : "outline"}
                className="cursor-pointer shrink-0"
                onClick={() => setFiltersOpen((o) => !o)}
              >
                <IconFilter className="mr-2 size-4" />
                Filter & urutkan
              </Button>
            </div>

            <div
              className={cn(
                "flex flex-col gap-4 rounded-lg border bg-muted/30 p-4",
                !filtersOpen && "hidden"
              )}
            >
              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                <div className="flex flex-col gap-1.5 sm:col-span-2">
                  <Label className="text-xs">Urutkan hasil</Label>
                  <Select
                    value={filters.ordering}
                    onValueChange={(v) =>
                      setFilters((f) => ({ ...f, ordering: v }))
                    }
                  >
                    <SelectTrigger className="w-full">
                      <SelectValue placeholder="Urutan" />
                    </SelectTrigger>
                    <SelectContent>
                      {ORDERING_OPTIONS.map((o) => (
                        <SelectItem key={o.value} value={o.value}>
                          {o.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label className="text-xs">TB min (cm)</Label>
                  <Input
                    inputMode="numeric"
                    placeholder="—"
                    value={filters.height_cm_min}
                    onChange={(e) =>
                      setFilters((f) => ({ ...f, height_cm_min: e.target.value }))
                    }
                  />
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label className="text-xs">TB maks (cm)</Label>
                  <Input
                    inputMode="numeric"
                    placeholder="—"
                    value={filters.height_cm_max}
                    onChange={(e) =>
                      setFilters((f) => ({ ...f, height_cm_max: e.target.value }))
                    }
                  />
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label className="text-xs">BB min (kg)</Label>
                  <Input
                    inputMode="numeric"
                    placeholder="—"
                    value={filters.weight_kg_min}
                    onChange={(e) =>
                      setFilters((f) => ({ ...f, weight_kg_min: e.target.value }))
                    }
                  />
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label className="text-xs">BB maks (kg)</Label>
                  <Input
                    inputMode="numeric"
                    placeholder="—"
                    value={filters.weight_kg_max}
                    onChange={(e) =>
                      setFilters((f) => ({ ...f, weight_kg_max: e.target.value }))
                    }
                  />
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label className="text-xs">Lahir dari</Label>
                  <Input
                    type="date"
                    value={filters.birth_date_from}
                    onChange={(e) =>
                      setFilters((f) => ({ ...f, birth_date_from: e.target.value }))
                    }
                  />
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label className="text-xs">Lahir sampai</Label>
                  <Input
                    type="date"
                    value={filters.birth_date_to}
                    onChange={(e) =>
                      setFilters((f) => ({ ...f, birth_date_to: e.target.value }))
                    }
                  />
                </div>
              </div>

              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                <div className="flex flex-col gap-1.5">
                  <Label className="text-xs">Jenis kelamin</Label>
                  <Select
                    value={filters.gender || "__all__"}
                    onValueChange={(v) =>
                      setFilters((f) => ({
                        ...f,
                        gender: v === "__all__" ? "" : v,
                      }))
                    }
                  >
                    <SelectTrigger className="w-full">
                      <SelectValue placeholder="Semua" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="__all__">Semua</SelectItem>
                      {(Object.entries(GENDER_LABELS) as [Gender, string][]).map(
                        ([k, label]) => (
                          <SelectItem key={k} value={k}>
                            {label}
                          </SelectItem>
                        )
                      )}
                    </SelectContent>
                  </Select>
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label className="text-xs">Agama</Label>
                  <Select
                    value={filters.religion || "__all__"}
                    onValueChange={(v) =>
                      setFilters((f) => ({
                        ...f,
                        religion: v === "__all__" ? "" : v,
                      }))
                    }
                  >
                    <SelectTrigger className="w-full">
                      <SelectValue placeholder="Semua" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="__all__">Semua</SelectItem>
                      {(Object.entries(RELIGION_LABELS) as [Religion, string][]).map(
                        ([k, label]) => (
                          <SelectItem key={k} value={k}>
                            {label}
                          </SelectItem>
                        )
                      )}
                    </SelectContent>
                  </Select>
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label className="text-xs">Pendidikan</Label>
                  <Select
                    value={filters.education_level || "__all__"}
                    onValueChange={(v) =>
                      setFilters((f) => ({
                        ...f,
                        education_level: v === "__all__" ? "" : v,
                      }))
                    }
                  >
                    <SelectTrigger className="w-full">
                      <SelectValue placeholder="Semua" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="__all__">Semua</SelectItem>
                      {(
                        Object.entries(EDUCATION_LEVEL_LABELS) as [
                          EducationLevel,
                          string,
                        ][]
                      ).map(([k, label]) => (
                        <SelectItem key={k} value={k}>
                          {label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label className="text-xs">Status perkawinan</Label>
                  <Select
                    value={filters.marital_status || "__all__"}
                    onValueChange={(v) =>
                      setFilters((f) => ({
                        ...f,
                        marital_status: v === "__all__" ? "" : v,
                      }))
                    }
                  >
                    <SelectTrigger className="w-full">
                      <SelectValue placeholder="Semua" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="__all__">Semua</SelectItem>
                      {(
                        Object.entries(MARITAL_STATUS_LABELS) as [
                          MaritalStatus,
                          string,
                        ][]
                      ).map(([k, label]) => (
                        <SelectItem key={k} value={k}>
                          {label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label className="text-xs">Menulis dengan tangan</Label>
                  <Select
                    value={filters.writing_hand || "__all__"}
                    onValueChange={(v) =>
                      setFilters((f) => ({
                        ...f,
                        writing_hand: v === "__all__" ? "" : v,
                      }))
                    }
                  >
                    <SelectTrigger className="w-full">
                      <SelectValue placeholder="Semua" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="__all__">Semua</SelectItem>
                      {(
                        Object.entries(WRITING_HAND_LABELS) as [WritingHand, string][]
                      ).map(([k, label]) => (
                        <SelectItem key={k} value={k}>
                          {label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <TriStateSelect
                  id="wears-glasses"
                  label="Kacamata"
                  value={filters.wears_glasses}
                  onChange={(wears_glasses) => setFilters((f) => ({ ...f, wears_glasses }))}
                  options={[
                    { value: "", label: "Semua" },
                    { value: "true", label: "Ya" },
                    { value: "false", label: "Tidak" },
                  ]}
                />
                <TriStateSelect
                  id="has-passport"
                  label="Paspor"
                  value={filters.has_passport}
                  onChange={(has_passport) => setFilters((f) => ({ ...f, has_passport }))}
                  options={[
                    { value: "", label: "Semua" },
                    { value: "true", label: "Ada" },
                    { value: "false", label: "Belum ada" },
                  ]}
                />
              </div>

              <div className="flex flex-wrap gap-2 justify-end">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  className="cursor-pointer"
                  onClick={resetFilters}
                >
                  Reset filter
                </Button>
                <Button
                  type="button"
                  size="sm"
                  className="cursor-pointer"
                  onClick={applySearchAndFilters}
                >
                  Terapkan filter &amp; muat ulang
                </Button>
              </div>
            </div>
          </div>

          {/* Table */}
          <div className="overflow-auto rounded-lg border flex-1 min-h-[200px]">
            {isLoading ? (
              <div className="flex items-center justify-center py-12">
                <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
              </div>
            ) : isError ? (
              <div className="flex items-center justify-center py-12 px-4 text-center text-sm text-destructive">
                Gagal memuat daftar pelamar. Tutup dialog dan coba lagi, atau cek filter /
                koneksi Anda.
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-10 sticky left-0 bg-background z-10 shadow-[2px_0_4px_-2px_rgba(0,0,0,0.1)]">
                      <Checkbox
                        checked={allPageSelected}
                        onCheckedChange={togglePage}
                        disabled={eligiblePageIds.length === 0}
                        aria-label="Pilih semua pelamar memenuhi syarat di halaman ini"
                      />
                    </TableHead>
                    <TableHead>Nama</TableHead>
                    <TableHead>NIK</TableHead>
                    <TableHead>Email</TableHead>
                    <TableHead className="text-right whitespace-nowrap">TB (cm)</TableHead>
                    <TableHead className="text-right whitespace-nowrap">BB (kg)</TableHead>
                    <TableHead className="whitespace-nowrap">JK</TableHead>
                    <TableHead className="whitespace-nowrap">Agama</TableHead>
                    <TableHead className="min-w-[140px]">Domisili</TableHead>
                    <TableHead>Rujukan</TableHead>
                    <TableHead className="whitespace-nowrap">Status</TableHead>
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
                        <TableCell
                          className="sticky left-0 bg-background z-10 shadow-[2px_0_4px_-2px_rgba(0,0,0,0.1)]"
                          onClick={(e) => e.stopPropagation()}
                        >
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
                            {row.phone ? (
                              <span className="text-xs text-muted-foreground">{row.phone}</span>
                            ) : null}
                          </div>
                        </TableCell>
                        <TableCell className="text-sm whitespace-nowrap">{row.nik || "—"}</TableCell>
                        <TableCell className="text-sm max-w-[160px] truncate" title={row.email}>
                          {row.email}
                        </TableCell>
                        <TableCell className="text-sm text-right tabular-nums">
                          {row.height_cm != null ? row.height_cm : "—"}
                        </TableCell>
                        <TableCell className="text-sm text-right tabular-nums">
                          {row.weight_kg != null ? row.weight_kg : "—"}
                        </TableCell>
                        <TableCell className="text-sm whitespace-nowrap">
                          {row.gender
                            ? GENDER_LABELS[row.gender as Gender] ?? row.gender
                            : "—"}
                        </TableCell>
                        <TableCell className="text-sm whitespace-nowrap">
                          {row.religion
                            ? RELIGION_LABELS[row.religion as Religion] ?? row.religion
                            : "—"}
                        </TableCell>
                        <TableCell className="text-sm text-muted-foreground max-w-[180px]">
                          <span className="line-clamp-2">{row.domicile || "—"}</span>
                        </TableCell>
                        <TableCell className="text-sm">
                          {row.referrer_display_name || row.referrer_code ? (
                            <div className="flex flex-col gap-0.5">
                              {row.referrer_display_name ? (
                                <span>{row.referrer_display_name}</span>
                              ) : null}
                              {row.referrer_code ? (
                                <span className="text-xs text-muted-foreground">
                                  {row.referrer_code}
                                </span>
                              ) : null}
                            </div>
                          ) : (
                            <span className="text-muted-foreground">—</span>
                          )}
                        </TableCell>
                        <TableCell className="whitespace-nowrap">
                          {row.is_eligible ? (
                            <Badge variant="default" className="text-xs">
                              Memenuhi Syarat
                            </Badge>
                          ) : (
                            <Badge
                              variant="destructive"
                              className="text-xs max-w-[140px] truncate block"
                              title={row.ineligible_reason ?? ""}
                            >
                              Tidak Memenuhi Syarat
                            </Badge>
                          )}
                        </TableCell>
                      </TableRow>
                    ))
                  ) : (
                    <TableRow>
                      <TableCell
                        colSpan={tableColCount}
                        className="h-20 text-center text-muted-foreground"
                      >
                        Tidak ada pelamar yang cocok. Ubah kata kunci atau longgarkan filter,
                        lalu klik Terapkan.
                      </TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>
            )}
          </div>

          {/* Pagination */}
          {(pageCount > 1 || (data?.count ?? 0) > 0) && (
            <div className="flex items-center justify-between shrink-0 text-sm pt-1">
              <span className="text-muted-foreground">{data?.count ?? 0} hasil</span>
              {pageCount > 1 ? (
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
              ) : null}
            </div>
          )}

          {selected.size > 0 && (
            <div className="flex flex-col gap-1.5 shrink-0 border-t pt-4">
              {selectedIdsNotOnCurrentPage > 0 && (
                <p className="text-xs text-muted-foreground">
                  {selectedIdsNotOnCurrentPage} pelamar terpilih tidak tampil di halaman ini —
                  centangan tetap aktif.
                </p>
              )}
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
        </div>

        <DialogFooter className="px-6 py-4 border-t shrink-0 gap-2 sm:gap-0">
          <Button
            variant="outline"
            onClick={() => onOpenChange(false)}
            className="cursor-pointer md:mr-2"
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
