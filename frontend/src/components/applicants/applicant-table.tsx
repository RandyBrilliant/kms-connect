/**
 * Applicant (Pelamar) table with server-side pagination, search, and filters.
 * Uses TanStack Table for display and TanStack Query for data.
 * Includes bulk selection and verification workflow.
 */

import { useState, useMemo, useCallback, useEffect } from "react"
import { Link, useNavigate } from "react-router-dom"
import {
  flexRender,
  getCoreRowModel,
  useReactTable,
  type ColumnDef,
} from "@tanstack/react-table"
import { useIsMobile } from "@/hooks/use-mobile"
import {
  IconArrowsSort,
  IconChevronLeft,
  IconChevronRight,
  IconEye,
  IconLayoutRows,
  IconPlus,
  IconSearch,
  IconSortAscending,
  IconSortDescending,
  IconChecks,
  IconX,
  IconDownload,
} from "@tabler/icons-react"

import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Checkbox } from "@/components/ui/checkbox"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import {
  useApplicantsQuery,
  useBulkApproveApplicantsMutation,
  useBulkRejectApplicantsMutation,
} from "@/hooks/use-applicants-query"
import { toast } from "@/lib/toast"
import {
  RELIGION_LABELS,
  VERIFICATION_STATUS_LABELS,
  getGenderLabel,
  getReligionLabel,
  getVerificationStatusLabel,
} from "@/constants/applicant"
import { calculateApplicantAgeYears, formatDate } from "@/lib/formatters"
import { cn } from "@/lib/utils"
import { isSubmittedStatus } from "@/lib/type-guards"
import { VerificationModal } from "./verification-modal"
import { exportApplicants } from "@/api/applicants"
import { DateRangePicker } from "@/components/ui/date-range-picker"
import { SearchableSelect } from "@/components/ui/searchable-select"
import { type DateRange } from "react-day-picker"
import { useReferrersQuery } from "@/hooks/use-referrers-query"
import { format } from "date-fns"
import type {
  ApplicantUser,
  ApplicantsListParams,
  ApplicantVerificationStatus,
  Gender,
  Religion,
} from "@/types/applicant"

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100]

const APPLICANT_FILTER_TRIGGER_CLASS =
  "h-9 w-full min-w-0 cursor-pointer shadow-none sm:min-h-0"

/** Default list order: tanggal bergabung terbaru dulu (kolom tidak ditampilkan di tabel). */
const DEFAULT_APPLICANT_LIST_ORDERING = "-applicant_profile__created_at"

/** Warna pill status verifikasi: Dikirim / Diterima / Ditolak */
function verificationStatusPillClass(status: string): string {
  switch (status) {
    case "SUBMITTED":
      return "bg-amber-600 text-white dark:bg-amber-700"
    case "ACCEPTED":
      return "bg-emerald-600 text-white dark:bg-emerald-700"
    case "REJECTED":
      return "bg-red-600 text-white dark:bg-red-700"
    default:
      return "bg-muted text-muted-foreground"
  }
}

function VerificationStatusPill({ status }: { status: string }) {
  return (
    <span
      className={`inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium shadow-sm ${verificationStatusPillClass(status)}`}
    >
      {getVerificationStatusLabel(status as ApplicantVerificationStatus)}
    </span>
  )
}

/** Server-side ordering field (DRF `ordering` query) without leading `-`. */
const SORT_FIELD = {
  pelamar: "full_name",
  jenisKelamin: "applicant_profile__gender",
  umur: "applicant_profile__birth_date",
  agama: "applicant_profile__religion",
  rujukan: "applicant_profile__referrer__full_name",
  skor: "applicant_profile__score",
  verifikasi: "applicant_profile__verification_status",
} as const

function SortableColumnHead({
  field,
  label,
  ordering,
  onSort,
  className,
}: {
  field: string
  label: string
  ordering?: string
  onSort: (field: string) => void
  className?: string
}) {
  const asc = field
  const desc = `-${field}`
  const isAsc = ordering === asc
  const isDesc = ordering === desc
  const isActive = isAsc || isDesc

  return (
    <button
      type="button"
      className={cn(
        "-mx-1 inline-flex max-w-full min-w-0 items-center gap-2 rounded-lg px-1.5 py-1 text-left text-sm font-semibold transition-colors",
        "text-muted-foreground hover:bg-muted/80 hover:text-foreground",
        isActive && "text-foreground",
        className
      )}
      onClick={() => onSort(field)}
      title={`Urutkan: ${label}`}
      aria-sort={isAsc ? "ascending" : isDesc ? "descending" : "none"}
    >
      <span className="min-w-0 truncate">{label}</span>
      <span
        className={cn(
          "flex size-7 shrink-0 items-center justify-center rounded-md border shadow-sm transition-colors",
          isActive
            ? "border-primary/30 bg-primary/10 text-primary"
            : "border-border/50 bg-background/80 text-muted-foreground/80"
        )}
        aria-hidden
      >
        {isAsc ? (
          <IconSortAscending className="size-3.5" stroke={2} />
        ) : isDesc ? (
          <IconSortDescending className="size-3.5" stroke={2} />
        ) : (
          <IconArrowsSort className="size-3.5 opacity-75" stroke={1.75} />
        )}
      </span>
    </button>
  )
}

