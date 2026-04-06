/**
 * Admin — Batch List page.
 * Lists all LamaranBatch records. Each row links to the batch detail page
 * where admin can assign applicants, set schedule, and run bulk transitions.
 */

import { useState } from "react"
import { useNavigate } from "react-router-dom"
import { useQuery } from "@tanstack/react-query"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import {
  IconClipboardList,
  IconEye,
  IconPlus,
  IconSearch,
} from "@tabler/icons-react"

import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { usePageTitle } from "@/hooks/use-page-title"
import { getBatches } from "@/api/batches"
import type { BatchListParams } from "@/types/lamaran-batch"
import { CreateBatchDialog } from "@/components/batches/create-batch-dialog"
import { joinAdminPath, useAdminDashboard } from "@/contexts/admin-dashboard-context"

function formatDate(value: string | null | undefined) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy HH:mm", { locale: idLocale })
}

export function AdminBatchListPage() {
  const { basePath } = useAdminDashboard()
  const batchBase = joinAdminPath(basePath, "/batch")

  usePageTitle("Kelola Batch Lamaran")
  const navigate = useNavigate()
  const [params, setParams] = useState<BatchListParams>({
    page: 1,
    page_size: 20,
  })
  const [searchInput, setSearchInput] = useState("")
  const [createOpen, setCreateOpen] = useState(false)

  const { data, isLoading, isError } = useQuery({
    queryKey: ["batches", params],
    queryFn: () => getBatches(params),
  })

  const handleSearch = () => {
    setParams((p) => ({ ...p, search: searchInput.trim() || undefined, page: 1 }))
  }

  const pageCount = data ? Math.ceil(data.count / (params.page_size ?? 20)) : 0
  const currentPage = params.page ?? 1

  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: basePath || "/" },
          { label: "Batch Lamaran" },
        ]}
      />
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div>
          <h1 className="text-2xl font-bold">Batch Lamaran</h1>
          <p className="text-muted-foreground text-sm mt-1">
            Kelola penugasan kelompok pelamar ke lowongan kerja
          </p>
        </div>
        <Button className="cursor-pointer" onClick={() => setCreateOpen(true)}>
          <IconPlus className="mr-2 size-4" />
          Buat Batch Baru
        </Button>
      </div>

      {/* Search */}
      <div className="flex gap-2">
        <div className="relative flex-1 max-w-sm">
          <IconSearch className="text-muted-foreground absolute left-3 top-1/2 size-4 -translate-y-1/2" />
          <Input
            placeholder="Cari nama batch atau lowongan..."
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && handleSearch()}
            className="pl-9"
          />
        </div>
        <Button onClick={handleSearch} variant="secondary" className="cursor-pointer">
          Cari
        </Button>
      </div>

      {/* Table */}
      <div className="overflow-hidden rounded-lg border">
        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          </div>
        ) : isError ? (
          <div className="p-6 text-center text-destructive">
            Gagal memuat data batch.
          </div>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Nama Batch</TableHead>
                <TableHead>Lowongan</TableHead>
                <TableHead>Pra-Seleksi</TableHead>
                <TableHead>Interview</TableHead>
                <TableHead className="text-center">Pelamar</TableHead>
                <TableHead>Dibuat</TableHead>
                <TableHead />
              </TableRow>
            </TableHeader>
            <TableBody>
              {data?.results.length ? (
                data.results.map((batch) => (
                  <TableRow
                    key={batch.id}
                    className="cursor-pointer hover:bg-muted/50"
                    onClick={() => navigate(`${batchBase}/${batch.id}`)}
                  >
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <IconClipboardList className="size-4 text-muted-foreground shrink-0" />
                        <span className="font-medium">{batch.name}</span>
                      </div>
                    </TableCell>
                    <TableCell>{batch.job_title}</TableCell>
                    <TableCell>{formatDate(batch.pra_seleksi_date)}</TableCell>
                    <TableCell>{formatDate(batch.interview_date)}</TableCell>
                    <TableCell className="text-center">{batch.applicant_count}</TableCell>
                    <TableCell className="text-muted-foreground text-sm">
                      {formatDate(batch.created_at)}
                    </TableCell>
                    <TableCell onClick={(e) => e.stopPropagation()}>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="size-8 cursor-pointer"
                        onClick={() => navigate(`${batchBase}/${batch.id}`)}
                        title="Lihat detail batch"
                      >
                        <IconEye className="size-4" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell colSpan={7} className="h-24 text-center">
                    Belum ada batch. Buat batch baru untuk mulai menugaskan pelamar.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        )}
      </div>

      {/* Pagination */}
      {data && data.count > 0 && (
        <div className="flex items-center justify-between gap-4">
          <p className="text-muted-foreground text-sm">
            {data.count} batch ditemukan
          </p>
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              className="cursor-pointer"
              onClick={() => setParams((p) => ({ ...p, page: currentPage - 1 }))}
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
              onClick={() => setParams((p) => ({ ...p, page: currentPage + 1 }))}
              disabled={currentPage >= pageCount}
            >
              Selanjutnya
            </Button>
          </div>
        </div>
      )}

      <CreateBatchDialog
        open={createOpen}
        onOpenChange={setCreateOpen}
        onSuccess={(batch) => {
          setCreateOpen(false)
          navigate(`${batchBase}/${batch.id}`)
        }}
      />
    </div>
  )
}
