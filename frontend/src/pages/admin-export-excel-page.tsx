/**
 * Admin Export Excel — filter pelamar by scheduled activity dates and export full biodata
 * plus lamaran / tahapan context.
 */

import { useState } from "react"
import { format } from "date-fns"
import { id } from "date-fns/locale"
import { IconDownload, IconFileSpreadsheet } from "@tabler/icons-react"
import type { DateRange } from "react-day-picker"

import {
  exportActivityApplicationsExcel,
  type ActivityExportType,
} from "@/api/applications"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Checkbox } from "@/components/ui/checkbox"
import { DateRangePicker } from "@/components/ui/date-range-picker"
import { Label } from "@/components/ui/label"
import { useAdminDashboard } from "@/contexts/admin-dashboard-context"
import { usePageTitle } from "@/hooks/use-page-title"
import {
  formatDateForAPI,
  getCurrentMonthRange,
  getLast30DaysRange,
  parseAPIDate,
} from "@/lib/date-utils"
import { toast } from "@/lib/toast"
import { cn } from "@/lib/utils"

const ACTIVITY_OPTIONS: { value: ActivityExportType; label: string; description: string }[] =
  [
    {
      value: "PRA_SELEKSI",
      label: "Pra-Seleksi",
      description: "Jadwal pra-seleksi batch (tanggal pra-seleksi)",
    },
    {
      value: "INTERVIEW",
      label: "Interview",
      description: "Jadwal sesi interview (tanggal interview)",
    },
    {
      value: "MEDICAL",
      label: "Medical",
      description: "Tanggal medical pada profil pelamar",
    },
    {
      value: "PSIKOTES",
      label: "Psikotes",
      description: "Tanggal FWCMS & psikotes pada profil pelamar",
    },
  ]

