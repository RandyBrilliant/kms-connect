/**
 * Select another `LamaranBatch` (pra-seleksi tahapan) for the same job.
 * Used when re-batching PRA_SELEKSI applicants without changing status.
 */

import { useQuery } from "@tanstack/react-query"
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Label } from "@/components/ui/label"
import { getBatches } from "@/api/batches"

export interface BatchSelectFieldProps {
  jobId: number
  value: number | null
  onChange: (batchId: number | null) => void
  /** Hide this batch id from the list (usually the current batch). */
  excludeBatchId?: number
  label?: string
  helperText?: string
  disabled?: boolean
  required?: boolean
  placeholder?: string
}

export function BatchSelectField({
  jobId,
  value,
  onChange,
  excludeBatchId,
  label = "Tahapan tujuan",
  helperText,
  disabled = false,
  required = false,
  placeholder = "Pilih batch...",
}: BatchSelectFieldProps) {
  const { data, isLoading } = useQuery({
    queryKey: ["batches", { job: jobId, select: "field" }],
    queryFn: () =>
      getBatches({
        job: jobId,
        page_size: 200,
        ordering: "tahap_order,created_at",
      }),
    enabled: Number.isFinite(jobId) && jobId > 0,
  })

  const batches = (data?.results ?? []).filter(
    (b) => b.id !== excludeBatchId
  )

  return (
    <div className="flex flex-col gap-1.5">
      <Label>
        {label} {required && <span className="text-destructive">*</span>}
      </Label>
      <Select
        value={value != null ? String(value) : ""}
        onValueChange={(v) => onChange(v ? Number(v) : null)}
        disabled={disabled || isLoading}
      >
        <SelectTrigger className="cursor-pointer">
          <SelectValue placeholder={isLoading ? "Memuat..." : placeholder} />
        </SelectTrigger>
        <SelectContent>
          {batches.length ? (
            <SelectGroup>
              <SelectLabel>Tahapan pra-seleksi</SelectLabel>
              {batches.map((b) => (
                <SelectItem key={b.id} value={String(b.id)}>
                  Tahap {b.tahap_order}: {b.name}
                  {b.tahap_label ? ` · ${b.tahap_label}` : ""}
                </SelectItem>
              ))}
            </SelectGroup>
          ) : !isLoading ? (
            <div className="px-3 py-4 text-center text-xs text-muted-foreground">
              Tidak ada tahapan lain untuk lowongan ini.
            </div>
          ) : null}
        </SelectContent>
      </Select>
      {helperText ? (
        <span className="text-muted-foreground text-xs">{helperText}</span>
      ) : null}
    </div>
  )
}
