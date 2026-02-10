/**
 * Applicant (Pelamar) table with server-side pagination, search, and filters.
 * Uses TanStack Table for display and TanStack Query for data.
 */

import { useState, useMemo, useCallback } from "react"
import { Link, useNavigate } from "react-router-dom"
import {
  flexRender,
  getCoreRowModel,
  useReactTable,
  type ColumnDef,
} from "@tanstack/react-table"
import {
  IconCircleCheck,
  IconCircleX,
  IconEye,
  IconPlus,
  IconSearch,
  IconUserCheck,
  IconUserOff,
} from "@tabler/icons-react"
import { format } from "date-fns"
import { id } from "date-fns/locale"

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
} from "@/hooks/use-applicants-query"
import { toast } from "@/lib/toast"
import type { ApplicantUser } from "@/types/applicant"
import type { ApplicantsListParams, ApplicantVerificationStatus } from "@/types/applicant"

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100]

const VERIFICATION_LABELS: Record<ApplicantVerificationStatus, string> = {
  DRAFT: "Draf",
  SUBMITTED: "Dikirim",
  ACCEPTED: "Diterima",
  REJECTED: "Ditolak",
}

interface ApplicantTableProps {
  basePath: string
}

export function ApplicantTable({ basePath }: ApplicantTableProps) {
  const navigate = useNavigate()
  const [params, setParams] = useState<ApplicantsListParams>({
    page: 1,
    page_size: 20,
    search: "",
    ordering: "-applicant_profile__created_at",
  })
  const [searchInput, setSearchInput] = useState("")

  const { data, isLoading, isError, error } = useApplicantsQuery(params)
  const deactivateMutation = useDeactivateApplicantMutation()
  const activateMutation = useActivateApplicantMutation()

  const handleSearch = () => {
    setParams((p) => ({
      ...p,
      search: searchInput.trim() || undefined,
      page: 1,
    }))
  }

  const handleFilterChange = <K extends keyof ApplicantsListParams>(
    key: K,
    value: ApplicantsListParams[K]
  ) => {
    setParams((p) => ({ ...p, [key]: value, page: 1 }))
  }

  const handlePageChange = (page: number) => {
    setParams((p) => ({ ...p, page }))
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

  const columns = useMemo<ColumnDef<ApplicantUser>[]>(
    () => [
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
          <span>{row.original.applicant_profile?.nik || "-"}</span>
        ),
      },
      {
        accessorKey: "applicant_profile.verification_status",
        header: "Status Verifikasi",
        cell: ({ row }) => {
          const status = row.original.applicant_profile?.verification_status
          const label = status ? VERIFICATION_LABELS[status] : "-"
          const variant =
            status === "ACCEPTED"
              ? "default"
              : status === "REJECTED"
                ? "destructive"
                : status === "SUBMITTED"
                  ? "secondary"
                  : "outline"
          return <Badge variant={variant}>{label}</Badge>
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
          format(
            new Date(row.original.applicant_profile?.created_at ?? row.original.date_joined),
            "dd MMM yyyy HH:mm",
            { locale: id }
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
    manualPagination: true,
    pageCount: data ? Math.ceil(data.count / (params.page_size ?? 20)) : 0,
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
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex flex-1 flex-col gap-2 sm:flex-row sm:items-center">
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
            className="cursor-pointer"
          >
            Cari
          </Button>
          <div className="flex gap-2">
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
              <SelectTrigger className="w-[140px] cursor-pointer">
                <SelectValue placeholder="Verifikasi" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Semua status</SelectItem>
                {Object.entries(VERIFICATION_LABELS).map(([val, label]) => (
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
              <SelectTrigger className="w-[130px] cursor-pointer">
                <SelectValue placeholder="Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Semua status</SelectItem>
                <SelectItem value="true">Aktif</SelectItem>
                <SelectItem value="false">Nonaktif</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>
        <Button asChild className="cursor-pointer">
          <Link to={`${basePath}/new`} className="cursor-pointer">
            <IconPlus className="mr-2 size-4" />
            Tambah Pelamar
          </Link>
        </Button>
      </div>

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

      {data && data.count > 0 && (
        <div className="flex flex-col items-center justify-between gap-4 sm:flex-row">
          <div className="text-muted-foreground text-sm">
            Menampilkan {(currentPage - 1) * (params.page_size ?? 20) + 1} -{" "}
            {Math.min(
              currentPage * (params.page_size ?? 20),
              data.count
            )}{" "}
            dari {data.count} pelamar
          </div>
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
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
            <div className="flex items-center gap-2">
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
    </div>
  )
}
