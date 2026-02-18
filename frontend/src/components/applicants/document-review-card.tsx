/**
 * Document Review Card - Enhanced UI for admin to review applicant documents
 * Features: Image/PDF preview, approve/reject, review notes, file info
 */

import { useState } from "react"
import { IconCheck, IconX, IconEye, IconDownload, IconFile } from "@tabler/icons-react"
import { Card, CardContent, CardFooter, CardHeader } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Textarea } from "@/components/ui/textarea"
import { Label } from "@/components/ui/label"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { formatDate } from "@/lib/formatters"
import { isImageDocument, isPDFDocument, isDocumentApproved, isDocumentRejected } from "@/lib/type-guards"
import type { ApplicantDocument, DocumentType } from "@/types/applicant"
import { env } from "@/lib/env"

interface DocumentReviewCardProps {
  document: ApplicantDocument
  documentType: DocumentType | null
  onApprove: (notes: string) => Promise<void>
  onReject: (notes: string) => Promise<void>
  isLoading?: boolean
}

function getFileUrl(filePath: string): string {
  if (!filePath) return ""
  if (filePath.startsWith("http")) return filePath
  const base = (env.VITE_API_URL || "").replace(/\/$/, "")
  const path = filePath.startsWith("/") ? filePath : `/${filePath}`
  return `${base}${path}`
}

