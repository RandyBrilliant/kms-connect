/**
 * Pengalaman Kerja tab - CRUD WorkExperience.
 */

import { useState } from "react"
import {
  IconPlus,
  IconPencil,
  IconTrash,
} from "@tabler/icons-react"
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
import { Checkbox } from "@/components/ui/checkbox"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { workExperienceSchema } from "@/schemas/applicant"
import type { WorkExperience } from "@/types/applicant"
import {
  useWorkExperiencesQuery,
  useCreateWorkExperienceMutation,
  useUpdateWorkExperienceMutation,
  useDeleteWorkExperienceMutation,
} from "@/hooks/use-applicants-query"
import { toast } from "@/lib/toast"

interface ApplicantWorkExperienceTabProps {
  applicantId: number
}

export function ApplicantWorkExperienceTab({
  applicantId,
}: ApplicantWorkExperienceTabProps) {
  const [dialogOpen, setDialogOpen] = useState(false)
  const [editing, setEditing] = useState<WorkExperience | null>(null)
  const [values, setValues] = useState({
    company_name: "",
    position: "",
    start_date: "" as string | null,
    end_date: "" as string | null,
    still_employed: false,
    description: "",
    sort_order: 0,
  })
  const [errors, setErrors] = useState<Partial<Record<string, string>>>({})

  const { data: experiences = [], isLoading } = useWorkExperiencesQuery(applicantId)
  const createMutation = useCreateWorkExperienceMutation(applicantId)
  const updateMutation = useUpdateWorkExperienceMutation(applicantId)
  const deleteMutation = useDeleteWorkExperienceMutation(applicantId)

  const resetForm = () => {
    setEditing(null)
    setValues({
      company_name: "",
      position: "",
      start_date: null,
      end_date: null,
      still_employed: false,
      description: "",
      sort_order: 0,
    })
    setErrors({})
  }

  const openCreate = () => {
    resetForm()
    setDialogOpen(true)
  }

  const openEdit = (we: WorkExperience) => {
    setEditing(we)
    setValues({
      company_name: we.company_name,
      position: we.position || "",
      start_date: we.start_date || null,
      end_date: we.end_date || null,
      still_employed: we.still_employed,
      description: we.description || "",
      sort_order: we.sort_order,
    })
    setErrors({})
    setDialogOpen(true)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrors({})

    const payload = {
      company_name: values.company_name,
      position: values.position || undefined,
      start_date: values.start_date || null,
      end_date: values.end_date || null,
      still_employed: values.still_employed,
      description: values.description || undefined,
      sort_order: values.sort_order,
    }

    const result = workExperienceSchema.safeParse(payload)
    if (!result.success) {
      const errs: Partial<Record<string, string>> = {}
      for (const issue of result.error.issues) {
        const path = issue.path[0] as string
        if (path) errs[path] = issue.message
      }
      setErrors(errs)
      return
    }

    try {
      if (editing) {
        await updateMutation.mutateAsync({
          id: editing.id,
          input: result.data,
        })
        toast.success("Pengalaman kerja diperbarui")
      } else {
        await createMutation.mutateAsync(result.data)
        toast.success("Pengalaman kerja ditambahkan")
      }
      setDialogOpen(false)
      resetForm()
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error("Gagal", res?.response?.data?.detail ?? "Coba lagi nanti")
    }
  }

  const handleDelete = async (we: WorkExperience) => {
    if (!confirm("Hapus pengalaman kerja ini?")) return
    try {
      await deleteMutation.mutateAsync(we.id)
      toast.success("Pengalaman kerja dihapus")
    } catch {
      toast.error("Gagal menghapus")
    }
  }

  const list = Array.isArray(experiences) ? experiences : (experiences as { results?: WorkExperience[] })?.results ?? []

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <p className="text-muted-foreground text-sm">
          Kelola riwayat pengalaman kerja pelamar.
        </p>
        <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
          <DialogTrigger asChild>
            <Button
              type="button"
              size="sm"
              className="cursor-pointer"
              onClick={openCreate}
            >
              <IconPlus className="mr-2 size-4" />
              Tambah Pengalaman
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>
                {editing ? "Edit Pengalaman Kerja" : "Tambah Pengalaman Kerja"}
              </DialogTitle>
            </DialogHeader>
            <form onSubmit={handleSubmit} className="space-y-6">
              <FieldGroup>
                <Field>
                  <FieldLabel htmlFor="company_name">Nama Perusahaan *</FieldLabel>
                  <Input
                    id="company_name"
                    value={values.company_name}
                    onChange={(e) =>
                      setValues((v) => ({ ...v, company_name: e.target.value }))
                    }
                  />
                  <FieldError
                    errors={errors.company_name ? [{ message: errors.company_name }] : []}
                  />
                </Field>
                <Field>
                  <FieldLabel htmlFor="position">Jabatan / Posisi</FieldLabel>
                  <Input
                    id="position"
                    value={values.position}
                    onChange={(e) =>
                      setValues((v) => ({ ...v, position: e.target.value }))
                    }
                  />
                </Field>
                <div className="grid gap-4 sm:grid-cols-2">
                  <Field>
                    <FieldLabel htmlFor="start_date">Tanggal Mulai</FieldLabel>
                    <Input
                      id="start_date"
                      type="date"
                      value={values.start_date ?? ""}
                      onChange={(e) =>
                        setValues((v) => ({
                          ...v,
                          start_date: e.target.value || null,
                        }))
                      }
                    />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="end_date">Tanggal Selesai</FieldLabel>
                    <Input
                      id="end_date"
                      type="date"
                      value={values.end_date ?? ""}
                      onChange={(e) =>
                        setValues((v) => ({
                          ...v,
                          end_date: e.target.value || null,
                        }))
                      }
                      disabled={values.still_employed}
                    />
                  </Field>
                </div>
                <div className="flex items-center space-x-2">
                  <Checkbox
                    id="still_employed"
                    checked={values.still_employed}
                    onCheckedChange={(c) =>
                      setValues((v) => ({
                        ...v,
                        still_employed: !!c,
                        end_date: !!c ? null : v.end_date,
                      }))
                    }
                  />
                  <FieldLabel htmlFor="still_employed" className="cursor-pointer font-normal">
                    Masih bekerja di sini
                  </FieldLabel>
                </div>
                <Field>
                  <FieldLabel htmlFor="description">Keterangan</FieldLabel>
                  <Input
                    id="description"
                    value={values.description}
                    onChange={(e) =>
                      setValues((v) => ({ ...v, description: e.target.value }))
                    }
                  />
                </Field>
              </FieldGroup>
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
                  disabled={createMutation.isPending || updateMutation.isPending}
                  className="cursor-pointer"
                >
                  {editing ? "Simpan" : "Tambah"}
                </Button>
              </div>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Daftar Pengalaman Kerja</CardTitle>
          <CardDescription>Riwayat pekerjaan pelamar</CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="flex justify-center py-8">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : list.length === 0 ? (
            <p className="text-muted-foreground py-8 text-center text-sm">
              Belum ada pengalaman kerja.
            </p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Perusahaan</TableHead>
                  <TableHead>Jabatan</TableHead>
                  <TableHead>Periode</TableHead>
                  <TableHead className="w-[100px]"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {list.map((we) => (
                  <TableRow key={we.id}>
                    <TableCell className="font-medium">{we.company_name}</TableCell>
                    <TableCell>{we.position || "-"}</TableCell>
                    <TableCell>
                      {we.start_date
                        ? format(new Date(we.start_date), "MMM yyyy", {
                            locale: id,
                          })
                        : "-"}{" "}
                      –{" "}
                      {we.still_employed
                        ? "Sekarang"
                        : we.end_date
                          ? format(new Date(we.end_date), "MMM yyyy", {
                              locale: id,
                            })
                          : "-"}
                    </TableCell>
                    <TableCell>
                      <div className="flex gap-1">
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-8 cursor-pointer"
                          onClick={() => openEdit(we)}
                          title="Edit"
                        >
                          <IconPencil className="size-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-8 cursor-pointer text-destructive"
                          onClick={() => handleDelete(we)}
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
    </div>
  )
}