export function AdminExportExcelPage() {
  usePageTitle("Export Excel")
  const { basePath } = useAdminDashboard()

  const [dateRange, setDateRange] = useState<DateRange | undefined>(() => {
    const { start_date, end_date } = getCurrentMonthRange()
    return { from: parseAPIDate(start_date), to: parseAPIDate(end_date) }
  })
  const [selectedActivities, setSelectedActivities] = useState<Set<ActivityExportType>>(
    () => new Set(ACTIVITY_OPTIONS.map((o) => o.value))
  )
  const [isExporting, setIsExporting] = useState(false)

  const toggleActivity = (value: ActivityExportType, checked: boolean) => {
    setSelectedActivities((prev) => {
      const next = new Set(prev)
      if (checked) next.add(value)
      else next.delete(value)
      return next
    })
  }

  const applyPreset = (preset: "month" | "last30") => {
    const range = preset === "month" ? getCurrentMonthRange() : getLast30DaysRange()
    setDateRange({
      from: parseAPIDate(range.start_date),
      to: parseAPIDate(range.end_date),
    })
  }

  const handleExport = async () => {
    if (!dateRange?.from || !dateRange?.to) {
      toast.error("Pilih rentang tanggal", "Tentukan tanggal mulai dan akhir.")
      return
    }
    if (selectedActivities.size === 0) {
      toast.error("Pilih aktivitas", "Centang minimal satu jenis aktivitas.")
      return
    }

    setIsExporting(true)
    try {
      const date_from = formatDateForAPI(dateRange.from)
      const date_to = formatDateForAPI(dateRange.to)
      await exportActivityApplicationsExcel({
        date_from,
        date_to,
        activities: Array.from(selectedActivities),
      })
      toast.success("File Excel berhasil diunduh.")
    } catch (err: unknown) {
      const detail = (err as { response?: { data?: { detail?: string } } })?.response?.data
        ?.detail
      toast.error("Gagal mengunduh Excel", detail ?? "Coba lagi nanti.")
    } finally {
      setIsExporting(false)
    }
  }

  const rangeLabel =
    dateRange?.from && dateRange?.to
      ? `${format(dateRange.from, "dd MMM yyyy", { locale: id })} – ${format(dateRange.to, "dd MMM yyyy", { locale: id })}`
      : "Belum dipilih"

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: basePath || "/" },
          { label: "Export Excel" },
        ]}
      />

      <div className="flex flex-col gap-1">
        <h1 className="text-2xl font-semibold tracking-tight">Export Excel</h1>
        <p className="text-muted-foreground text-sm max-w-3xl">
          Unduh data lengkap pelamar beserta lowongan, grup tahapan, dan tahapan lamaran
          mereka. Filter berdasarkan rentang tanggal jadwal aktivitas yang dipilih.
        </p>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Rentang Tanggal</CardTitle>
            <CardDescription>
              Pelamar dimasukkan jika jadwal aktivitas terpilih jatuh dalam rentang ini.
            </CardDescription>
          </CardHeader>
          <CardContent className="flex flex-col gap-4">
            <DateRangePicker
              dateRange={dateRange}
              onDateRangeChange={setDateRange}
              className="max-w-md"
            />
            <div className="flex flex-wrap gap-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                className="cursor-pointer"
                onClick={() => applyPreset("month")}
              >
                Bulan ini
              </Button>
              <Button
                type="button"
                variant="outline"
                size="sm"
                className="cursor-pointer"
                onClick={() => applyPreset("last30")}
              >
                30 hari terakhir
              </Button>
            </div>
            <p className="text-muted-foreground text-xs">Rentang aktif: {rangeLabel}</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Jenis Aktivitas</CardTitle>
            <CardDescription>
              Pilih satu atau lebih. Hasil export adalah gabungan (OR) dari semua yang
              dipilih.
            </CardDescription>
          </CardHeader>
          <CardContent className="flex flex-col gap-3">
            {ACTIVITY_OPTIONS.map((option) => {
              const checked = selectedActivities.has(option.value)
              return (
                <label
                  key={option.value}
                  className={cn(
                    "flex cursor-pointer items-start gap-3 rounded-lg border p-3 transition-colors",
                    checked ? "border-primary/40 bg-primary/[0.04]" : "hover:bg-muted/40"
                  )}
                >
                  <Checkbox
                    checked={checked}
                    onCheckedChange={(v) => toggleActivity(option.value, v === true)}
                    aria-label={option.label}
                  />
                  <span className="flex flex-col gap-0.5">
                    <span className="text-sm font-medium">{option.label}</span>
                    <span className="text-muted-foreground text-xs">{option.description}</span>
                  </span>
                </label>
              )
            })}
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-base">
            <IconFileSpreadsheet className="size-4" />
            Kolom Export
          </CardTitle>
          <CardDescription>
            Setiap baris = satu lamaran yang cocok dengan filter. Kolom awal berisi konteks
            lamaran; diikuti seluruh biodata pelamar (sama seperti export pelamar standar).
          </CardDescription>
        </CardHeader>
        <CardContent>
          <ul className="text-muted-foreground grid gap-1 text-sm sm:grid-cols-2">
            <li>Aktivitas yang cocok dengan filter</li>
            <li>Lowongan &amp; perusahaan</li>
            <li>Status &amp; grup tahapan lamaran</li>
            <li>Nama tahapan pra-seleksi &amp; sesi interview</li>
            <li>Sub-tahapan diterima (jika ada)</li>
            <li>Tanggal pra-seleksi, interview, medical, psikotes</li>
            <li>+ semua kolom biodata &amp; dokumen pelamar</li>
          </ul>
        </CardContent>
      </Card>

      <div className="flex flex-wrap items-center gap-3">
        <Button
          type="button"
          className="cursor-pointer"
          disabled={isExporting}
          onClick={() => void handleExport()}
        >
          <IconDownload className="mr-2 size-4" />
          {isExporting ? "Mengunduh..." : "Unduh Excel"}
        </Button>
        <p className="text-muted-foreground text-xs">
          {selectedActivities.size} aktivitas dipilih
          {dateRange?.from && dateRange?.to ? ` · ${rangeLabel}` : ""}
        </p>
      </div>
    </div>
  )
}