export function DocumentReviewCard({
  document,
  documentType,
  onApprove,
  onReject,
  isLoading = false,
}: DocumentReviewCardProps) {
  const [showPreview, setShowPreview] = useState(false)
  const [showReviewForm, setShowReviewForm] = useState(false)
  const [reviewAction, setReviewAction] = useState<"approve" | "reject" | null>(null)
  const [notes, setNotes] = useState("")
  const [error, setError] = useState("")

  const fileUrl = getFileUrl(document.file)
  const isImage = isImageDocument(document)
  const isPDF = isPDFDocument(document)
  const isApproved = isDocumentApproved(document)
  const isRejected = isDocumentRejected(document)

  const handleApproveClick = () => {
    setReviewAction("approve")
    setNotes("")
    setError("")
    setShowReviewForm(true)
  }

  const handleRejectClick = () => {
    setReviewAction("reject")
    setNotes(document.review_notes || "")
    setError("")
    setShowReviewForm(true)
  }

  const handleSubmitReview = async () => {
    setError("")

    // Validate notes for rejection
    if (reviewAction === "reject" && !notes.trim()) {
      setError("Catatan wajib diisi untuk penolakan")
      return
    }

    try {
      if (reviewAction === "approve") {
        await onApprove(notes.trim())
      } else if (reviewAction === "reject") {
        await onReject(notes.trim())
      }
      setShowReviewForm(false)
      setNotes("")
    } catch (err) {
      setError("Gagal memproses review")
    }
  }

  const getStatusBadge = () => {
    if (isApproved) {
      return (
        <Badge variant="default" className="gap-1">
          <IconCheck className="size-3" />
          Diterima
        </Badge>
      )
    }
    if (isRejected) {
      return (
        <Badge variant="destructive" className="gap-1">
          <IconX className="size-3" />
          Ditolak
        </Badge>
      )
    }
    return (
      <Badge variant="secondary" className="gap-1">
        Menunggu Review
      </Badge>
    )
  }

  return (
    <>
      <Card className={isRejected ? "border-destructive/50" : isApproved ? "border-green-500/50" : ""}>
        <CardHeader className="pb-3">
          <div className="flex items-start justify-between gap-3">
            <div className="flex-1 space-y-1">
              <h4 className="text-sm font-semibold">
                {documentType?.name || "Dokumen"}
              </h4>
              {documentType?.description && (
                <p className="text-muted-foreground text-xs">
                  {documentType.description}
                </p>
              )}
            </div>
            {getStatusBadge()}
          </div>
        </CardHeader>

        <CardContent className="space-y-3">
          {/* File Preview Thumbnail */}
          <div className="relative aspect-video overflow-hidden rounded-lg border bg-muted">
            {isImage && fileUrl ? (
              <img
                src={fileUrl}
                alt={documentType?.name || "Document"}
                className="h-full w-full object-contain cursor-pointer hover:opacity-90 transition"
                onClick={() => setShowPreview(true)}
              />
            ) : isPDF ? (
              <div className="flex h-full w-full flex-col items-center justify-center gap-2 text-muted-foreground">
                <IconFile className="size-12" />
                <span className="text-sm">File PDF</span>
              </div>
            ) : (
              <div className="flex h-full w-full flex-col items-center justify-center gap-2 text-muted-foreground">
                <IconFile className="size-12" />
                <span className="text-sm">Tidak ada preview</span>
              </div>
            )}
          </div>

          {/* File Info */}
          <div className="space-y-1 text-xs text-muted-foreground">
            <div className="flex items-center justify-between">
              <span>Diunggah:</span>
              <span className="font-medium">{formatDate(document.uploaded_at)}</span>
            </div>
            {document.reviewed_at && (
              <div className="flex items-center justify-between">
                <span>Direview:</span>
                <span className="font-medium">{formatDate(document.reviewed_at)}</span>
              </div>
            )}
          </div>

          {/* Review Notes */}
          {document.review_notes && (
            <div className="rounded-lg bg-muted p-3 space-y-1">
              <p className="text-xs font-medium">Catatan Review:</p>
              <p className="text-sm">{document.review_notes}</p>
            </div>
          )}
        </CardContent>

        <CardFooter className="flex gap-2 pt-3">
          {fileUrl && (
            <>
              <Button
                variant="outline"
                size="sm"
                className="flex-1 cursor-pointer gap-1.5"
                onClick={() => setShowPreview(true)}
              >
                <IconEye className="size-4" />
                Lihat
              </Button>
              <Button
                variant="outline"
                size="sm"
                className="cursor-pointer"
                asChild
              >
                <a href={fileUrl} download target="_blank" rel="noopener noreferrer">
                  <IconDownload className="size-4" />
                </a>
              </Button>
            </>
          )}
          
          {!isApproved && !isRejected && (
            <>
              <Button
                variant="default"
                size="sm"
                className="flex-1 cursor-pointer gap-1.5"
                onClick={handleApproveClick}
                disabled={isLoading}
              >
                <IconCheck className="size-4" />
                Terima
              </Button>
              <Button
                variant="destructive"
                size="sm"
                className="flex-1 cursor-pointer gap-1.5"
                onClick={handleRejectClick}
                disabled={isLoading}
              >
                <IconX className="size-4" />
                Tolak
              </Button>
            </>
          )}

          {(isApproved || isRejected) && (
            <Button
              variant="outline"
              size="sm"
              className="flex-1 cursor-pointer"
              onClick={() => setShowReviewForm(true)}
              disabled={isLoading}
            >
              Ubah Review
            </Button>
          )}
        </CardFooter>
      </Card>

      {/* Preview Dialog */}
      <Dialog open={showPreview} onOpenChange={setShowPreview}>
        <DialogContent className="max-w-4xl max-h-[90vh]">
          <DialogHeader>
            <DialogTitle>{documentType?.name || "Preview Dokumen"}</DialogTitle>
          </DialogHeader>
          <div className="overflow-auto">
            {isImage && fileUrl && (
              <img
                src={fileUrl}
                alt={documentType?.name || "Document"}
                className="w-full"
              />
            )}
            {isPDF && fileUrl && (
              <iframe
                src={fileUrl}
                className="h-[70vh] w-full"
                title="PDF Preview"
              />
            )}
          </div>
        </DialogContent>
      </Dialog>

      {/* Review Form Dialog */}
      <Dialog open={showReviewForm} onOpenChange={setShowReviewForm}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {reviewAction === "approve" ? "Terima Dokumen" : "Tolak Dokumen"}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="review-notes">
                Catatan {reviewAction === "reject" && <span className="text-destructive">*</span>}
              </Label>
              <Textarea
                id="review-notes"
                placeholder={
                  reviewAction === "approve"
                    ? "Tambahkan catatan (opsional)"
                    : "Jelaskan alasan penolakan"
                }
                value={notes}
                onChange={(e) => {
                  setNotes(e.target.value)
                  if (error) setError("")
                }}
                rows={4}
                className={error ? "border-destructive" : ""}
              />
              {error && <p className="text-destructive text-sm">{error}</p>}
            </div>
          </div>
          <div className="flex justify-end gap-2">
            <Button
              variant="outline"
              onClick={() => setShowReviewForm(false)}
              disabled={isLoading}
              className="cursor-pointer"
            >
              Batal
            </Button>
            <Button
              variant={reviewAction === "approve" ? "default" : "destructive"}
              onClick={handleSubmitReview}
              disabled={isLoading}
              className="cursor-pointer gap-2"
            >
              {isLoading ? (
                <>
                  <div className="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
                  Memproses...
                </>
              ) : (
                <>
                  {reviewAction === "approve" ? (
                    <IconCheck className="size-4" />
                  ) : (
                    <IconX className="size-4" />
                  )}
                  {reviewAction === "approve" ? "Terima" : "Tolak"}
                </>
              )}
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </>
  )
}
