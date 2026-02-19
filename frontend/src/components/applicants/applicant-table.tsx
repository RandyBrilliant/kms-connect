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
  IconCircleCheck,
  IconCircleX,
  IconEye,
  IconPlus,
  IconSearch,
  IconUserCheck,
  IconUserOff,
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
import { Badge } from "@/components/ui/badge"
import {
  useApplicantsQuery,
  useDeactivateApplicantMutation,
  useActivateApplicantMutation,
  useBulkApproveApplicantsMutation,
  useBulkRejectApplicantsMutation,
} from "@/hooks/use-applicants-query"
import { toast } from "@/lib/toast"
import { 
  VERIFICATION_STATUS_LABELS,
  VERIFICATION_STATUS_COLORS,
  getVerificationStatusLabel,
} from "@/constants/applicant"
import { formatDate, formatNIK } from "@/lib/formatters"
import { isSubmittedStatus } from "@/lib/type-guards"
import { VerificationModal } from "./verification-modal"
import { exportApplicants } from "@/api/applicants"
import { DateRangePicker } from "@/components/ui/date-range-picker"
import { type DateRange } from "react-day-picker"
import { format } from "date-fns"
import type { ApplicantUser } from "@/types/applicant"
import type { ApplicantsListParams, ApplicantVerificationStatus } from "@/types/applicant"

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100]

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
    ordering: "-applicant_profile__created_at",
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
  const deactivateMutation = useDeactivateApplicantMutation()
  const activateMutation = useActivateApplicantMutation()
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

  const handleSearch = () => {
    setParams((p) => ({
      ...p,
      search: searchInput.trim() || undefined,
      page: 1,
    }))
    setRowSelection({}) // Clear selection on search
  }

  const handleFilterChange = <K extends keyof ApplicantsListParams>(
    key: K,
    value: ApplicantsListParams[K]
  ) => {
    setParams((p) => ({ ...p, [key]: value, page: 1 }))
    setRowSelection({}) // Clear selection on filter change
  }

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

  const handleSortChange = useCallback((value: string) => {
    setParams((p) => ({ ...p, ordering: value === "default" ? undefined : value, page: 1 }))
    setRowSelection({}) // Clear selection on sort change
  }, [])

  const handlePageChange = (page: number) => {
    setParams((p) => ({ ...p, page }))
    setRowSelection({}) // Clear selection on page change
  }

  const handleActivate = useCallback(
    async (applicant: ApplicantUser) => {
      try {
        await activateMutation.mutateAsync(applicant.id)
        toast.success("Pelamar diaktifkan", "Akun berhasil diaktifkan kembali")
      } catch {
        toast.error("Gagal mengaktifkan", "Coba lagi nanti")
      }
    },
    [activateMutation]
  )

  const handleDeactivate = useCallback(
    async (applicant: ApplicantUser) => {
      try {
        await deactivateMutation.mutateAsync(applicant.id)
        toast.success("Pelamar dinonaktifkan", "Akun berhasil dinonaktifkan")
      } catch {
        toast.error("Gagal menonaktifkan", "Coba lagi nanti")
      }
    },
    [deactivateMutation]
  )

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
        is_active: params.is_active,
        email_verified: params.email_verified,
        verification_status: params.verification_status,
        created_at_after: params.created_at_after,
        created_at_before: params.created_at_before,
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
        accessorKey: "applicant_profile.full_name",
        header: "Nama",
        cell: ({ row }) => (
          <span className="font-medium">
            {row.original.applicant_profile?.full_name || "-"}
          </span>
        ),
      },
      {
        accessorKey: "email",
        header: "Email",
        cell: ({ row }) => <span>{row.original.email}</span>,
      },
      {
        accessorKey: "applicant_profile.nik",
        header: "NIK",
        cell: ({ row }) => (
          <span>{formatNIK(row.original.applicant_profile?.nik)}</span>
        ),
      },
      {
        accessorKey: "applicant_profile.score",
        header: "Skor",
        cell: ({ row }) => {
          const score = row.original.applicant_profile?.score
          if (score == null) {
            return <span className="text-muted-foreground">-</span>
          }
          return <span>{Math.round(score)}</span>
        },
      },
      {
        accessorKey: "applicant_profile.verification_status",
        header: "Status Verifikasi",
        cell: ({ row }) => {
          const status = row.original.applicant_profile?.verification_status
          if (!status) return <span className="text-muted-foreground">-</span>
          const color = VERIFICATION_STATUS_COLORS[status]
          return (
            <Badge variant={color}>
              {getVerificationStatusLabel(status)}
            </Badge>
          )
        },
      },
      {
        accessorKey: "is_active",
        header: "Status",
        cell: ({ row }) =>
          row.original.is_active ? (
            <Badge variant="default" className="gap-1">
              <IconCircleCheck className="size-3" />
              Aktif
            </Badge>
          ) : (
            <Badge variant="secondary" className="gap-1">
              <IconCircleX className="size-3" />
              Nonaktif
            </Badge>
          ),
      },
      {
        accessorKey: "applicant_profile.created_at",
        header: "Bergabung",
        cell: ({ row }) =>
          formatDate(
            row.original.applicant_profile?.created_at ?? row.original.date_joined
          ),
      },
      {
        id: "actions",
        header: "",
        cell: ({ row }) => {
          const applicant = row.original
          return (
            <div className="flex items-center gap-1">
              <Button
                variant="ghost"
                size="icon"
                className="size-8 cursor-pointer"
                onClick={() => navigate(`${basePath}/${applicant.id}`)}
                title="Lihat Detail"
              >
                <IconEye className="size-4" />
                <span className="sr-only">Lihat Detail</span>
              </Button>
              {applicant.is_active ? (
                <Button
                  variant="ghost"
                  size="icon"
                  className="size-8 cursor-pointer text-destructive hover:text-destructive"
                  onClick={() => handleDeactivate(applicant)}
                  title="Nonaktifkan"
                >
                  <IconUserOff className="size-4" />
                  <span className="sr-only">Nonaktifkan</span>
                </Button>
              ) : (
                <Button
                  variant="ghost"
                  size="icon"
                  className="size-8 cursor-pointer"
                  onClick={() => handleActivate(applicant)}
                  title="Aktifkan"
                >
                  <IconUserCheck className="size-4" />
                  <span className="sr-only">Aktifkan</span>
                </Button>
              )}
            </div>
          )
        },
      },
    ],
    [basePath, navigate, handleActivate, handleDeactivate]
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
      {/* Search and Filters */}
      <div className="flex flex-col gap-3">
        {/* Search Bar */}
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
          <div className="relative flex-1">
            <IconSearch className="text-muted-foreground absolute left-3 top-1/2 size-4 -translate-y-1/2" />
            <Input
              placeholder="Cari nama, email, NIK..."
              value={searchInput}
              onChange={(e) => setSearchInput(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && handleSearch()}
              className="pl-9"
            />
          </div>
          <Button
            onClick={handleSearch}
            variant="secondary"
            className="cursor-pointer w-full sm:w-auto"
          >
            Cari
          </Button>
        </div>

        {/* Filters Row */}
        <div className="flex flex-wrap items-center gap-2">
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
            <SelectTrigger className="w-full sm:w-[140px] cursor-pointer">
              <SelectValue placeholder="Verifikasi" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">Semua status</SelectItem>
              {Object.entries(VERIFICATION_STATUS_LABELS).map(([val, label]) => (
                <SelectItem key={val} value={val}>
                  {label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Select
            value={
              params.is_active === undefined
                ? "all"
                : String(params.is_active)
            }
            onValueChange={(v) =>
              handleFilterChange(
                "is_active",
                v === "all" ? undefined : v === "true"
              )
            }
          >
            <SelectTrigger className="w-full sm:w-[130px] cursor-pointer">
              <SelectValue placeholder="Status" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">Semua status</SelectItem>
              <SelectItem value="true">Aktif</SelectItem>
              <SelectItem value="false">Nonaktif</SelectItem>
            </SelectContent>
          </Select>
          <DateRangePicker
            dateRange={dateRange}
            onDateRangeChange={handleDateRangeChange}
            placeholder="Rentang tanggal bergabung"
            fromYear={2020}
            toYear={new Date().getFullYear()}
            numberOfMonths={isMobile ? 1 : 2}
          />
          <Select
            value={params.ordering || "default"}
            onValueChange={handleSortChange}
          >
            <SelectTrigger className="w-full sm:w-[160px] cursor-pointer">
              <SelectValue placeholder="Urutkan" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="default">Default (Terbaru)</SelectItem>
              <SelectItem value="applicant_profile__score">Skor: Rendah ke Tinggi</SelectItem>
              <SelectItem value="-applicant_profile__score">Skor: Tinggi ke Rendah</SelectItem>
              <SelectItem value="applicant_profile__created_at">Bergabung: Lama ke Baru</SelectItem>
              <SelectItem value="-applicant_profile__created_at">Bergabung: Baru ke Lama</SelectItem>
              <SelectItem value="applicant_profile__user__full_name">Nama: A-Z</SelectItem>
              <SelectItem value="-applicant_profile__user__full_name">Nama: Z-A</SelectItem>
            </SelectContent>
          </Select>
        </div>

        {/* Action Buttons */}
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-end">
          <Button
            onClick={handleExport}
            variant="outline"
            className="cursor-pointer w-full sm:w-auto"
            disabled={isExporting}
          >
            {isExporting ? (
              <>
                <div className="mr-2 size-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
                Mengekspor...
              </>
            ) : (
              <>
                <IconDownload className="mr-2 size-4" />
                {isMobile ? "Ekspor" : "Ekspor Excel"}
              </>
            )}
          </Button>
          <Button asChild className="cursor-pointer w-full sm:w-auto">
            <Link to={`${basePath}/new`} className="cursor-pointer">
              <IconPlus className="mr-2 size-4" />
              {isMobile ? "Tambah" : "Tambah Pelamar"}
            </Link>
          </Button>
        </div>
      </div>

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
            <div className="flex items-center justify-center py-12">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : data?.results && data.results.length > 0 ? (
            data.results.map((applicant) => {
              const isSelected = rowSelection[String(applicant.id)] || false
              const profile = applicant.applicant_profile
              return (
                <div
                  key={applicant.id}
                  className={`rounded-lg border p-4 ${
                    isSelected ? "border-primary bg-primary/5" : ""
                  }`}
                >
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex-1 space-y-2">
                      <div className="flex items-start gap-2">
                        <Checkbox
                          checked={isSelected}
                          onCheckedChange={(value) =>
                            setRowSelection((prev) => ({
                              ...prev,
                              [applicant.id]: !!value,
                            }))
                          }
                          aria-label="Pilih pelamar"
                          className="mt-1"
                        />
                        <div className="flex-1">
                          <h3 className="font-semibold text-base">
                            {profile?.full_name || "-"}
                          </h3>
                          <p className="text-muted-foreground text-sm">
                            {applicant.email}
                          </p>
                        </div>
                      </div>

                      <div className="grid grid-cols-2 gap-2 text-sm">
                        <div>
                          <span className="text-muted-foreground">NIK:</span>{" "}
                          <span>{formatNIK(profile?.nik)}</span>
                        </div>
                        <div>
                          <span className="text-muted-foreground">HP:</span>{" "}
                          <span>{profile?.contact_phone || "-"}</span>
                        </div>
                        {profile?.score != null && (
                          <div>
                            <span className="text-muted-foreground">Skor:</span>{" "}
                            <span>{Math.round(profile.score)}</span>
                          </div>
                        )}
                        <div>
                          <span className="text-muted-foreground">Bergabung:</span>{" "}
                          <span className="text-xs">
                            {formatDate(
                              profile?.created_at ?? applicant.date_joined
                            )}
                          </span>
                        </div>
                      </div>

                      <div className="flex flex-wrap items-center gap-2">
                        {profile?.verification_status && (
                          <Badge
                            variant={
                              VERIFICATION_STATUS_COLORS[
                                profile.verification_status
                              ]
                            }
                          >
                            {getVerificationStatusLabel(profile.verification_status)}
                          </Badge>
                        )}
                        {applicant.is_active ? (
                          <Badge variant="default" className="gap-1">
                            <IconCircleCheck className="size-3" />
                            Aktif
                          </Badge>
                        ) : (
                          <Badge variant="secondary" className="gap-1">
                            <IconCircleX className="size-3" />
                            Nonaktif
                          </Badge>
                        )}
                      </div>
                    </div>

                    <div className="flex flex-col gap-1">
                      <Button
                        variant="ghost"
                        size="icon"
                        className="size-8 cursor-pointer"
                        onClick={() => navigate(`${basePath}/${applicant.id}`)}
                        title="Lihat Detail"
                      >
                        <IconEye className="size-4" />
                        <span className="sr-only">Lihat Detail</span>
                      </Button>
                      {applicant.is_active ? (
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-8 cursor-pointer text-destructive hover:text-destructive"
                          onClick={() => handleDeactivate(applicant)}
                          title="Nonaktifkan"
                        >
                          <IconUserOff className="size-4" />
                          <span className="sr-only">Nonaktifkan</span>
                        </Button>
                      ) : (
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-8 cursor-pointer"
                          onClick={() => handleActivate(applicant)}
                          title="Aktifkan"
                        >
                          <IconUserCheck className="size-4" />
                          <span className="sr-only">Aktifkan</span>
                        </Button>
                      )}
                    </div>
                  </div>
                </div>
              )
            })
          ) : (
            <div className="rounded-lg border p-8 text-center">
              <p className="text-muted-foreground">Tidak ada data pelamar.</p>
            </div>
          )}
        </div>
      ) : (
        /* Desktop Table View */
        <div className="overflow-hidden rounded-lg border">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : (
            <Table>
              <TableHeader>
                {table.getHeaderGroups().map((headerGroup) => (
                  <TableRow key={headerGroup.id}>
                    {headerGroup.headers.map((header) => (
                      <TableHead key={header.id}>
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
                    <TableRow key={row.id}>
                      {row.getVisibleCells().map((cell) => (
                        <TableCell key={cell.id}>
                          {flexRender(
                            cell.column.columnDef.cell,
                            cell.getContext()
                          )}
                        </TableCell>
                      ))}
                    </TableRow>
                  ))
                ) : (
                  <TableRow>
                    <TableCell
                      colSpan={columns.length}
                      className="h-24 text-center"
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

      {data && data.count > 0 && (
        <div className="flex flex-col gap-4">
          <div className="text-muted-foreground text-center text-sm sm:text-left">
            Menampilkan {(currentPage - 1) * (params.page_size ?? 20) + 1} -{" "}
            {Math.min(
              currentPage * (params.page_size ?? 20),
              data.count
            )}{" "}
            dari {data.count} pelamar
          </div>
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-center justify-center gap-2 sm:justify-start">
              <Label htmlFor="page-size" className="text-sm">
                Per halaman
              </Label>
              <Select
                value={String(params.page_size ?? 20)}
                onValueChange={(v) =>
                  handleFilterChange("page_size", Number(v))
                }
              >
                <SelectTrigger id="page-size" className="w-20 cursor-pointer">
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
            <div className="flex items-center justify-center gap-2">
              <Button
                variant="outline"
                size="sm"
                className="cursor-pointer"
                onClick={() => handlePageChange(currentPage - 1)}
                disabled={currentPage <= 1}
              >
                Sebelumnya
              </Button>
              <span className="text-sm">
                Halaman {currentPage} dari {pageCount || 1}
              </span>
              <Button
                variant="outline"
                size="sm"
                className="cursor-pointer"
                onClick={() => handlePageChange(currentPage + 1)}
                disabled={currentPage >= pageCount}
              >
                Selanjutnya
              </Button>
            </div>
          </div>
        </div>
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