function applicantTableHeadClass(columnId: string) {
  return cn(
    "h-11 border-border/50 px-3 py-2 text-left align-middle first:pl-4 last:pr-4 sm:first:pl-5 sm:last:pr-5",
    columnId === "select" && "w-12",
    columnId === "actions" && "w-14",
    columnId === "skor" && "tabular-nums",
    columnId === "umur" && "tabular-nums"
  )
}

function applicantTableCellClass(columnId: string) {
  return cn(
    "border-border/40 px-3 py-2.5 align-middle first:pl-4 last:pr-4 sm:first:pl-5 sm:last:pr-5",
    columnId === "select" && "w-12",
    (columnId === "pelamar" || columnId === "rujukan") &&
      "max-w-[min(22rem,32vw)] whitespace-normal",
    columnId === "jenis_kelamin" && "whitespace-nowrap",
    columnId === "umur" && "tabular-nums",
    columnId === "agama" && "max-w-[10rem] whitespace-normal",
    columnId === "skor" && "tabular-nums font-medium",
    columnId === "verifikasi" && "whitespace-normal",
    columnId === "actions" && "w-14 text-right"
  )
}

/** Kolom Rujukan: pakai display_name dari API (nama DB atau label dari email lokal), bukan kode. */
function staffRujukanDisplayName(
  profile: ApplicantUser["applicant_profile"] | undefined
): string {
  const r = profile?.referrer_display
  if (!r) return ""
  const label = (r.display_name ?? r.full_name ?? "").trim()
  return label
}

function PelamarIdentityBlock({ applicant }: { applicant: ApplicantUser }) {
  const profile = applicant.applicant_profile

  return (
    <div className="flex min-w-0 flex-col gap-0.5 py-0.5">
      <span className="font-medium leading-tight break-words">
        {profile?.full_name || "—"}
      </span>
      <span className="text-muted-foreground text-sm break-all leading-tight">
        {applicant.email}
      </span>
    </div>
  )
}

/** Nama rujukan + kode di baris kedua (desktop & mobile). */
function RujukanBlock({
  profile,
}: {
  profile: ApplicantUser["applicant_profile"] | undefined
}) {
  const r = profile?.referrer_display
  const name = staffRujukanDisplayName(profile)
  const code = (r?.referral_code ?? "").trim()
  if (!name && !code) {
    return <span className="text-muted-foreground">—</span>
  }
  return (
    <div className="flex min-w-0 flex-col gap-0.5">
      {name ? (
        <span className="font-medium leading-tight break-words">{name}</span>
      ) : null}
      {code ? (
        <span
          className={
            name
              ? "text-muted-foreground text-xs tabular-nums leading-tight"
              : "font-medium tabular-nums leading-tight"
          }
        >
          {code}
        </span>
      ) : null}
    </div>
  )
}

function RujukanCell({ applicant }: { applicant: ApplicantUser }) {
  return (
    <div className="min-w-0 py-0.5">
      <RujukanBlock profile={applicant.applicant_profile} />
    </div>
  )
}

interface ApplicantTableProps {
  basePath: string
}

