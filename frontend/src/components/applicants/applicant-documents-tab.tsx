/**
 * Dokumen tab - CRUD ApplicantDocument (upload, delete, review).
 */

import { useRef, useState } from "react"
import { IconPlus, IconTrash, IconFileUpload, IconPencil } from "@tabler/icons-react"
import { format } from "date-fns"
import { id } from "date-fns/locale"

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { cn } from "@/lib/utils"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  useApplicantDocumentsQuery,
  useCreateApplicantDocumentMutation,
  useUpdateApplicantDocumentMutation,
  useDeleteApplicantDocumentMutation,
  useDocumentTypesQuery,
} from "@/hooks/use-applicants-query"
import { toast } from "@/lib/toast"
import type { ApplicantDocument, DocumentType, DocumentReviewStatus } from "@/types/applicant"
import { env } from "@/lib/env"

interface ApplicantDocumentsTabProps {
  applicantId: number
}

const REVIEW_STATUS_LABELS: Record<DocumentReviewStatus, string> = {
  PENDING: "Menunggu Review",
  APPROVED: "Diterima",
  REJECTED: "Ditolak",
}

function getFileUrl(filePath: string): string {
  if (!filePath) return ""
  if (filePath.startsWith("http")) return filePath
  const base = (env.VITE_API_URL || "").replace(/\/$/, "")
  const path = filePath.startsWith("/") ? filePath : `/${filePath}`
  return `${base}${path}`
}

