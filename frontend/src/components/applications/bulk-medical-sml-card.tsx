/**
 * Bulk edit medical / hasil / SML dates for selected DITERIMA applicants (MEDICAL sub-step).
 */

import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { DatePicker } from "@/components/ui/date-picker"
import { Label } from "@/components/ui/label"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"

export interface BulkMedicalSmlCardProps {
  bulkTglMedical: Date | undefined
  onBulkTglMedicalChange: (d: Date | undefined) => void
  bulkHasilMedical: string
  onBulkHasilMedicalChange: (v: string) => void
  bulkTglBayarSml: Date | undefined
  onBulkTglBayarSmlChange: (d: Date | undefined) => void
  selectedCount: number
  canApply: boolean
  isPending: boolean
  onApply: () => void
}

export function BulkMedicalSmlCard({
  bulkTglMedical,
  onBulkTglMedicalChange,
  bulkHasilMedical,
  onBulkHasilMedicalChange,
  bulkTglBayarSml,
  onBulkTglBayarSmlChange,
  selectedCount,
  canApply,
  isPending,
  onApply,
}: BulkMedicalSmlCardProps) {
  return (
    <Card>
      <CardHeader className="pb-3">
        <CardTitle className="text-base">Pengisian data medical &amp; bayar SML</CardTitle>
        <p className="text-sm text-muted-foreground">
          Sama seperti pengumuman: centang pelamar di tabel, isi field yang ingin diterapkan
          bersamaan untuk semua terpilih, lalu klik Terapkan. Field yang tidak diisi di sini tidak
          mengubah nilai yang sudah tersimpan.
        </p>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <div className="space-y-1.5">
            <Label htmlFor="bulk-tgl-medical-cohort">Tgl. medical</Label>
            <DatePicker
              date={bulkTglMedical}
              onDateChange={(d) => onBulkTglMedicalChange(d ?? undefined)}
              placeholder="Opsional"
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="bulk-hasil-medical-cohort">Hasil medical</Label>
            <Select
              value={bulkHasilMedical || "__skip__"}
              onValueChange={(v) => onBulkHasilMedicalChange(v === "__skip__" ? "" : v)}
            >
              <SelectTrigger id="bulk-hasil-medical-cohort" className="w-full">
                <SelectValue placeholder="Opsional" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="__skip__">— tidak ubah —</SelectItem>
                <SelectItem value="FIT">FIT</SelectItem>
                <SelectItem value="UNFIT">UNFIT</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="bulk-tgl-bayar-sml-cohort">Tgl. bayar SML</Label>
            <DatePicker
              date={bulkTglBayarSml}
              onDateChange={(d) => onBulkTglBayarSmlChange(d ?? undefined)}
              placeholder="Opsional"
            />
          </div>
        </div>
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="text-xs text-muted-foreground">
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
