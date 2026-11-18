/**
 * Dokumen Pendukung tab — admin-only internal files for a pelamar.
 *
 * Any number of PDF/JPG/PNG files, each with a free-text label (the set differs per
 * placement). Pelamar, companies and the mobile app never see these files.
 */

import { useRef, useState } from "react"
import {
  IconDownload,
  IconFileUpload,
  IconLock,
  IconPencil,
  IconPlus,
  IconTrash,
  IconX,
} from "@tabler/icons-react"
import { format } from "date-fns"
import { id } from "date-fns/locale"

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Field, FieldError, FieldLabel } from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import {
  useDeleteSupportingDocumentMutation,
  useSupportingDocumentsQuery,
  useUpdateSupportingDocumentMutation,
  useUploadSupportingDocumentMutation,
} from "@/hooks/use-applicants-query"
import { downloadAllSupportingDocuments } from "@/api/applicants"
import { toast } from "@/lib/toast"
import type { ApplicantSupportingDocument } from "@/types/applicant"

const MAX_FILE_BYTES = 2 * 1024 * 1024
const ACCEPTED_MIME = ["application/pdf", "image/jpeg", "image/png"]
const ACCEPTED_EXT = /\.(pdf|jpe?g|png)$/i
const MAX_LABEL_LENGTH = 150
const LABEL_SUGGESTIONS_ID = "supporting-document-label-suggestions"

interface ApplicantSupportingDocumentsTabProps {
  applicantId: number
  /** Used for the ZIP filename fallback. */
  fullName?: string
}

