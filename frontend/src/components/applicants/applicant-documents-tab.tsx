/**
 * Dokumen tab - CRUD ApplicantDocument (upload, delete).
 */

import { useRef, useState } from "react"
import { IconPlus, IconTrash, IconFileUpload } from "@tabler/icons-react"
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
  FieldLabel,
} from "@/components/ui/field"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import {
  useApplicantDocumentsQuery,
  useCreateApplicantDocumentMutation,
  useDeleteApplicantDocumentMutation,
  useDocumentTypesQuery,
} from "@/hooks/use-applicants-query"
import { toast } from "@/lib/toast"
import type { ApplicantDocument, DocumentType } from "@/types/applicant"
import { env } from "@/lib/env"

interface ApplicantDocumentsTabProps {
  applicantId: number
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
  const [dialogOpen, setDialogOpen] = useState(false)
  const [selectedTypeId, setSelectedTypeId] = useState<string>("")
  const [fileError, setFileError] = useState<string>("")

  const { data: documents = [], isLoading } = useApplicantDocumentsQuery(applicantId)
  const { data: docTypes = [] } = useDocumentTypesQuery()
  const createMutation = useCreateApplicantDocumentMutation(applicantId)
  const deleteMutation = useDeleteApplicantDocumentMutation(applicantId)

  const list = Array.isArray(documents)
    ? documents
    : (documents as { results?: ApplicantDocument[] })?.results ?? []
  const types = Array.isArray(docTypes)
    ? docTypes
    : (docTypes as { results?: DocumentType[] })?.results ?? []

  const uploadedTypeIds = new Set(list.map((d) => d.document_type))
  const availableTypes = types.filter((t) => !uploadedTypeIds.has(t.id))

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

    const formData = new FormData()
    formData.append("document_type", String(typeId))
    formData.append("file", file)

    try {
      await createMutation.mutateAsync(formData)
      toast.success("Dokumen berhasil diunggah")
      setDialogOpen(false)
      setSelectedTypeId("")
      if (fileInputRef.current) fileInputRef.current.value = ""
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error("Gagal mengunggah", res?.response?.data?.detail ?? "Coba lagi nanti")
    }
  }

  const handleDelete = async (doc: ApplicantDocument) => {
    if (!confirm("Hapus dokumen ini?")) return
    try {
      await deleteMutation.mutateAsync(doc.id)
      toast.success("Dokumen dihapus")
    } catch {
      toast.error("Gagal menghapus")
    }
  }

  const getTypeName = (typeId: number) => {
    const t = types.find((x) => x.id === typeId)
    return t?.name ?? `Tipe ${typeId}`
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <p className="text-muted-foreground text-sm">
          Kelola dokumen pelamar (KTP, Ijasah, dll.).
        </p>
        <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
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
                <FieldLabel>Tipe Dokumen *</FieldLabel>
                <select
                  className="border-input bg-background flex h-9 w-full rounded-md border px-3 py-1 text-sm"
                  value={selectedTypeId}
                  onChange={(e) => setSelectedTypeId(e.target.value)}
                  required
                >
                  <option value="">Pilih tipe</option>
                  {availableTypes.map((t) => (
                    <option key={t.id} value={t.id}>
                      {t.name}
                      {t.is_required ? " (wajib)" : ""}
                    </option>
                  ))}
                </select>
              </Field>
              <Field>
                <FieldLabel>File *</FieldLabel>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*,.pdf"
                  className="border-input bg-background flex h-9 w-full rounded-md border px-3 py-1 text-sm file:mr-4 file:rounded file:border-0 file:bg-primary file:px-4 file:py-2 file:text-sm file:text-primary-foreground"
                  onChange={() => setFileError("")}
                />
                {fileError && (
                  <FieldError errors={[{ message: fileError }]} />
                )}
              </Field>
              <div className="flex justify-end gap-2">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setDialogOpen(false)}
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
                  <TableHead>Diunggah</TableHead>
                  <TableHead>File</TableHead>
                  <TableHead className="w-[80px]"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {list.map((doc) => (
                  <TableRow key={doc.id}>
                    <TableCell className="font-medium">
                      {getTypeName(doc.document_type)}
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
                      <Button
                        variant="ghost"
                        size="icon"
                        className="size-8 cursor-pointer text-destructive"
                        onClick={() => handleDelete(doc)}
                        title="Hapus"
                      >
                        <IconTrash className="size-4" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
