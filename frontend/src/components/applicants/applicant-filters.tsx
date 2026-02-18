/**
 * Advanced Filters Panel for Applicants Table
 * Provides district, province, date range, and other advanced filters
 */

import { useState } from "react"
import { IconFilter, IconX, IconCalendar, IconChevronDown, IconChevronUp } from "@tabler/icons-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import {  
  RELIGION_LABELS,
  EDUCATION_LEVEL_LABELS,
  MARITAL_STATUS_LABELS,
  WORK_COUNTRY_OPTIONS,
} from "@/constants/applicant"
import type { ApplicantsListParams } from "@/types/applicant"

interface ApplicantFiltersProps {
  onFiltersChange: (filters: Partial<ApplicantsListParams>) => void
  onReset: () => void
}

export function ApplicantFilters({
  onFiltersChange,
  onReset,
}: ApplicantFiltersProps) {
  const [isExpanded, setIsExpanded] = useState(false)
  const [filters, setFilters] = useState<Partial<ApplicantsListParams>>({})

  const updateFilter = <K extends keyof ApplicantsListParams>(
    key: K,
    value: ApplicantsListParams[K]
  ) => {
    const newFilters = {
      ...filters,
      [key]: value === "" || value === "all" ? undefined : value,
    }
    setFilters(newFilters)
  }

  const handleApply = () => {
    onFiltersChange(filters)
  }

  const handleReset = () => {
    setFilters({})
    onReset()
  }

  const activeFilterCount = Object.keys(filters).filter(
    (key) => filters[key as keyof ApplicantsListParams] !== undefined
  ).length

  return (
    <Card>
      <CardHeader
        className="cursor-pointer flex-row items-center justify-between space-y-0 py-4"
        onClick={() => setIsExpanded(!isExpanded)}
      >
        <div className="flex items-center gap-2">
          <IconFilter className="size-4" />
          <CardTitle className="text-base">Filter Lanjutan</CardTitle>
          {activeFilterCount > 0 && (
            <span className="bg-primary text-primary-foreground flex h-5 w-5 items-center justify-center rounded-full text-xs font-semibold">
              {activeFilterCount}
            </span>
          )}
        </div>
        <div className="flex items-center gap-2">
          {activeFilterCount > 0 && (
            <Button
              variant="ghost"
              size="sm"
              className="cursor-pointer h-8 px-2"
              onClick={(e) => {
                e.stopPropagation()
                handleReset()
              }}
            >
              <IconX className="mr-1 size-3" />
              Reset
            </Button>
          )}
          {isExpanded ? (
            <IconChevronUp className="size-4" />
          ) : (
            <IconChevronDown className="size-4" />
          )}
        </div>
      </CardHeader>

      {isExpanded && (
        <CardContent className="space-y-4 pt-0">
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {/* Province Filter (ID from regions) */}
            <div className="space-y-2">
              <Label htmlFor="province">Provinsi (ID)</Label>
              <Input
                id="province"
                type="number"
                min={1}
                placeholder="ID provinsi..."
                value={filters.province ?? ""}
                onChange={(e) =>
                  updateFilter("province", e.target.value ? Number(e.target.value) : undefined)
                }
              />
            </div>

            {/* District Filter (Regency ID from regions) */}
            <div className="space-y-2">
              <Label htmlFor="district">Kabupaten/Kota (ID)</Label>
              <Input
                id="district"
                type="number"
                min={1}
                placeholder="ID kabupaten/kota..."
                value={filters.district ?? ""}
                onChange={(e) =>
                  updateFilter("district", e.target.value ? Number(e.target.value) : undefined)
                }
              />
            </div>

            {/* Religion Filter */}
            <div className="space-y-2">
              <Label htmlFor="religion">Agama</Label>
              <Select
                value={filters.religion || "all"}
                onValueChange={(v) => updateFilter("religion", v as any)}
              >
                <SelectTrigger id="religion" className="cursor-pointer">
                  <SelectValue placeholder="Semua Agama" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Semua Agama</SelectItem>
                  {Object.entries(RELIGION_LABELS).map(([value, label]) => (
                    <SelectItem key={value} value={value}>
                      {label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Education Level Filter */}
            <div className="space-y-2">
              <Label htmlFor="education">Pendidikan</Label>
              <Select
                value={filters.education_level || "all"}
                onValueChange={(v) => updateFilter("education_level", v as any)}
              >
                <SelectTrigger id="education" className="cursor-pointer">
                  <SelectValue placeholder="Semua Pendidikan" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Semua Pendidikan</SelectItem>
                  {Object.entries(EDUCATION_LEVEL_LABELS).map(([value, label]) => (
                    <SelectItem key={value} value={value}>
                      {label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Marital Status Filter */}
            <div className="space-y-2">
              <Label htmlFor="marital">Status Pernikahan</Label>
              <Select
                value={filters.marital_status || "all"}
                onValueChange={(v) => updateFilter("marital_status", v as any)}
              >
                <SelectTrigger id="marital" className="cursor-pointer">
                  <SelectValue placeholder="Semua Status" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Semua Status</SelectItem>
                  {Object.entries(MARITAL_STATUS_LABELS).map(([value, label]) => (
                    <SelectItem key={value} value={value}>
                      {label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Work Country Filter */}
            <div className="space-y-2">
              <Label htmlFor="country">Negara Tujuan</Label>
              <Select
                value={filters.work_country || "all"}
                onValueChange={(v) => updateFilter("work_country", v as any)}
              >
                <SelectTrigger id="country" className="cursor-pointer">
                  <SelectValue placeholder="Semua Negara" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Semua Negara</SelectItem>
                  {WORK_COUNTRY_OPTIONS.map(([value, label]) => (
                    <SelectItem key={value} value={value}>
                      {label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Submitted After Date */}
            <div className="space-y-2">
              <Label htmlFor="submitted-after">Dikirim Setelah</Label>
              <div className="relative">
                <Input
                  id="submitted-after"
                  type="date"
                  value={filters.submitted_after || ""}
                  onChange={(e) => updateFilter("submitted_after", e.target.value)}
                />
                <IconCalendar className="text-muted-foreground pointer-events-none absolute right-3 top-1/2 size-4 -translate-y-1/2" />
              </div>
            </div>

            {/* Submitted Before Date */}
            <div className="space-y-2">
              <Label htmlFor="submitted-before">Dikirim Sebelum</Label>
              <div className="relative">
                <Input
                  id="submitted-before"
                  type="date"
                  value={filters.submitted_before || ""}
                  onChange={(e) => updateFilter("submitted_before", e.target.value)}
                />
                <IconCalendar className="text-muted-foreground pointer-events-none absolute right-3 top-1/2 size-4 -translate-y-1/2" />
              </div>
            </div>

            {/* Referrer Search */}
            <div className="space-y-2">
              <Label htmlFor="referrer">Referrer (ID)</Label>
              <Input
                id="referrer"
                type="number"
                placeholder="Masukkan ID referrer..."
                value={filters.referrer != null ? String(filters.referrer) : ""}
                onChange={(e) => updateFilter("referrer", e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>
          </div>

          <div className="flex justify-end gap-2">
            <Button
              variant="outline"
              className="cursor-pointer"
              onClick={handleReset}
            >
              Reset Filter
            </Button>
            <Button
              variant="default"
              className="cursor-pointer"
              onClick={handleApply}
            >
              <IconFilter className="mr-2 size-4" />
              Terapkan Filter
            </Button>
          </div>
        </CardContent>
      )}
    </Card>
  )
}
