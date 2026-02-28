/**
 * Dialog for admin to assign a job to an applicant (admin-initiated placement).
 * Accepts jobId and/or applicantId as pre-filled props to support multiple contexts.
 */

import { useState, useEffect } from "react"
import { useForm } from "@tanstack/react-form"
import { z } from "zod"
import { IconUserPlus } from "@tabler/icons-react"

import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
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
import { Textarea } from "@/components/ui/textarea"
import { useAssignApplicationMutation } from "@/hooks/use-applications-query"
import { toast } from "@/lib/toast"

const formSchema = z.object({
  job: z.coerce
    .number({ error: "ID lowongan wajib diisi" })
    .int()
    .positive("ID lowongan harus positif"),
  applicant: z.coerce
    .number({ error: "ID pelamar wajib diisi" })
    .int()
    .positive("ID pelamar harus positif"),
  note: z.string().max(500, "Catatan maksimal 500 karakter").optional(),
})

interface AssignApplicationDialogProps {
  /** Pre-fill the job ID (e.g. opened from job detail page). */
  defaultJobId?: number
  /** Pre-fill the applicant ID (e.g. opened from applicant detail page). */
  defaultApplicantId?: number
  /** Called after a successful assignment. */
  onSuccess?: () => void
  /** Render a custom trigger element instead of the default button. */
  trigger?: React.ReactNode
}

function fieldErrors(errors: unknown[]): Array<{ message: string }> {
  return errors.map((e) => {
    if (typeof e === "string") return { message: e }
    const err = e as { message?: string }
    return { message: err?.message ?? String(e) }
  })
}

export function AssignApplicationDialog({
  defaultJobId,
  defaultApplicantId,
  onSuccess,
  trigger,
}: AssignApplicationDialogProps) {
  const [open, setOpen] = useState(false)
  const assignMutation = useAssignApplicationMutation()

  const form = useForm({
    defaultValues: {
      job: defaultJobId as number,
      applicant: defaultApplicantId as number,
      note: "",
    },
    onSubmit: async ({ value }) => {
      const result = formSchema.safeParse(value)
      if (!result.success) return
      const values = result.data
      try {
        await assignMutation.mutateAsync({
          job: values.job,
          applicant: values.applicant,
          note: values.note || undefined,
        })
        toast.success("Berhasil", "Pelamar berhasil ditugaskan ke lowongan ini.")
        setOpen(false)
        onSuccess?.()
      } catch (err: unknown) {
        const error = err as { response?: { data?: { detail?: string; non_field_errors?: string[]; errors?: unknown } } }
        const data = error?.response?.data
        if (data?.detail) {
          // Cooldown error has a specific detail message from the backend
          toast.error("Tidak dapat menugaskan", data.detail)
        } else if (data?.non_field_errors?.[0]) {
          toast.error("Gagal", data.non_field_errors[0])
        } else {
          toast.error("Gagal menugaskan", "Periksa data dan coba lagi.")
        }
      }
    },
  })

  // Sync pre-filled props when dialog opens
  useEffect(() => {
    if (open) {
      form.reset()
      form.setFieldValue("job", defaultJobId as number)
      form.setFieldValue("applicant", defaultApplicantId as number)
      form.setFieldValue("note", "")
    }
  }, [open, defaultJobId, defaultApplicantId, form])

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        {trigger ?? (
          <Button className="cursor-pointer">
            <IconUserPlus className="mr-2 size-4" />
            Tugaskan Pelamar
          </Button>
        )}
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Tugaskan Pelamar ke Lowongan</DialogTitle>
          <DialogDescription>
            Admin menentukan pelamar yang akan ditempatkan di lowongan ini.
          </DialogDescription>
        </DialogHeader>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            void form.handleSubmit()
          }}
          className="space-y-4"
        >
          <FieldGroup>
            <form.Field name="job">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>ID Lowongan</FieldLabel>
                  <Input
                    id={field.name}
                    type="number"
                    placeholder="Masukkan ID lowongan"
                    value={field.state.value ?? ""}
                    onChange={(e) => field.handleChange(Number(e.target.value) || (undefined as unknown as number))}
                    onBlur={field.handleBlur}
                  />
                  <FieldError errors={fieldErrors(field.state.meta.errors as unknown[])} />
                </Field>
              )}
            </form.Field>

            <form.Field name="applicant">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>ID Pelamar</FieldLabel>
                  <Input
                    id={field.name}
                    type="number"
                    placeholder="Masukkan ID pelamar"
                    value={field.state.value ?? ""}
                    onChange={(e) => field.handleChange(Number(e.target.value) || (undefined as unknown as number))}
                    onBlur={field.handleBlur}
                  />
                  <FieldError errors={fieldErrors(field.state.meta.errors as unknown[])} />
                </Field>
              )}
            </form.Field>

            <form.Field name="note">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Catatan (opsional)</FieldLabel>
                  <Textarea
                    id={field.name}
                    placeholder="Catatan untuk penugasan ini..."
                    className="resize-none"
                    rows={3}
                    value={field.state.value ?? ""}
                    onChange={(e) => field.handleChange(e.target.value)}
                    onBlur={field.handleBlur}
                  />
                  <FieldError errors={fieldErrors(field.state.meta.errors as unknown[])} />
                </Field>
              )}
            </form.Field>
          </FieldGroup>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              className="cursor-pointer"
              onClick={() => setOpen(false)}
            >
              Batal
            </Button>
            <Button
              type="submit"
              className="cursor-pointer"
              disabled={assignMutation.isPending}
            >
              {assignMutation.isPending ? "Memproses..." : "Tugaskan"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