export function ApplicantDocumentsTab({
  applicantId,
}: ApplicantDocumentsTabProps) {
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [uploadDialogOpen, setUploadDialogOpen] = useState(false)
  const [editDialogOpen, setEditDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [editingDoc, setEditingDoc] = useState<ApplicantDocument | null>(null)
  const [deletingDoc, setDeletingDoc] = useState<ApplicantDocument | null>(null)
  const [selectedTypeId, setSelectedTypeId] = useState<string>("")
  const [fileError, setFileError] = useState<string>("")
  const [selectedFileName, setSelectedFileName] = useState<string>("")
  const [reviewStatus, setReviewStatus] = useState<DocumentReviewStatus>("PENDING")
  const [reviewNotes, setReviewNotes] = useState<string>("")
  const [reviewError, setReviewError] = useState<string>("")

  const { data: documents = [], isLoading } = useApplicantDocumentsQuery(applicantId)
  const { data: docTypes = [] } = useDocumentTypesQuery()
  const createMutation = useCreateApplicantDocumentMutation(applicantId)
  const updateMutation = useUpdateApplicantDocumentMutation(applicantId)
  const deleteMutation = useDeleteApplicantDocumentMutation(applicantId)

  const list = Array.isArray(documents)
    ? documents
    : (documents as { results?: ApplicantDocument[] })?.results ?? []
  const types = Array.isArray(docTypes)
    ? docTypes
    : (docTypes as { results?: DocumentType[] })?.results ?? []

  const uploadedTypeIds = new Set(list.map((d) => d.document_type))
  const availableTypes = types.filter((t) => !uploadedTypeIds.has(t.id))

  const selectedType = selectedTypeId
    ? types.find((t) => String(t.id) === selectedTypeId) ?? null
    : null

  const handleUpload = async (e: React.FormEvent) => {
    e.preventDefault()
    setFileError("")

    const typeId = selectedTypeId ? Number(selectedTypeId) : null
    const file = fileInputRef.current?.files?.[0]

    if (!typeId) {
      toast.error("Pilih tipe dokumen")
      return
    }
    if (!file) {
      setFileError("Pilih file untuk diunggah")
      return
    }

    // Validate file type and size
    const fileType = file.type.toLowerCase()
    const fileName = file.name.toLowerCase()
    const fileSize = file.size
    
    const isPDF = fileType === "application/pdf" || fileName.endsWith(".pdf")
    const isJPG = fileType === "image/jpeg" || fileName.endsWith(".jpg") || fileName.endsWith(".jpeg")
    
    // Only allow PDF and JPG files
    if (!isPDF && !isJPG) {
      setFileError("Hanya file PDF atau JPG yang diperbolehkan")
      return
    }
    
    // Validate file size: PDF max 2MB, JPG max 500KB
    const maxSize = isPDF ? 2 * 1024 * 1024 : 500 * 1024  // 2MB for PDF, 500KB for JPG
    const maxSizeLabel = isPDF ? "2MB" : "500KB"
    const fileTypeLabel = isPDF ? "PDF" : "JPG"
    
    if (fileSize > maxSize) {
      setFileError(`Ukuran file ${fileTypeLabel} maksimal ${maxSizeLabel}. File Anda: ${(fileSize / 1024 / 1024).toFixed(2)}MB`)
      return
    }

    const formData = new FormData()
    formData.append("document_type", String(typeId))
    formData.append("file", file)

    try {
      await createMutation.mutateAsync(formData)
      toast.success("Dokumen berhasil diunggah")
      setUploadDialogOpen(false)
      setSelectedTypeId("")
      if (fileInputRef.current) {
        fileInputRef.current.value = ""
      }
      setSelectedFileName("")
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error("Gagal mengunggah", res?.response?.data?.detail ?? "Coba lagi nanti")
    }
  }

  const openEdit = (doc: ApplicantDocument) => {
    setEditingDoc(doc)
    setReviewStatus(doc.review_status)
    setReviewNotes(doc.review_notes || "")
    setReviewError("")
    setEditDialogOpen(true)
  }

  const handleReviewSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setReviewError("")

    if (!editingDoc) return

    // Validate: review_notes required when REJECTED
    if (reviewStatus === "REJECTED" && !reviewNotes.trim()) {
      setReviewError("Catatan review wajib diisi ketika status ditolak")
      return
    }

    try {
      await updateMutation.mutateAsync({
        id: editingDoc.id,
        input: {
          review_status: reviewStatus,
          review_notes: reviewStatus === "APPROVED" ? "" : reviewNotes.trim() || undefined,
        },
      })
      toast.success("Status review diperbarui")
      setEditDialogOpen(false)
      setEditingDoc(null)
      setReviewStatus("PENDING")
      setReviewNotes("")
    } catch (err: unknown) {
      const res = err as {
        response?: {
          data?: {
            errors?: Record<string, unknown>
            detail?: string
          }
        }
      }
      const errors = res?.response?.data?.errors
      const detail = res?.response?.data?.detail
      if (errors) {
        const msgs = Object.entries(errors)
          .flatMap(([k, v]) => {
            if (
              k === "review_notes" &&
              v &&
              typeof v === "object" &&
              !Array.isArray(v)
            ) {
              return Object.values(v as Record<string, unknown>).map((m) => String(m))
            }
            const arr = Array.isArray(v) ? v : [v]
            return arr.map((m) => `${k}: ${String(m)}`)
          })
        toast.error("Validasi gagal", msgs.join(". "))
      } else {
        toast.error("Gagal", detail ?? "Coba lagi nanti")
      }
    }
  }

  const openDelete = (doc: ApplicantDocument) => {
    setDeletingDoc(doc)
    setDeleteDialogOpen(true)
  }

  const handleDelete = async () => {
    if (!deletingDoc) return
    try {
      await deleteMutation.mutateAsync(deletingDoc.id)
      toast.success("Dokumen dihapus")
      setDeleteDialogOpen(false)
      setDeletingDoc(null)
    } catch {
      toast.error("Gagal menghapus")
    }
  }

  const getTypeName = (typeId: number) => {
    const t = types.find((x) => x.id === typeId)
    return t?.name ?? `Tipe ${typeId}`
  }

  const getStatusBadgeClass = (status: DocumentReviewStatus) => {
    switch (status) {
      case "APPROVED":
        return "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"
      case "REJECTED":
        return "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"
      default:
        return "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200"
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <p className="text-muted-foreground text-sm">
          Kelola dokumen pelamar (KTP, Ijasah, dll.).
        </p>
        <Dialog open={uploadDialogOpen} onOpenChange={setUploadDialogOpen}>
          <DialogTrigger asChild>
            <Button
              type="button"
              size="sm"
              className="cursor-pointer"
              disabled={availableTypes.length === 0}
            >
              <IconPlus className="mr-2 size-4" />
              Unggah Dokumen
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Unggah Dokumen</DialogTitle>
            </DialogHeader>
            <form onSubmit={handleUpload} className="space-y-6">
              <Field>
                <FieldLabel>
                  Tipe Dokumen <span className="text-destructive">*</span>
                </FieldLabel>
                <Select
                  value={selectedTypeId}
                  onValueChange={(val) => setSelectedTypeId(val)}
                >
                  <SelectTrigger className="cursor-pointer">
                    <SelectValue placeholder="Pilih tipe" />
                  </SelectTrigger>
                  <SelectContent>
                    {availableTypes.map((t) => (
                      <SelectItem key={t.id} value={String(t.id)}>
                        {t.name}
                        {t.is_required ? " (wajib)" : ""}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {selectedType?.description && (
                  <p className="mt-1 text-xs text-muted-foreground">
                    {selectedType.description}
                  </p>
                )}
              </Field>
              <Field>
                <FieldLabel>
                  File <span className="text-destructive">*</span>
                </FieldLabel>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".pdf,.jpg,.jpeg,image/jpeg,application/pdf"
                  className="hidden"
                  onChange={() => {
                    setFileError("")
                    const file = fileInputRef.current?.files?.[0]
                    setSelectedFileName(file ? file.name : "")
                  }}
                />
                <Button
                  type="button"
                  variant="outline"
                  className="flex w-full justify-start gap-2 cursor-pointer"
                  onClick={() => fileInputRef.current?.click()}
                >
                  <IconFileUpload className="size-4" />
                  <span className="truncate">
                    {selectedFileName || "Pilih file (PDF maks 2MB, JPG maks 500KB)"}
                  </span>
                </Button>
                {fileError && <FieldError errors={[{ message: fileError }]} />}
              </Field>
              <div className="flex justify-end gap-2">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setUploadDialogOpen(false)}
                >
                  Batal
                </Button>
                <Button
                  type="submit"
                  disabled={createMutation.isPending}
                  className="cursor-pointer"
                >
                  <IconFileUpload className="mr-2 size-4" />
                  Unggah
                </Button>
              </div>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Daftar Dokumen</CardTitle>
          <CardDescription>Dokumen yang telah diunggah</CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="flex justify-center py-8">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : list.length === 0 ? (
            <p className="text-muted-foreground py-8 text-center text-sm">
              Belum ada dokumen.
            </p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Tipe</TableHead>
                  <TableHead>Status Review</TableHead>
                  <TableHead>Direview Oleh</TableHead>
                  <TableHead>Diunggah</TableHead>
                  <TableHead>File</TableHead>
                  <TableHead className="w-[140px]"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {list.map((doc) => (
                  <TableRow key={doc.id}>
                    <TableCell className="font-medium">
                      {getTypeName(doc.document_type)}
                    </TableCell>
                    <TableCell>
                      <span
                        className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${getStatusBadgeClass(
                          doc.review_status
                        )}`}
                      >
                        {REVIEW_STATUS_LABELS[doc.review_status]}
                      </span>
                    </TableCell>
                    <TableCell>
                      {doc.reviewed_by_name ? (
                        <span className="text-sm font-medium">
                          {doc.reviewed_by_name}
                        </span>
                      ) : (
                        <span className="text-sm text-muted-foreground">-</span>
                      )}
                    </TableCell>
                    <TableCell>
                      {format(new Date(doc.uploaded_at), "dd MMM yyyy HH:mm", {
                        locale: id,
                      })}
                    </TableCell>
                    <TableCell>
                      <a
                        href={getFileUrl(doc.file)}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-primary hover:underline cursor-pointer"
                      >
                        Lihat file
                      </a>
                    </TableCell>
                    <TableCell>
                      <div className="flex gap-1">
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-8 cursor-pointer"
                          onClick={() => openEdit(doc)}
                          title="Edit Review"
                        >
                          <IconPencil className="size-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-8 cursor-pointer text-destructive"
                          onClick={() => openDelete(doc)}
                          title="Hapus"
                        >
                          <IconTrash className="size-4" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Edit Review Dialog */}
      <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Review Dokumen</DialogTitle>
          </DialogHeader>
          {editingDoc && (
            <form onSubmit={handleReviewSubmit} className="space-y-6">
              <FieldGroup>
                <Field>
                  <FieldLabel>
                    Tipe Dokumen
                  </FieldLabel>
                  <Input
                    value={getTypeName(editingDoc.document_type)}
                    disabled
                    className="bg-muted"
                  />
                </Field>
                <Field>
                  <FieldLabel>
                    Status Review <span className="text-destructive">*</span>
                  </FieldLabel>
                  <Select
                    value={reviewStatus}
                    onValueChange={(val) => {
                      setReviewStatus(val as DocumentReviewStatus)
                      setReviewError("")
                      // Clear notes when switching to APPROVED
                      if (val === "APPROVED") {
                        setReviewNotes("")
                      }
                    }}
                  >
                    <SelectTrigger className="cursor-pointer">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {Object.entries(REVIEW_STATUS_LABELS).map(([val, label]) => (
                        <SelectItem key={val} value={val}>
                          {label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                {reviewStatus !== "APPROVED" && (
                  <Field>
                    <FieldLabel>
                      Catatan Review{" "}
                      {reviewStatus === "REJECTED" && (
                        <span className="text-destructive">*</span>
                      )}
                    </FieldLabel>
                    <textarea
                      value={reviewNotes}
                      onChange={(e) => {
                        setReviewNotes(e.target.value)
                        setReviewError("")
                      }}
                      rows={4}
                      className={cn(
                        "flex min-h-[80px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
                        "focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px]",
                        "aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive"
                      )}
                      placeholder={
                        reviewStatus === "REJECTED"
                          ? "Alasan dokumen ditolak..."
                          : "Catatan tambahan (opsional)..."
                      }
                    />
                    {(reviewError || (reviewStatus === "REJECTED" && !reviewNotes.trim())) && (
                      <FieldError
                        errors={[
                          {
                            message:
                              reviewError ||
                              (reviewStatus === "REJECTED" && !reviewNotes.trim()
                                ? "Catatan review wajib diisi ketika status ditolak"
                                : ""),
                          },
                        ].filter((e) => e.message)}
                      />
                    )}
                  </Field>
                )}
              </FieldGroup>
              <div className="flex justify-end gap-2">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => {
                    setEditDialogOpen(false)
                    setEditingDoc(null)
                    setReviewStatus("PENDING")
                    setReviewNotes("")
                    setReviewError("")
                  }}
                >
                  Batal
                </Button>
                <Button
                  type="submit"
                  disabled={updateMutation.isPending}
                  className="cursor-pointer"
                >
                  {updateMutation.isPending ? "Menyimpan..." : "Simpan"}
                </Button>
              </div>
            </form>
          )}
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Hapus Dokumen</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <p className="text-sm text-muted-foreground">
              Apakah Anda yakin ingin menghapus dokumen{" "}
              <span className="font-medium text-foreground">
                {deletingDoc ? getTypeName(deletingDoc.document_type) : ""}
              </span>
              ?
            </p>
            <p className="text-sm text-muted-foreground">
              Tindakan ini tidak dapat dibatalkan.
            </p>
          </div>
          <div className="flex justify-end gap-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => {
                setDeleteDialogOpen(false)
                setDeletingDoc(null)
              }}
            >
              Batal
            </Button>
            <Button
              type="button"
              variant="destructive"
              onClick={handleDelete}
              disabled={deleteMutation.isPending}
              className="cursor-pointer"
            >
              {deleteMutation.isPending ? "Menghapus..." : "Hapus"}
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  )
}
