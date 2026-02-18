/**
 * Document Review Panel - Grid view of all documents with review controls
 * For use in admin applicant detail page
 */

import { useState, useMemo } from "react"
import { IconFilter, IconCheck, IconX, IconAlertCircle } from "@tabler/icons-react"
import { Badge } from "@/components/ui/badge"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { DocumentReviewCard } from "./document-review-card"
import {
  useApplicantDocumentsQuery,
  useDocumentTypesQuery,
  useUpdateApplicantDocumentMutation,
} from "@/hooks/use-applicants-query"
import { toast } from "@/lib/toast"
import { documentNeedsReview, isDocumentApproved, isDocumentRejected } from "@/lib/type-guards"
import type { ApplicantDocument, DocumentReviewStatus } from "@/types/applicant"

interface DocumentReviewPanelProps {
  applicantId: number
}

type FilterStatus = "all" | "pending" | "approved" | "rejected"

export function DocumentReviewPanel({ applicantId }: DocumentReviewPanelProps) {
  const [filterStatus, setFilterStatus] = useState<FilterStatus>("all")

  const { data: documents = [], isLoading } = useApplicantDocumentsQuery(applicantId)
  const { data: docTypes = [] } = useDocumentTypesQuery()
  const updateMutation = useUpdateApplicantDocumentMutation(applicantId)

  const list = Array.isArray(documents)
    ? documents
    : (documents as { results?: ApplicantDocument[] })?.results ?? []
  const types = Array.isArray(docTypes)
    ? docTypes
    : (docTypes as { results?: import("@/types/applicant").DocumentType[] })?.results ?? []

  // Filter documents by status
  const filteredDocuments = useMemo(() => {
    if (filterStatus === "all") return list
    if (filterStatus === "pending") return list.filter(documentNeedsReview)
    if (filterStatus === "approved") return list.filter(isDocumentApproved)
    if (filterStatus === "rejected") return list.filter(isDocumentRejected)
    return list
  }, [list, filterStatus])

  // Statistics
  const stats = useMemo(() => {
    const pending = list.filter(documentNeedsReview).length
    const approved = list.filter(isDocumentApproved).length
    const rejected = list.filter(isDocumentRejected).length
    return { total: list.length, pending, approved, rejected }
  }, [list])

  const handleApprove = async (documentId: number, notes: string) => {
    try {
      await updateMutation.mutateAsync({
        id: documentId,
        input: {
          review_status: "APPROVED" as DocumentReviewStatus,
          review_notes: notes || undefined,
        },
      })
      toast.success("Dokumen diterima", "Review berhasil diperbarui")
    } catch {
      toast.error("Gagal memproses", "Terjadi kesalahan saat menyimpan review")
    }
  }

  const handleReject = async (documentId: number, notes: string) => {
    try {
      await updateMutation.mutateAsync({
        id: documentId,
        input: {
          review_status: "REJECTED" as DocumentReviewStatus,
          review_notes: notes,
        },
      })
      toast.success("Dokumen ditolak", "Review berhasil diperbarui")
    } catch {
      toast.error("Gagal memproses", "Terjadi kesalahan saat menyimpan review")
    }
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    )
  }

  return (
    <div className="space-y-4">
      {/* Header with stats and filter */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex flex-wrap items-center gap-2">
          <Badge variant="outline" className="gap-1.5">
            Total: <span className="font-semibold">{stats.total}</span>
          </Badge>
          <Badge variant="secondary" className="gap-1.5">
            Menunggu: <span className="font-semibold">{stats.pending}</span>
          </Badge>
          <Badge variant="default" className="gap-1.5">
            <IconCheck className="size-3" />
            {stats.approved}
          </Badge>
          <Badge variant="destructive" className="gap-1.5">
            <IconX className="size-3" />
            {stats.rejected}
          </Badge>
        </div>

        <div className="flex items-center gap-2">
          <IconFilter className="text-muted-foreground size-4" />
          <Select
            value={filterStatus}
            onValueChange={(v) => setFilterStatus(v as FilterStatus)}
          >
            <SelectTrigger className="w-40 cursor-pointer">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">Semua Status</SelectItem>
              <SelectItem value="pending">Menunggu Review</SelectItem>
              <SelectItem value="approved">Diterima</SelectItem>
              <SelectItem value="rejected">Ditolak</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>

      {/* Alert for pending reviews */}
      {stats.pending > 0 && filterStatus === "all" && (
        <Alert>
          <IconAlertCircle className="size-4" />
          <AlertDescription>
            {stats.pending} dokumen menunggu review Anda
          </AlertDescription>
        </Alert>
      )}

      {/* Documents Grid */}
      {filteredDocuments.length === 0 ? (
        <div className="rounded-lg border border-dashed p-12 text-center">
          <p className="text-muted-foreground">
            {filterStatus === "all"
              ? "Belum ada dokumen yang diunggah"
              : `Tidak ada dokumen dengan status "${filterStatus}"`}
          </p>
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {filteredDocuments.map((doc) => {
            const docType = types.find((t) => t.id === doc.document_type)
            return (
              <DocumentReviewCard
                key={doc.id}
                document={doc}
                documentType={docType || null}
                onApprove={(notes) => handleApprove(doc.id, notes)}
                onReject={(notes) => handleReject(doc.id, notes)}
                isLoading={updateMutation.isPending}
              />
            )
          })}
        </div>
      )}
    </div>
  )
}