interface PendingUpload {
  key: string
  file: File
  label: string
  status: "idle" | "uploading" | "done" | "error"
  error?: string
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

function defaultLabel(fileName: string): string {
  return fileName.replace(ACCEPTED_EXT, "").replace(/[_-]+/g, " ").trim().slice(0, MAX_LABEL_LENGTH)
}

function clientFileError(file: File): string | undefined {
  const accepted = ACCEPTED_EXT.test(file.name) && (!file.type || ACCEPTED_MIME.includes(file.type))
  if (!accepted) return "Hanya file PDF, JPG, atau PNG yang diperbolehkan."
  if (file.size > MAX_FILE_BYTES) return "Ukuran file melebihi 2 MB."
  return undefined
}

function serverErrorMessage(err: unknown): string {
  const data = (err as { response?: { data?: unknown } })?.response?.data as
    | { detail?: string; errors?: Record<string, unknown> }
    | undefined
  const errors = data?.errors
  if (errors) {
    for (const key of ["file", "label", "non_field_errors"]) {
      const value = errors[key]
      if (Array.isArray(value) && typeof value[0] === "string") return value[0]
    }
  }
  return data?.detail || "Gagal mengunggah. Coba lagi."
}

export function ApplicantSupportingDocumentsTab({
  applicantId,
  fullName = "",
}: ApplicantSupportingDocumentsTabProps) {
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [uploadOpen, setUploadOpen] = useState(false)
  const [pending, setPending] = useState<PendingUpload[]>([])
  const [isUploading, setIsUploading] = useState(false)
  const [isDownloading, setIsDownloading] = useState(false)

  const [editingDoc, setEditingDoc] = useState<ApplicantSupportingDocument | null>(null)
  const [editLabel, setEditLabel] = useState("")
  const [deletingDoc, setDeletingDoc] = useState<ApplicantSupportingDocument | null>(null)

  const { data: documents = [], isLoading } = useSupportingDocumentsQuery(applicantId)
  const uploadMutation = useUploadSupportingDocumentMutation(applicantId)
  const updateMutation = useUpdateSupportingDocumentMutation(applicantId)
  const deleteMutation = useDeleteSupportingDocumentMutation(applicantId)

  const labelSuggestions = Array.from(new Set(documents.map((d) => d.label))).sort()

  // --- upload -----------------------------------------------------------
  const resetUpload = () => {
    setPending([])
    if (fileInputRef.current) fileInputRef.current.value = ""
  }

  const handleFilesSelected = (files: FileList | null) => {
    if (!files?.length) return
    const added: PendingUpload[] = Array.from(files).map((file) => {
      const error = clientFileError(file)
      return {
        key: `${file.name}-${file.size}-${file.lastModified}-${Math.random()}`,
        file,
        label: defaultLabel(file.name),
        status: error ? "error" : "idle",
        error,
      }
    })
    setPending((prev) => [...prev, ...added])
    if (fileInputRef.current) fileInputRef.current.value = ""
  }

  const updatePending = (key: string, patch: Partial<PendingUpload>) =>
    setPending((prev) => prev.map((p) => (p.key === key ? { ...p, ...patch } : p)))

  const removePending = (key: string) =>
    setPending((prev) => prev.filter((p) => p.key !== key))

  const toUpload = pending.filter((p) => p.status !== "done" && !clientFileError(p.file))
  const hasBlankLabel = toUpload.some((p) => !p.label.trim())
  const hasInvalidFile = pending.some((p) => p.status !== "done" && clientFileError(p.file))

  const handleUpload = async () => {
    if (!toUpload.length || hasBlankLabel || hasInvalidFile) return
    setIsUploading(true)
    let succeeded = 0
    let failed = 0
    // One request per file, in order, so each row gets its own result.
    for (const item of toUpload) {
      updatePending(item.key, { status: "uploading", error: undefined })
      try {
        await uploadMutation.mutateAsync({ label: item.label.trim(), file: item.file })
        updatePending(item.key, { status: "done" })
        succeeded += 1
      } catch (err) {
        updatePending(item.key, { status: "error", error: serverErrorMessage(err) })
        failed += 1
      }
    }
    setIsUploading(false)

    if (failed === 0) {
      toast.success("Dokumen pendukung diunggah", `${succeeded} file berhasil diunggah.`)
      setUploadOpen(false)
      resetUpload()
    } else {
      // Keep the dialog open with only the failed rows so they can be fixed.
      setPending((prev) => prev.filter((p) => p.status !== "done"))
      toast.error(
        "Sebagian gagal diunggah",
        `${succeeded} berhasil, ${failed} gagal. Periksa file yang ditandai.`
      )
    }
  }

  // --- download ---------------------------------------------------------
  const handleDownloadAll = async () => {
    setIsDownloading(true)
    try {
      const { missing } = await downloadAllSupportingDocuments(applicantId, fullName)
      if (missing.length) {
        toast.warning(
          "Sebagian file tidak ditemukan",
          `${missing.length} file tidak tersedia di penyimpanan dan tidak masuk ZIP.`
        )
      } else {
        toast.success("Dokumen pendukung diunduh", "File ZIP telah tersimpan.")
      }
    } catch (err: unknown) {
      const status = (err as { response?: { status?: number } })?.response?.status
      if (status === 404) {
        toast.error("Tidak ada dokumen", "Pelamar belum memiliki dokumen pendukung.")
      } else {
        toast.error("Gagal mengunduh", "Coba lagi nanti.")
      }
    } finally {
      setIsDownloading(false)
    }
  }

  // --- edit / delete ----------------------------------------------------
  const openEdit = (doc: ApplicantSupportingDocument) => {
    setEditingDoc(doc)
    setEditLabel(doc.label)
  }

  const handleEditSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!editingDoc || !editLabel.trim()) return
    try {
      await updateMutation.mutateAsync({ id: editingDoc.id, label: editLabel.trim() })
      toast.success("Label diperbarui")
      setEditingDoc(null)
    } catch (err) {
      toast.error("Gagal memperbarui label", serverErrorMessage(err))
    }
  }

  const handleDelete = async () => {
    if (!deletingDoc) return
    try {
      await deleteMutation.mutateAsync(deletingDoc.id)
      toast.success("Dokumen pendukung dihapus")
      setDeletingDoc(null)
    } catch {
      toast.error("Gagal menghapus", "Coba lagi nanti.")
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-muted-foreground flex items-center gap-2 text-sm">
          <IconLock className="size-4 shrink-0" />
          Dokumen internal admin. Tidak terlihat oleh pelamar maupun perusahaan.
        </p>
        <div className="flex items-center gap-2">
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="cursor-pointer"
            disabled={isDownloading || documents.length === 0}
            onClick={handleDownloadAll}
            title={
              documents.length === 0
                ? "Belum ada dokumen pendukung"
                : "Unduh semua dokumen pendukung sebagai ZIP"
            }
          >
            <IconDownload className="mr-2 size-4" />
            {isDownloading ? "Mengunduh..." : "Unduh Semua (ZIP)"}
          </Button>
          <Button
            type="button"
            size="sm"
            className="cursor-pointer"
            onClick={() => setUploadOpen(true)}
          >
            <IconPlus className="mr-2 size-4" />
            Tambah Dokumen
          </Button>
        </div>
      </div>

      <datalist id={LABEL_SUGGESTIONS_ID}>
        {labelSuggestions.map((label) => (
          <option key={label} value={label} />
        ))}
      </datalist>

      <Card>
        <CardHeader>
          <CardTitle>Dokumen Pendukung</CardTitle>
          <CardDescription>
            PDF atau gambar (JPG/PNG) internal dengan label bebas. Jumlah dan jenisnya boleh berbeda untuk tiap pelamar.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="flex justify-center py-8">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : documents.length === 0 ? (
            <div className="flex flex-col items-center gap-3 py-10 text-center">
              <p className="text-muted-foreground text-sm">Belum ada dokumen pendukung.</p>
              <Button
                type="button"
                variant="outline"
                size="sm"
                className="cursor-pointer"
                onClick={() => setUploadOpen(true)}
              >
                <IconFileUpload className="mr-2 size-4" />
                Unggah Dokumen
              </Button>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-12">No</TableHead>
                  <TableHead>Label</TableHead>
                  <TableHead>Nama File</TableHead>
                  <TableHead>Ukuran</TableHead>
                  <TableHead>Diunggah Oleh</TableHead>
                  <TableHead>Diunggah</TableHead>
                  <TableHead className="w-[160px]"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {documents.map((doc, index) => (
                  <TableRow key={doc.id}>
                    <TableCell className="text-muted-foreground tabular-nums">
                      {index + 1}
                    </TableCell>
                    <TableCell className="max-w-[260px] font-medium break-words">
                      {doc.label}
                    </TableCell>
                    <TableCell
                      className="text-muted-foreground max-w-[220px] truncate text-sm"
                      title={doc.original_filename}
                    >
                      {doc.original_filename || "-"}
                    </TableCell>
                    <TableCell className="text-sm tabular-nums">
                      {formatBytes(doc.file_size)}
                    </TableCell>
                    <TableCell className="text-sm">{doc.uploaded_by_name || "-"}</TableCell>
                    <TableCell className="text-sm">
                      {format(new Date(doc.created_at), "dd MMM yyyy HH:mm", { locale: id })}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-1">
                        {doc.file_view_url && (
                          <a
                            href={doc.file_view_url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-primary mr-2 text-sm hover:underline"
                          >
                            Lihat
                          </a>
                        )}
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-8 cursor-pointer"
                          onClick={() => openEdit(doc)}
                          title="Ubah label"
                        >
                          <IconPencil className="size-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-8 cursor-pointer text-destructive"
                          onClick={() => setDeletingDoc(doc)}
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

      {/* Upload dialog: several PDFs, one label each */}
      <Dialog
        open={uploadOpen}
        onOpenChange={(open) => {
          if (isUploading) return
          setUploadOpen(open)
          if (!open) resetUpload()
        }}
      >
        <DialogContent className="sm:max-w-2xl">
          <DialogHeader>
            <DialogTitle>Tambah Dokumen Pendukung</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <input
              ref={fileInputRef}
              type="file"
              multiple
              accept="application/pdf,.pdf,image/jpeg,.jpg,.jpeg,image/png,.png"
              className="hidden"
              onChange={(e) => handleFilesSelected(e.target.files)}
            />
            <Button
              type="button"
              variant="outline"
              className="flex w-full cursor-pointer justify-start gap-2"
              disabled={isUploading}
              onClick={() => fileInputRef.current?.click()}
            >
              <IconFileUpload className="size-4" />
              {pending.length ? "Tambah file lain" : "Pilih file PDF, JPG, atau PNG (bisa lebih dari satu, maks 2 MB per file)"}
            </Button>

            {pending.length > 0 && (
              <div className="max-h-[50vh] space-y-3 overflow-y-auto pr-1">
                {pending.map((item) => {
                  const fileError = clientFileError(item.file)
                  return (
                    <div key={item.key} className="rounded-md border p-3">
                      <div className="mb-2 flex items-start justify-between gap-2">
                        <div className="min-w-0">
                          <p className="truncate text-sm font-medium" title={item.file.name}>
                            {item.file.name}
                          </p>
                          <p className="text-muted-foreground text-xs">
                            {formatBytes(item.file.size)}
                            {item.status === "uploading" && " · Mengunggah..."}
                            {item.status === "done" && " · Berhasil"}
                          </p>
                        </div>
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          className="size-7 shrink-0 cursor-pointer"
                          disabled={isUploading}
                          onClick={() => removePending(item.key)}
                          title="Hapus dari daftar"
                        >
                          <IconX className="size-4" />
                        </Button>
                      </div>
                      {!fileError && (
                        <Field>
                          <FieldLabel className="text-xs">
                            Label <span className="text-destructive">*</span>
                          </FieldLabel>
                          <Input
                            value={item.label}
                            maxLength={MAX_LABEL_LENGTH}
                            list={LABEL_SUGGESTIONS_ID}
                            placeholder="mis. Surat Sponsor PT A"
                            disabled={isUploading || item.status === "done"}
                            aria-invalid={!item.label.trim() || undefined}
                            onChange={(e) =>
                              updatePending(item.key, {
                                label: e.target.value,
                                ...(item.status === "error" ? { status: "idle", error: undefined } : {}),
                              })
                            }
                          />
                        </Field>
                      )}
                      {(fileError || item.error) && (
                        <FieldError errors={[{ message: fileError || item.error }]} />
                      )}
                    </div>
                  )
                })}
              </div>
            )}

            {hasInvalidFile && (
              <p className="text-destructive text-xs">
                Hapus file yang bukan PDF/JPG/PNG atau lebih dari 2 MB dari daftar sebelum mengunggah.
              </p>
            )}

            <div className="flex justify-end gap-2">
              <Button
                type="button"
                variant="outline"
                disabled={isUploading}
                onClick={() => {
                  setUploadOpen(false)
                  resetUpload()
                }}
              >
                Batal
              </Button>
              <Button
                type="button"
                className="cursor-pointer"
                disabled={isUploading || !toUpload.length || hasBlankLabel || hasInvalidFile}
                onClick={handleUpload}
              >
                <IconFileUpload className="mr-2 size-4" />
                {isUploading
                  ? "Mengunggah..."
                  : toUpload.length > 1
                    ? `Unggah ${toUpload.length} File`
                    : "Unggah"}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Edit label dialog */}
      <Dialog open={!!editingDoc} onOpenChange={(open) => !open && setEditingDoc(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Ubah Label</DialogTitle>
          </DialogHeader>
          <form onSubmit={handleEditSubmit} className="space-y-6">
            <Field>
              <FieldLabel>
                Label <span className="text-destructive">*</span>
              </FieldLabel>
              <Input
                value={editLabel}
                maxLength={MAX_LABEL_LENGTH}
                list={LABEL_SUGGESTIONS_ID}
                onChange={(e) => setEditLabel(e.target.value)}
                autoFocus
              />
              {!editLabel.trim() && <FieldError errors={[{ message: "Label wajib diisi." }]} />}
            </Field>
            <div className="flex justify-end gap-2">
              <Button type="button" variant="outline" onClick={() => setEditingDoc(null)}>
                Batal
              </Button>
              <Button
                type="submit"
                className="cursor-pointer"
                disabled={updateMutation.isPending || !editLabel.trim()}
              >
                {updateMutation.isPending ? "Menyimpan..." : "Simpan"}
              </Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>

      {/* Delete confirmation */}
      <Dialog open={!!deletingDoc} onOpenChange={(open) => !open && setDeletingDoc(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Hapus Dokumen Pendukung</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <p className="text-muted-foreground text-sm">
              Hapus dokumen{" "}
              <span className="text-foreground font-medium">{deletingDoc?.label}</span>?
            </p>
            <p className="text-muted-foreground text-sm">Tindakan ini tidak dapat dibatalkan.</p>
          </div>
          <div className="flex justify-end gap-2">
            <Button type="button" variant="outline" onClick={() => setDeletingDoc(null)}>
              Batal
            </Button>
            <Button
              type="button"
              variant="destructive"
              className="cursor-pointer"
              disabled={deleteMutation.isPending}
              onClick={handleDelete}
            >
              {deleteMutation.isPending ? "Menghapus..." : "Hapus"}
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  )
}
