/**
 * Admin Laporan (Reports) Page
 * Displays applicant statistics with date range filtering
 */

import { useState } from "react"
import { format } from "date-fns"
import { id } from "date-fns/locale"
import {
  IconCalendar,
  IconDownload,
  IconUsers,
  IconUserCheck,
  IconUserX,
  IconFileCheck,
  IconChartBar,
  IconMapPin,
  IconTrendingUp,
  IconRefresh,
} from "@tabler/icons-react"

import { useApplicantReportQuery } from "@/hooks/use-reports-query"
import {
  getCurrentMonthRange,
  getLastMonthRange,
  getLast30DaysRange,
  getCurrentYearRange,
  formatDateForAPI,
  parseAPIDate,
} from "@/lib/date-utils"
import { cn } from "@/lib/utils"

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Skeleton } from "@/components/ui/skeleton"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover"
import { Calendar } from "@/components/ui/calendar"
import type { DateRange } from "react-day-picker"

/**
 * Stat card component for summary metrics
 */
interface StatCardProps {
  title: string
  value: number | string
  icon: React.ReactNode
  description?: string
  trend?: number
  className?: string
}

function StatCard({ title, value, icon, description, trend, className }: StatCardProps) {
  return (
    <Card className={className}>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium">{title}</CardTitle>
        <div className="text-muted-foreground">{icon}</div>
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">{value}</div>
        {description && (
          <p className="text-muted-foreground text-xs">{description}</p>
        )}
        {trend !== undefined && (
          <div className={cn(
            "mt-1 flex items-center gap-1 text-xs",
            trend >= 0 ? "text-green-600" : "text-red-600"
          )}>
            <IconTrendingUp className={cn(
              "size-3",
              trend < 0 && "rotate-180"
            )} />
            <span>{Math.abs(trend).toFixed(1)}%</span>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

/**
 * Quick filter presets
 */
const FILTER_PRESETS = [
  { label: "Bulan Ini", value: "current_month", getRange: getCurrentMonthRange },
  { label: "Bulan Lalu", value: "last_month", getRange: getLastMonthRange },
  { label: "30 Hari Terakhir", value: "last_30_days", getRange: getLast30DaysRange },
  { label: "Tahun Ini", value: "current_year", getRange: getCurrentYearRange },
  { label: "Custom", value: "custom", getRange: () => getCurrentMonthRange() },
]

/**
 * Status label mapping (Indonesian)
 */
const STATUS_LABELS: Record<string, string> = {
  DRAFT: "Draf",
  SUBMITTED: "Dikirim",
  ACCEPTED: "Diterima",
  REJECTED: "Ditolak",
}

/**
 * Gender label mapping (Indonesian)
 */
const GENDER_LABELS: Record<string, string> = {
  M: "Laki-laki",
  F: "Perempuan",
  O: "Lainnya",
}

export function AdminLaporanPage() {
  // Initialize with current month
  const [selectedPreset, setSelectedPreset] = useState("current_month")
  const [dateRange, setDateRange] = useState(getCurrentMonthRange())
  const [customDateRange, setCustomDateRange] = useState<DateRange | undefined>()

  const { data: report, isLoading, error, refetch } = useApplicantReportQuery(dateRange)

  /**
   * Handle preset filter change
   */
  const handlePresetChange = (value: string) => {
    setSelectedPreset(value)
    if (value !== "custom") {
      const preset = FILTER_PRESETS.find(p => p.value === value)
      if (preset) {
        const range = preset.getRange()
        setDateRange(range)
      }
    }
  }

  /**
   * Handle custom date range change
   */
  const handleCustomDateChange = (range: DateRange | undefined) => {
    setCustomDateRange(range)
    if (range?.from && range?.to) {
      setDateRange({
        start_date: formatDateForAPI(range.from),
        end_date: formatDateForAPI(range.to),
      })
    }
  }

  /**
   * Format date range for display
   */
  const formatDateRangeDisplay = () => {
    if (!report) return ""
    const start = parseAPIDate(report.date_range.start_date)
    const end = parseAPIDate(report.date_range.end_date)
    return `${format(start, "dd MMM yyyy", { locale: id })} - ${format(end, "dd MMM yyyy", { locale: id })}`
  }

  /**
   * Handle export to Excel (placeholder - can be implemented later)
   */
  const handleExport = () => {
    // TODO: Implement Excel export
    console.log("Export report", report)
  }

  return (
    <div className="flex flex-col gap-6 px-6 py-6 md:px-8 md:py-8">
      {/* Header */}
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight md:text-3xl">Laporan Pelamar</h1>
          <p className="text-muted-foreground">
            {report && formatDateRangeDisplay()}
          </p>
        </div>
        <div className="flex flex-col gap-2 sm:flex-row">
          <Button
            variant="outline"
            size="sm"
            onClick={() => refetch()}
            disabled={isLoading}
          >
            <IconRefresh className={cn("mr-2 size-4", isLoading && "animate-spin")} />
            Refresh
          </Button>
          <Button
            size="sm"
            onClick={handleExport}
            disabled={isLoading || !report}
          >
            <IconDownload className="mr-2 size-4" />
            Export Excel
          </Button>
        </div>
      </div>

      {/* Filters */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Filter Periode</CardTitle>
          <CardDescription>Pilih rentang tanggal untuk laporan</CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-4 sm:flex-row sm:items-end">
          <div className="flex-1">
            <label className="text-sm font-medium">Preset</label>
            <Select value={selectedPreset} onValueChange={handlePresetChange}>
              <SelectTrigger className="mt-1.5">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {FILTER_PRESETS.map(preset => (
                  <SelectItem key={preset.value} value={preset.value}>
                    {preset.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {selectedPreset === "custom" && (
            <div className="flex-1">
              <label className="text-sm font-medium">Rentang Tanggal Custom</label>
              <Popover>
                <PopoverTrigger asChild>
                  <Button variant="outline" className="mt-1.5 w-full justify-start text-left">
                    <IconCalendar className="mr-2 size-4" />
                    {customDateRange?.from && customDateRange?.to ? (
                      <>
                        {format(customDateRange.from, "dd MMM yyyy", { locale: id })} -{" "}
                        {format(customDateRange.to, "dd MMM yyyy", { locale: id })}
                      </>
                    ) : (
                      <span>Pilih tanggal</span>
                    )}
                  </Button>
                </PopoverTrigger>
                <PopoverContent className="w-auto p-0" align="start">
                  <Calendar
                    mode="range"
                    selected={customDateRange}
                    onSelect={handleCustomDateChange}
                    numberOfMonths={2}
                    locale={id}
                  />
                </PopoverContent>
              </Popover>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Loading State */}
      {isLoading && (
        <div className="space-y-6">
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            {Array.from({ length: 5 }).map((_, i) => (
              <Skeleton key={i} className="h-32" />
            ))}
          </div>
          <Skeleton className="h-64" />
        </div>
      )}

      {/* Error State */}
      {error && (
        <Card className="border-destructive">
          <CardHeader>
            <CardTitle className="text-destructive">Gagal Memuat Laporan</CardTitle>
            <CardDescription>
              Terjadi kesalahan saat memuat data. Silakan coba lagi.
            </CardDescription>
          </CardHeader>
        </Card>
      )}

      {/* Report Content */}
      {report && !isLoading && (
        <>
          {/* Summary Cards */}
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-5">
            <StatCard
              title="Total Pelamar"
              value={report.summary.total_applicants}
              icon={<IconUsers className="size-4" />}
              description="Pendaftar dalam periode"
            />
            <StatCard
              title="Diterima"
              value={report.summary.total_accepted}
              icon={<IconUserCheck className="size-4" />}
              description="Lolos verifikasi"
              className="border-green-200 bg-green-50/50 dark:border-green-900 dark:bg-green-950/20"
            />
            <StatCard
              title="Ditolak"
              value={report.summary.total_rejected}
              icon={<IconUserX className="size-4" />}
              description="Tidak lolos"
              className="border-red-200 bg-red-50/50 dark:border-red-900 dark:bg-red-950/20"
            />
            <StatCard
              title="Dikirim"
              value={report.summary.total_submitted}
              icon={<IconFileCheck className="size-4" />}
              description="Menunggu review"
              className="border-blue-200 bg-blue-50/50 dark:border-blue-900 dark:bg-blue-950/20"
            />
            <StatCard
              title="Kelengkapan Dokumen"
              value={`${report.summary.completion_rate}%`}
              icon={<IconChartBar className="size-4" />}
              description="Dokumen lengkap"
            />
          </div>

          {/* Charts and Tables Grid */}
          <div className="grid gap-6 lg:grid-cols-2">
            {/* Status Breakdown */}
            <Card>
              <CardHeader>
                <CardTitle>Status Verifikasi</CardTitle>
                <CardDescription>Distribusi berdasarkan status</CardDescription>
              </CardHeader>
              <CardContent>
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Status</TableHead>
                      <TableHead className="text-right">Jumlah</TableHead>
                      <TableHead className="text-right">Persentase</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {report.by_status.map((item) => (
                      <TableRow key={item.verification_status}>
                        <TableCell className="font-medium">
                          {STATUS_LABELS[item.verification_status] || item.verification_status}
                        </TableCell>
                        <TableCell className="text-right">{item.count}</TableCell>
                        <TableCell className="text-right">
                          {((item.count / report.summary.total_applicants) * 100).toFixed(1)}%
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </CardContent>
            </Card>

            {/* Province Breakdown */}
            <Card>
              <CardHeader>
                <CardTitle>Top 10 Provinsi</CardTitle>
                <CardDescription>Asal pelamar terbanyak</CardDescription>
              </CardHeader>
              <CardContent>
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Provinsi</TableHead>
                      <TableHead className="text-right">Jumlah</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {report.by_province.length > 0 ? (
                      report.by_province.map((item, index) => (
                        <TableRow key={index}>
                          <TableCell className="font-medium">
                            <div className="flex items-center gap-2">
                              <IconMapPin className="size-4 text-muted-foreground" />
                              {item.province_name || "Tidak diketahui"}
                            </div>
                          </TableCell>
                          <TableCell className="text-right">{item.count}</TableCell>
                        </TableRow>
                      ))
                    ) : (
                      <TableRow>
                        <TableCell colSpan={2} className="text-center text-muted-foreground">
                          Tidak ada data
                        </TableCell>
                      </TableRow>
                    )}
                  </TableBody>
                </Table>
              </CardContent>
            </Card>

            {/* Gender Breakdown */}
            <Card>
              <CardHeader>
                <CardTitle>Jenis Kelamin</CardTitle>
                <CardDescription>Distribusi berdasarkan gender</CardDescription>
              </CardHeader>
              <CardContent>
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Jenis Kelamin</TableHead>
                      <TableHead className="text-right">Jumlah</TableHead>
                      <TableHead className="text-right">Persentase</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {report.by_gender.map((item, index) => (
                      <TableRow key={index}>
                        <TableCell className="font-medium">
                          {item.gender ? GENDER_LABELS[item.gender] || item.gender : "Tidak diketahui"}
                        </TableCell>
                        <TableCell className="text-right">{item.count}</TableCell>
                        <TableCell className="text-right">
                          {((item.count / report.summary.total_applicants) * 100).toFixed(1)}%
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </CardContent>
            </Card>

            {/* Education Breakdown */}
            <Card>
              <CardHeader>
                <CardTitle>Pendidikan Terakhir</CardTitle>
                <CardDescription>Distribusi tingkat pendidikan</CardDescription>
              </CardHeader>
              <CardContent>
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Pendidikan</TableHead>
                      <TableHead className="text-right">Jumlah</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {report.by_education.length > 0 ? (
                      report.by_education.map((item, index) => (
                        <TableRow key={index}>
                          <TableCell className="font-medium">
                            {item.education_level || "Tidak diketahui"}
                          </TableCell>
                          <TableCell className="text-right">{item.count}</TableCell>
                        </TableRow>
                      ))
                    ) : (
                      <TableRow>
                        <TableCell colSpan={2} className="text-center text-muted-foreground">
                          Tidak ada data
                        </TableCell>
                      </TableRow>
                    )}
                  </TableBody>
                </Table>
              </CardContent>
            </Card>
          </div>

          {/* Referrer Breakdown */}
          {report.by_referrer.length > 0 && (
            <Card>
              <CardHeader>
                <CardTitle>Top 10 Staff Rujukan</CardTitle>
                <CardDescription>Staff dengan rujukan terbanyak</CardDescription>
              </CardHeader>
              <CardContent>
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Nama Staff</TableHead>
                      <TableHead className="text-right">Jumlah Rujukan</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {report.by_referrer.map((item) => (
                      <TableRow key={item.staff_id}>
                        <TableCell className="font-medium">{item.staff_name}</TableCell>
                        <TableCell className="text-right">{item.count}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </CardContent>
            </Card>
          )}

          {/* Timeline Chart (simple table for now) */}
          {report.timeline.length > 0 && (
            <Card>
              <CardHeader>
                <CardTitle>Grafik Pendaftaran Harian</CardTitle>
                <CardDescription>Jumlah pendaftar per hari</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="max-h-64 overflow-y-auto">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Tanggal</TableHead>
                        <TableHead className="text-right">Jumlah</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {report.timeline.map((item) => (
                        <TableRow key={item.date}>
                          <TableCell className="font-medium">
                            {format(parseAPIDate(item.date), "dd MMM yyyy", { locale: id })}
                          </TableCell>
                          <TableCell className="text-right">{item.count}</TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              </CardContent>
            </Card>
          )}
        </>
      )}
    </div>
  )
}