export function ApplicantTable({ basePath }: ApplicantTableProps) {
  const navigate = useNavigate()
  const isMobile = useIsMobile()
  const [params, setParams] = useState<ApplicantsListParams>({
    page: 1,
    page_size: 20,
    search: "",
    ordering: DEFAULT_APPLICANT_LIST_ORDERING,
  })
  const [searchInput, setSearchInput] = useState("")
  const [rowSelection, setRowSelection] = useState<Record<string, boolean>>({})
  const [showVerificationModal, setShowVerificationModal] = useState(false)
  const [verificationAction, setVerificationAction] = useState<"approve" | "reject" | null>(null)
  const [isExporting, setIsExporting] = useState(false)
  const [dateRange, setDateRange] = useState<DateRange | undefined>(undefined)

  // Sync dateRange state with params when they change externally (e.g., from URL or reset)
  useEffect(() => {
    const from = params.created_at_after ? new Date(params.created_at_after) : undefined
    const to = params.created_at_before ? new Date(params.created_at_before) : undefined
    
    // Only update if different to avoid infinite loops
    const currentFrom = dateRange?.from
    const currentTo = dateRange?.to
    const fromChanged = from?.getTime() !== currentFrom?.getTime()
    const toChanged = to?.getTime() !== currentTo?.getTime()
    
    if (fromChanged || toChanged) {
      if (from || to) {
        setDateRange({ from: from ?? undefined, to: to ?? undefined })
      } else {
        setDateRange(undefined)
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [params.created_at_after, params.created_at_before])

  const { data, isLoading, isError, error } = useApplicantsQuery(params)
  const { data: referrers = [], isPending: referrersLoading } = useReferrersQuery()
  const bulkApproveMutation = useBulkApproveApplicantsMutation()
  const bulkRejectMutation = useBulkRejectApplicantsMutation()

  // Get selected applicants
  const selectedApplicants = useMemo(() => {
    const selectedIds = Object.keys(rowSelection).filter((id) => rowSelection[id])
    return (data?.results || []).filter((applicant) =>
      selectedIds.includes(String(applicant.id))
    )
  }, [rowSelection, data?.results])

  // Check if all selected applicants are eligible for verification actions
  const canBulkVerify = useMemo(() => {
    if (selectedApplicants.length === 0) return false
    return selectedApplicants.every((applicant) =>
      isSubmittedStatus(applicant.applicant_profile?.verification_status || "")
    )
  }, [selectedApplicants])

  const handleSearch = useCallback(() => {
    setParams((p) => ({
      ...p,
      search: searchInput.trim() || undefined,
      page: 1,
    }))
    setRowSelection({})
  }, [searchInput])

  const handleFilterChange = useCallback(
    <K extends keyof ApplicantsListParams>(key: K, value: ApplicantsListParams[K]) => {
      setParams((p) => ({ ...p, [key]: value, page: 1 }))
      setRowSelection({})
    },
    []
  )

  const referrerSelectItems = useMemo(
    () =>
      referrers.map((r) => {
        const label = (r.full_name ?? "").trim() || r.email
        return {
          id: r.id,
          name: r.referral_code ? `${label} · ${r.referral_code}` : label,
        }
      }),
    [referrers]
  )

  const handleDateRangeChange = useCallback((range: DateRange | undefined) => {
    setDateRange(range)
    setParams((p) => ({
      ...p,
      created_at_after: range?.from ? format(range.from, "yyyy-MM-dd") : undefined,
      created_at_before: range?.to ? format(range.to, "yyyy-MM-dd") : undefined,
      page: 1,
    }))
    setRowSelection({}) // Clear selection on filter change
  }, [])

  const handleSortColumn = useCallback((field: string) => {
    setParams((p) => {
      const cur = p.ordering
      const asc = field
      const desc = `-${field}`
      const next =
        cur === asc ? desc : cur === desc ? asc : asc
      return { ...p, ordering: next, page: 1 }
    })
    setRowSelection({})
  }, [])

  const handlePageChange = (page: number) => {
    setParams((p) => ({ ...p, page }))
    setRowSelection({}) // Clear selection on page change
  }

  const handleBulkApprove = useCallback(() => {
    setVerificationAction("approve")
    setShowVerificationModal(true)
  }, [])

  const handleBulkReject = useCallback(() => {
    setVerificationAction("reject")
    setShowVerificationModal(true)
  }, [])

  const handleClearSelection = useCallback(() => {
    setRowSelection({})
  }, [])

  const handleExport = useCallback(async () => {
    setIsExporting(true)
    try {
      // Build export params (exclude pagination)
      const exportParams: Omit<ApplicantsListParams, "page" | "page_size"> = {
        search: params.search,
        email_verified: params.email_verified,
        verification_status: params.verification_status,
        referrer: params.referrer,
        created_at_after: params.created_at_after,
        created_at_before: params.created_at_before,
        gender: params.gender,
        religion: params.religion,
        age_min: params.age_min,
        age_max: params.age_max,
        ordering: params.ordering,
      }

      const blob = await exportApplicants(exportParams)
      
      // Create download link
      const url = window.URL.createObjectURL(blob)
      const link = document.createElement("a")
      link.href = url
      
      // Generate filename with current date
      const today = new Date()
      const dateStr = today.toISOString().split("T")[0]
      link.download = `pelamar-${dateStr}.xlsx`
      
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      window.URL.revokeObjectURL(url)
      
      toast.success("Ekspor berhasil", "Data pelamar berhasil diekspor ke Excel")
    } catch (error) {
      console.error("Export error:", error)
      toast.error("Gagal mengekspor", "Terjadi kesalahan saat mengekspor data. Coba lagi nanti.")
    } finally {
      setIsExporting(false)
    }
  }, [params])

  const handleVerificationConfirm = useCallback(
    async (notes: string) => {
      if (!verificationAction || selectedApplicants.length === 0) return

      try {
        // Extract profile IDs from selected applicants
        const profileIds = selectedApplicants
          .map((a) => a.applicant_profile?.id)
          .filter((id): id is number => id !== undefined)

        if (profileIds.length === 0) {
          toast.error("Gagal memproses", "Tidak ada profil yang valid untuk diverifikasi")
          return
        }

        if (verificationAction === "approve") {
          await bulkApproveMutation.mutateAsync({ profileIds, notes })
          toast.success(
            `${selectedApplicants.length} pelamar diterima`,
            "Verifikasi berhasil diproses"
          )
        } else {
          await bulkRejectMutation.mutateAsync({ profileIds, notes })
          toast.success(
            `${selectedApplicants.length} pelamar ditolak`,
            "Verifikasi berhasil diproses"
          )
        }

        // Clear selection and close modal
        setRowSelection({})
        setShowVerificationModal(false)
        setVerificationAction(null)
      } catch {
        toast.error(
          "Gagal memproses verifikasi",
          "Terjadi kesalahan. Periksa koneksi dan coba lagi."
        )
      }
    },
    [verificationAction, selectedApplicants, bulkApproveMutation, bulkRejectMutation]
  )

  const columns = useMemo<ColumnDef<ApplicantUser>[]>(
    () => [
      {
        id: "select",
        header: ({ table }) => (
          <Checkbox
            checked={table.getIsAllPageRowsSelected()}
            onCheckedChange={(value) => table.toggleAllPageRowsSelected(!!value)}
            aria-label="Pilih semua"
          />
        ),
        cell: ({ row }) => (
          <Checkbox
            checked={row.getIsSelected()}
            onCheckedChange={(value) => row.toggleSelected(!!value)}
            aria-label="Pilih baris"
          />
        ),
        enableSorting: false,
        enableHiding: false,
      },
      {
        id: "pelamar",
        accessorKey: "applicant_profile.full_name",
        header: () => (
          <SortableColumnHead
            field={SORT_FIELD.pelamar}
            label="Pelamar"
            ordering={params.ordering}
            onSort={handleSortColumn}
          />
        ),
        cell: ({ row }) => <PelamarIdentityBlock applicant={row.original} />,
      },
      {
        id: "jenis_kelamin",
        accessorFn: (row) => row.applicant_profile?.gender ?? "",
        header: () => (
          <SortableColumnHead
            field={SORT_FIELD.jenisKelamin}
            label="Jenis kelamin"
            ordering={params.ordering}
            onSort={handleSortColumn}
          />
        ),
        cell: ({ row }) => {
          const g = row.original.applicant_profile?.gender
          if (g !== "M" && g !== "F") {
            return <span className="text-muted-foreground">—</span>
          }
          return <span>{getGenderLabel(g)}</span>
        },
      },
      {
        id: "umur",
        accessorFn: (row) =>
          calculateApplicantAgeYears(row.applicant_profile?.birth_date ?? null),
        header: () => (
          <SortableColumnHead
            field={SORT_FIELD.umur}
            label="Umur"
            ordering={params.ordering}
            onSort={handleSortColumn}
          />
        ),
        cell: ({ row }) => {
          const age = calculateApplicantAgeYears(
            row.original.applicant_profile?.birth_date ?? null
          )
          if (age == null) {
            return <span className="text-muted-foreground">—</span>
          }
          return <span>{age}</span>
        },
      },
      {
        id: "agama",
        accessorFn: (row) => row.applicant_profile?.religion ?? "",
        header: () => (
          <SortableColumnHead
            field={SORT_FIELD.agama}
            label="Agama"
            ordering={params.ordering}
            onSort={handleSortColumn}
          />
        ),
        cell: ({ row }) => {
          const r = row.original.applicant_profile?.religion
          if (!r) {
            return <span className="text-muted-foreground">—</span>
          }
          return (
            <span className="leading-snug">{getReligionLabel(r as Religion)}</span>
          )
        },
      },
      {
        id: "rujukan",
        accessorFn: (row) => staffRujukanDisplayName(row.applicant_profile),
        header: () => (
          <SortableColumnHead
            field={SORT_FIELD.rujukan}
            label="Rujukan"
            ordering={params.ordering}
            onSort={handleSortColumn}
          />
        ),
        cell: ({ row }) => <RujukanCell applicant={row.original} />,
      },
      {
        id: "skor",
        accessorKey: "applicant_profile.score",
        header: () => (
          <SortableColumnHead
            field={SORT_FIELD.skor}
            label="Skor"
            ordering={params.ordering}
            onSort={handleSortColumn}
          />
        ),
        cell: ({ row }) => {
          const score = row.original.applicant_profile?.score
          if (score == null) {
            return <span className="text-muted-foreground">—</span>
          }
          return <span>{Math.round(score)}</span>
        },
      },
      {
        id: "verifikasi",
        accessorKey: "applicant_profile.verification_status",
        header: () => (
          <SortableColumnHead
            field={SORT_FIELD.verifikasi}
            label="Status Verifikasi"
            ordering={params.ordering}
            onSort={handleSortColumn}
          />
        ),
        cell: ({ row }) => {
          const status = row.original.applicant_profile?.verification_status
          if (!status) return <span className="text-muted-foreground">—</span>
          return <VerificationStatusPill status={status} />
        },
      },
      {
        id: "actions",
        header: "",
        cell: ({ row }) => {
          const applicant = row.original
          return (
            <div className="flex items-center justify-end gap-1">
              <Button
                variant="outline"
                size="icon"
                className="size-8 cursor-pointer rounded-lg border-border/80 bg-background/80 shadow-sm hover:bg-muted/60"
                onClick={() => navigate(`${basePath}/${applicant.id}`)}
                title="Lihat Detail"
              >
                <IconEye className="size-4" />
                <span className="sr-only">Lihat Detail</span>
              </Button>
            </div>
          )
        },
      },
    ],
    [basePath, navigate, params.ordering, handleSortColumn]
  )

  const table = useReactTable({
    data: data?.results ?? [],
    columns,
    getCoreRowModel: getCoreRowModel(),
    onRowSelectionChange: setRowSelection,
    getRowId: (row) => String(row.id),
    state: {
      rowSelection,
    },
    manualPagination: true,
    pageCount: data ? Math.ceil(data.count / (params.page_size ?? 20)) : 0,
    enableRowSelection: true,
  })

  const pageCount = data ? Math.ceil(data.count / (params.page_size ?? 20)) : 0
  const currentPage = params.page ?? 1
  const pageSize = params.page_size ?? 20
  const paginationFooter =
    data && data.count > 0
      ? {
          rangeStart: (currentPage - 1) * pageSize + 1,
          rangeEnd: Math.min(currentPage * pageSize, data.count),
          totalPages: pageCount || 1,
          totalCount: data.count,
        }
      : null

  if (isError) {
    return (
      <div className="rounded-lg border border-destructive/50 bg-destructive/5 p-4 text-center">
        <p className="text-destructive">
          Gagal memuat data: {(error as Error).message}
        </p>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-4">
      <section
        aria-label="Pencarian dan filter pelamar"
        className="overflow-hidden rounded-xl border bg-card text-card-foreground shadow-sm"
      >
        <div className="border-b bg-muted/30 px-4 py-3 sm:px-5 sm:py-3.5 dark:bg-muted/15">
          <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between lg:gap-4">
            <div className="flex min-w-0 flex-1 flex-col gap-2 sm:flex-row sm:items-center sm:gap-2">
              <div className="relative min-w-0 flex-1">
                <IconSearch className="text-muted-foreground pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2" />
                <Input
                  type="search"
                  enterKeyHint="search"
                  autoComplete="off"
                  placeholder="Cari nama, email, NIK, HP, staff rujukan…"
                  value={searchInput}
                  onChange={(e) => setSearchInput(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && handleSearch()}
                  className="h-9 border-border/80 bg-background pl-9 shadow-sm focus-visible:ring-1"
                />
              </div>
              <Button
                type="button"
                onClick={handleSearch}
                variant="secondary"
                className="h-9 shrink-0 cursor-pointer px-5 sm:w-auto"
              >
                Cari
              </Button>
            </div>
            <div className="flex flex-col gap-2 sm:flex-row sm:justify-end lg:shrink-0">
              <Button
                type="button"
                onClick={handleExport}
                variant="outline"
                className="h-9 cursor-pointer border-border/80 bg-background shadow-sm sm:w-auto"
                disabled={isExporting}
              >
                {isExporting ? (
                  <>
                    <div className="mr-2 size-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
                    Mengekspor…
                  </>
                ) : (
                  <>
                    <IconDownload className="mr-2 size-4 shrink-0 opacity-70" />
                    {isMobile ? "Ekspor" : "Ekspor Excel"}
                  </>
                )}
              </Button>
              <Button
                asChild
                className="h-9 cursor-pointer shadow-sm sm:w-auto"
              >
                <Link to={`${basePath}/new`} className="cursor-pointer">
                  <IconPlus className="mr-2 size-4 shrink-0" />
                  {isMobile ? "Tambah" : "Tambah Pelamar"}
                </Link>
              </Button>
            </div>
          </div>
        </div>

        <div className="px-4 py-3 sm:px-5 sm:py-4">
          <p className="text-muted-foreground sr-only">Filter daftar pelamar</p>
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-12 xl:gap-2">
            <div className="min-w-0 sm:col-span-1 xl:col-span-4">
              <Select
                value={
                  params.verification_status === undefined
                    ? "all"
                    : params.verification_status
                }
                onValueChange={(v) =>
                  handleFilterChange(
                    "verification_status",
                    v === "all" ? undefined : (v as ApplicantVerificationStatus)
                  )
                }
              >
                <SelectTrigger className={APPLICANT_FILTER_TRIGGER_CLASS}>
                  <SelectValue placeholder="Status verifikasi" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Semua verifikasi</SelectItem>
                  {Object.entries(VERIFICATION_STATUS_LABELS).map(([val, label]) => (
                    <SelectItem key={val} value={val}>
                      {label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="min-w-0 sm:col-span-1 xl:col-span-5">
              <SearchableSelect
                className="min-w-0 border-border/80 bg-background shadow-sm"
                items={referrerSelectItems}
                value={params.referrer ?? null}
                onChange={(id) => handleFilterChange("referrer", id ?? undefined)}
                placeholder="Staff rujukan"
                clearLabel="Semua rujukan"
                loading={referrersLoading}
                emptyMessage="Tidak ada staff"
              />
            </div>
            <div className="min-w-0 sm:col-span-2 xl:col-span-3">
              <DateRangePicker
                dateRange={dateRange}
                onDateRangeChange={handleDateRangeChange}
                placeholder="Tanggal bergabung"
                fromYear={2020}
                toYear={new Date().getFullYear()}
                numberOfMonths={isMobile ? 1 : 2}
                className="border-border/80 bg-background shadow-sm"
              />
            </div>
          </div>

          <div className="border-border/40 mt-3 grid grid-cols-1 gap-2 border-t pt-3 sm:grid-cols-2 xl:grid-cols-12 xl:gap-2">
            <div className="min-w-0 xl:col-span-3">
              <Select
                value={params.gender ?? "all"}
                onValueChange={(v) =>
                  handleFilterChange(
                    "gender",
                    v === "all" ? undefined : (v as Gender)
                  )
                }
              >
                <SelectTrigger className={APPLICANT_FILTER_TRIGGER_CLASS}>
                  <SelectValue placeholder="Jenis kelamin" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Semua jenis kelamin</SelectItem>
                  <SelectItem value="M">Laki-laki</SelectItem>
                  <SelectItem value="F">Perempuan</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="min-w-0 xl:col-span-3">
              <Select
                value={params.religion ?? "all"}
                onValueChange={(v) =>
                  handleFilterChange(
                    "religion",
                    v === "all" ? undefined : (v as Religion)
                  )
                }
              >
                <SelectTrigger className={APPLICANT_FILTER_TRIGGER_CLASS}>
                  <SelectValue placeholder="Agama" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Semua agama</SelectItem>
                  {Object.entries(RELIGION_LABELS).map(([val, label]) => (
                    <SelectItem key={val} value={val}>
                      {label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="min-w-0 xl:col-span-3">
              <Label htmlFor="age-min" className="sr-only">
                Umur minimal
              </Label>
              <Input
                id="age-min"
                type="number"
                inputMode="numeric"
                min={0}
                max={150}
                placeholder="Umur min (tahun)"
                value={params.age_min ?? ""}
                onChange={(e) => {
                  const raw = e.target.value
                  if (raw === "") {
                    handleFilterChange("age_min", undefined)
                    return
                  }
                  const n = Number.parseInt(raw, 10)
                  if (!Number.isFinite(n) || n < 0) return
                  handleFilterChange("age_min", n)
                }}
                className="h-9 border-border/80 bg-background shadow-sm"
              />
            </div>
            <div className="min-w-0 xl:col-span-3">
              <Label htmlFor="age-max" className="sr-only">
                Umur maksimal
              </Label>
              <Input
                id="age-max"
                type="number"
                inputMode="numeric"
                min={0}
                max={150}
                placeholder="Umur maks (tahun)"
                value={params.age_max ?? ""}
                onChange={(e) => {
                  const raw = e.target.value
                  if (raw === "") {
                    handleFilterChange("age_max", undefined)
                    return
                  }
                  const n = Number.parseInt(raw, 10)
                  if (!Number.isFinite(n) || n < 0) return
                  handleFilterChange("age_max", n)
                }}
                className="h-9 border-border/80 bg-background shadow-sm"
              />
            </div>
          </div>
        </div>
      </section>

      {/* Bulk Action Bar */}
      {selectedApplicants.length > 0 && (
        <div className="flex flex-col gap-3 rounded-lg border bg-muted/50 px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex flex-col gap-1 sm:flex-row sm:items-center sm:gap-2">
            <span className="text-sm font-medium">
              {selectedApplicants.length} pelamar dipilih
            </span>
            {canBulkVerify ? (
              <span className="text-muted-foreground text-xs">
                Semua dapat diverifikasi (status Dikirim)
              </span>
            ) : (
              <span className="text-muted-foreground text-xs">
                Hanya pelamar dengan status Dikirim dapat diverifikasi
              </span>
            )}
          </div>
          <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
            <Button
              onClick={handleBulkApprove}
              variant="default"
              size="sm"
              className="cursor-pointer gap-1.5 w-full sm:w-auto"
              disabled={!canBulkVerify}
              title={
                canBulkVerify
                  ? "Terima pelamar yang dipilih"
                  : "Pilih hanya pelamar dengan status Dikirim"
              }
            >
              <IconChecks className="size-4" />
              Terima
            </Button>
            <Button
              onClick={handleBulkReject}
              variant="destructive"
              size="sm"
              className="cursor-pointer gap-1.5 w-full sm:w-auto"
              disabled={!canBulkVerify}
              title={
                canBulkVerify
                  ? "Tolak pelamar yang dipilih"
                  : "Pilih hanya pelamar dengan status Dikirim"
              }
            >
              <IconX className="size-4" />
              Tolak
            </Button>
            <Button
              onClick={handleClearSelection}
              variant="ghost"
              size="sm"
              className="cursor-pointer w-full sm:w-auto"
            >
              Batal
            </Button>
          </div>
        </div>
      )}

      {/* Mobile Card View */}
      {isMobile ? (
        <div className="flex flex-col gap-3">
          {isLoading ? (
            <div className="flex min-h-[12rem] items-center justify-center rounded-xl border border-border/60 bg-muted/10 shadow-sm">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : data?.results && data.results.length > 0 ? (
            data.results.map((applicant) => {
              const isSelected = rowSelection[String(applicant.id)] || false
              const profile = applicant.applicant_profile
              const ageYears = calculateApplicantAgeYears(profile?.birth_date ?? null)
              return (
                <article
                  key={applicant.id}
                  className={cn(
                    "rounded-xl border border-border/60 bg-card p-4 shadow-sm transition-colors",
                    isSelected
                      ? "border-primary/40 bg-primary/[0.04] ring-2 ring-primary/20"
                      : "hover:border-border hover:bg-muted/15"
                  )}
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0 flex-1 space-y-3">
                      <div className="flex items-start gap-2.5">
                        <Checkbox
                          checked={isSelected}
                          onCheckedChange={(value) =>
                            setRowSelection((prev) => ({
                              ...prev,
                              [applicant.id]: !!value,
                            }))
                          }
                          aria-label="Pilih pelamar"
                          className="mt-0.5"
                        />
                        <div className="min-w-0 flex-1">
                          <PelamarIdentityBlock applicant={applicant} />
                        </div>
                      </div>

                      <div className="border-border/50 text-sm leading-relaxed">
                        <span className="text-muted-foreground text-xs font-medium tracking-wide uppercase">
                          Rujukan
                        </span>
                        <div className="mt-0.5 inline-block min-w-0">
                          <RujukanBlock profile={profile} />
                        </div>
                      </div>

                      <div className="grid grid-cols-2 gap-x-3 gap-y-2 border-t border-border/50 pt-3 text-sm">
                        <div>
                          <span className="text-muted-foreground text-xs font-medium">
                            Jenis kelamin
                          </span>
                          <p className="mt-0.5">
                            {profile?.gender === "M" || profile?.gender === "F"
                              ? getGenderLabel(profile.gender)
                              : "—"}
                          </p>
                        </div>
                        <div>
                          <span className="text-muted-foreground text-xs font-medium">
                            Umur
                          </span>
                          <p className="mt-0.5 tabular-nums">
                            {ageYears != null ? ageYears : "—"}
                          </p>
                        </div>
                        <div className="col-span-2 sm:col-span-1">
                          <span className="text-muted-foreground text-xs font-medium">
                            Agama
                          </span>
                          <p className="mt-0.5">
                            {profile?.religion
                              ? getReligionLabel(profile.religion as Religion)
                              : "—"}
                          </p>
                        </div>
                        <div>
                          <span className="text-muted-foreground text-xs font-medium">
                            HP
                          </span>
                          <p className="mt-0.5 tabular-nums">
                            {profile?.contact_phone || "—"}
                          </p>
                        </div>
                        {profile?.score != null && (
                          <div>
                            <span className="text-muted-foreground text-xs font-medium">
                              Skor
                            </span>
                            <p className="mt-0.5 font-medium tabular-nums">
                              {Math.round(profile.score)}
                            </p>
                          </div>
                        )}
                      </div>

                      {profile?.verification_status ? (
                        <div className="flex flex-wrap items-center gap-2 pt-0.5">
                          <VerificationStatusPill
                            status={profile.verification_status}
                          />
                        </div>
                      ) : null}
                    </div>

                    <div className="shrink-0">
                      <Button
                        variant="outline"
                        size="icon"
                        className="size-9 cursor-pointer rounded-lg border-border/80 bg-background/80 shadow-sm hover:bg-muted/60"
                        onClick={() => navigate(`${basePath}/${applicant.id}`)}
                        title="Lihat Detail"
                      >
                        <IconEye className="size-4" />
                        <span className="sr-only">Lihat Detail</span>
                      </Button>
                    </div>
                  </div>
                </article>
              )
            })
          ) : (
            <div className="rounded-xl border border-border/60 border-dashed bg-muted/10 p-10 text-center shadow-sm">
              <p className="text-muted-foreground text-sm">
                Tidak ada data pelamar.
              </p>
            </div>
          )}
        </div>
      ) : (
        /* Desktop Table View */
        <div className="overflow-hidden rounded-xl border border-border/60 bg-card text-card-foreground shadow-sm">
          {isLoading ? (
            <div className="flex min-h-[14rem] items-center justify-center">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : (
            <Table className="border-collapse">
              <TableHeader>
                {table.getHeaderGroups().map((headerGroup) => (
                  <TableRow
                    key={headerGroup.id}
                    className="border-border/60 bg-muted/35 hover:bg-muted/35"
                  >
                    {headerGroup.headers.map((header) => (
                      <TableHead
                        key={header.id}
                        className={applicantTableHeadClass(header.column.id)}
                      >
                        {header.isPlaceholder
                          ? null
                          : flexRender(
                              header.column.columnDef.header,
                              header.getContext()
                            )}
                      </TableHead>
                    ))}
                  </TableRow>
                ))}
              </TableHeader>
              <TableBody>
                {table.getRowModel().rows?.length ? (
                  table.getRowModel().rows.map((row) => (
                    <TableRow
                      key={row.id}
                      data-state={row.getIsSelected() ? "selected" : undefined}
                      className="group border-border/40 transition-colors hover:bg-muted/40 data-[state=selected]:bg-primary/[0.06] data-[state=selected]:hover:bg-primary/[0.08]"
                    >
                      {row.getVisibleCells().map((cell) => (
                        <TableCell
                          key={cell.id}
                          className={applicantTableCellClass(cell.column.id)}
                        >
                          {flexRender(
                            cell.column.columnDef.cell,
                            cell.getContext()
                          )}
                        </TableCell>
                      ))}
                    </TableRow>
                  ))
                ) : (
                  <TableRow className="hover:bg-transparent">
                    <TableCell
                      colSpan={columns.length}
                      className="text-muted-foreground h-28 border-0 px-4 text-center text-sm"
                    >
                      Tidak ada data pelamar.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          )}
        </div>
      )}

      {paginationFooter && (
        <nav
          aria-label="Paginasi daftar pelamar"
          className="rounded-xl border border-border/60 bg-muted/15 px-4 py-3 shadow-sm sm:px-5 dark:bg-muted/10"
        >
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between sm:gap-4">
            <div className="flex flex-col items-center gap-2 sm:flex-row sm:items-center sm:gap-6">
              <p className="text-muted-foreground text-center text-sm tabular-nums sm:text-left">
                Menampilkan{" "}
                <span className="font-medium text-foreground">
                  {paginationFooter.rangeStart}–{paginationFooter.rangeEnd}
                </span>{" "}
                dari{" "}
                <span className="font-medium text-foreground">
                  {paginationFooter.totalCount}
                </span>{" "}
                pelamar
              </p>
              <div className="flex items-center gap-2">
                <Label
                  htmlFor="page-size"
                  className="text-muted-foreground flex shrink-0 items-center gap-1.5 text-xs font-medium whitespace-nowrap sm:text-sm"
                >
                  <IconLayoutRows className="size-3.5 opacity-70" aria-hidden />
                  Per halaman
                </Label>
                <Select
                  value={String(pageSize)}
                  onValueChange={(v) =>
                    handleFilterChange("page_size", Number(v))
                  }
                >
                  <SelectTrigger
                    id="page-size"
                    className="h-9 w-[4.5rem] cursor-pointer border-border/80 bg-background shadow-sm"
                  >
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {PAGE_SIZE_OPTIONS.map((n) => (
                      <SelectItem key={n} value={String(n)}>
                        {n}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="flex items-center justify-center gap-1 sm:justify-end">
              <Button
                type="button"
                variant="outline"
                size="icon"
                className="size-9 shrink-0 cursor-pointer rounded-lg border-border/80 shadow-sm disabled:opacity-40"
                onClick={() => handlePageChange(currentPage - 1)}
                disabled={currentPage <= 1}
                aria-label="Halaman sebelumnya"
                title="Sebelumnya"
              >
                <IconChevronLeft className="size-5" stroke={2} />
              </Button>
              <div className="text-muted-foreground flex min-w-[5.5rem] items-center justify-center gap-1 px-2 text-sm tabular-nums">
                <span className="sr-only">Halaman </span>
                <span className="text-foreground font-semibold tabular-nums">
                  {currentPage}
                </span>
                <span className="text-muted-foreground/80" aria-hidden>
                  /
                </span>
                <span className="tabular-nums">
                  {paginationFooter.totalPages}
                </span>
              </div>
              <Button
                type="button"
                variant="outline"
                size="icon"
                className="size-9 shrink-0 cursor-pointer rounded-lg border-border/80 shadow-sm disabled:opacity-40"
                onClick={() => handlePageChange(currentPage + 1)}
                disabled={currentPage >= paginationFooter.totalPages}
                aria-label="Halaman berikutnya"
                title="Selanjutnya"
              >
                <IconChevronRight className="size-5" stroke={2} />
              </Button>
            </div>
          </div>
        </nav>
      )}

      {/* Verification Modal */}
      <VerificationModal
        open={showVerificationModal}
        onOpenChange={setShowVerificationModal}
        action={verificationAction || "approve"}
        applicants={selectedApplicants}
        onConfirm={handleVerificationConfirm}
        isLoading={bulkApproveMutation.isPending || bulkRejectMutation.isPending}
      />
    </div>
  )
}
