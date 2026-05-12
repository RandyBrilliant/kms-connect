/**
 * Bulk edit FWCMS / psikotes schedule and payment dates for selected DITERIMA applicants.
 */

import { IconBrain } from "@tabler/icons-react"

import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { DatePicker } from "@/components/ui/date-picker"
import { Label } from "@/components/ui/label"

export interface BulkFwcmsPsikotesCardProps {
  bulkTglFwcmPsikotes: Date | undefined
  onBulkTglFwcmPsikotesChange: (d: Date | undefined) => void
  bulkTglBayarPsikotes: Date | undefined
  onBulkTglBayarPsikotesChange: (d: Date | undefined) => void
  selectedCount: number
  canApply: boolean
  isPending: boolean
  onApply: () => void
}

export function BulkFwcmsPsikotesCard({
  bulkTglFwcmPsikotes,
  onBulkTglFwcmPsikotesChange,
  bulkTglBayarPsikotes,
  onBulkTglBayarPsikotesChange,
  selectedCount,
  canApply,
  isPending,
  onApply,
}: BulkFwcmsPsikotesCardProps) {
  return (
    <Card>
      <CardHeader className="pb-3">
        <div className="flex items-start gap-3">
          <div className="bg-muted flex size-9 shrink-0 items-center justify-center rounded-md border">
            <IconBrain className="text-foreground size-5" aria-hidden />
          </div>
          <div className="min-w-0 space-y-1">
            <CardTitle className="text-base">FWCMS &amp; Psikotes</CardTitle>
            <p className="text-muted-foreground text-sm">
              Jadwal FWCMS/psikotes dan tanggal pembayaran psikotes. Centang pelamar di tabel, isi
              tanggal yang ingin diterapkan bersamaan, lalu klik Terapkan. Field yang tidak diisi
              tidak mengubah nilai yang sudah tersimpan.
            </p>
          </div>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-1.5">
            <Label>Tgl. FWCMS &amp; Psikotes</Label>
            <DatePicker
              date={bulkTglFwcmPsikotes}
              onDateChange={(d) => onBulkTglFwcmPsikotesChange(d ?? undefined)}
              placeholder="Opsional"
            />
          </div>
          <div className="space-y-1.5">
            <Label>Tgl. Bayar Psikotes</Label>
            <DatePicker
              date={bulkTglBayarPsikotes}
              onDateChange={(d) => onBulkTglBayarPsikotesChange(d ?? undefined)}
              placeholder="Opsional"
            />
          </div>
        </div>
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="text-muted-foreground text-xs">
            {selectedCount} pelamar tercentang di tabel
          </span>
          <Button
            type="button"
            size="sm"
            className="cursor-pointer"
            disabled={!canApply || isPending}
            onClick={() => onApply()}
          >
            {isPending ? "Memproses..." : "Terapkan ke terpilih"}
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
