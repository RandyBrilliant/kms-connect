/**
 * Dialog for admin/staff to advance a JobApplication's FSM status.
 * Shows only the transitions allowed from the current status (mirrors backend TRANSITIONS dict).
 */

import { useState } from "react"
import { useForm } from "@tanstack/react-form"
import { z } from "zod"
import { IconArrowRight } from "@tabler/icons-react"

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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { Input } from "@/components/ui/input"
import { useTransitionApplicationMutation } from "@/hooks/use-applications-query"
import {
  APPLICATION_STATUS_LABELS,
  type ApplicationStatus,
  type JobApplication,
} from "@/types/job-applications"
import { toast } from "@/lib/toast"

// Mirrors backend services.py TRANSITIONS — role = "admin"
const ADMIN_TRANSITIONS: Partial<Record<ApplicationStatus, ApplicationStatus[]>> = {
  PRA_SELEKSI: ["INTERVIEW", "DITOLAK"],
  INTERVIEW: ["DITERIMA", "DITOLAK"],
  DITERIMA: ["BERANGKAT", "DITOLAK"],
  BERANGKAT: ["SELESAI"],
}

// Date is required only when transitioning to SELESAI
const STATUSES_REQUIRING_DATE: ApplicationStatus[] = ["SELESAI"]

const formSchema = z
  .object({
    status: z.string().min(1, "Pilih status baru"),
    note: z.string().max(500, "Catatan maksimal 500 karakter").optional(),
    placement_end_date: z.string().optional(),
  })
  .refine(
    (data) => {
      if (STATUSES_REQUIRING_DATE.includes(data.status as ApplicationStatus)) {
        return !!data.placement_end_date
      }
      return true
    },
    {
      message: "Tanggal selesai kerja wajib diisi untuk status ini",
      path: ["placement_end_date"],
    }
  )

interface TransitionApplicationDialogProps {
  application: JobApplication
  onSuccess?: () => void
  trigger?: React.ReactNode
}

function fieldErrors(errors: unknown[]): Array<{ message: string }> {
  return errors.map((e) => {
    if (typeof e === "string") return { message: e }
    const err = e as { message?: string }
    return { message: err?.message ?? String(e) }
  })
}

export function TransitionApplicationDialog({
  application,
  onSuccess,
  trigger,
}: TransitionApplicationDialogProps) {
  const [open, setOpen] = useState(false)
  const transitionMutation = useTransitionApplicationMutation(application.id)

  const allowedStatuses = ADMIN_TRANSITIONS[application.status] ?? []

  const form = useForm({
    defaultValues: {
      status: "",
      note: "",
      placement_end_date: "",
    },
    onSubmit: async ({ value }) => {
      const result = formSchema.safeParse(value)
      if (!result.success) return
      const values = result.data
      try {
        await transitionMutation.mutateAsync({
          status: values.status as ApplicationStatus,
          note: values.note || undefined,
          placement_end_date: values.placement_end_date || null,
        })
        toast.success(
          "Status diperbarui",
          `Lamaran berhasil dipindahkan ke "${APPLICATION_STATUS_LABELS[values.status as ApplicationStatus]}".`
        )
        setOpen(false)
        form.reset()
        onSuccess?.()
      } catch (err: unknown) {
        const error = err as { response?: { data?: { detail?: string } } }
        const detail = error?.response?.data?.detail
        toast.error("Gagal memperbarui status", detail ?? "Coba lagi nanti.")
      }
    },
  })

  if (!allowedStatuses.length) {
    return null // No transitions available from this status
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(val) => {
        setOpen(val)
        if (!val) form.reset()
      }}
    >
      <DialogTrigger asChild>
        {trigger ?? (
          <Button variant="outline" size="sm" className="cursor-pointer">
            <IconArrowRight className="mr-2 size-4" />
            Ubah Status
          </Button>
        )}
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Ubah Status Lamaran</DialogTitle>
          <DialogDescription>
            Status saat ini:{" "}
            <strong>{APPLICATION_STATUS_LABELS[application.status]}</strong>
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
            <form.Field name="status">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Status Baru</FieldLabel>
                  <Select
                    value={field.state.value}
                    onValueChange={(v) => field.handleChange(v)}
                  >
                    <SelectTrigger id={field.name} className="cursor-pointer">
                      <SelectValue placeholder="Pilih status..." />
                    </SelectTrigger>
                    <SelectContent>
                      {allowedStatuses.map((s) => (
                        <SelectItem key={s} value={s}>
                          {APPLICATION_STATUS_LABELS[s]}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FieldError errors={fieldErrors(field.state.meta.errors as unknown[])} />
                </Field>
              )}
            </form.Field>

            <form.Subscribe selector={(state) => state.values.status}>
              {(status) =>
                STATUSES_REQUIRING_DATE.includes(status as ApplicationStatus) && (
                  <form.Field name="placement_end_date">
                    {(field) => (
                      <Field>
                        <FieldLabel htmlFor={field.name}>Tanggal Selesai Kerja</FieldLabel>
                        <Input
                          id={field.name}
                          type="date"
                          value={field.state.value ?? ""}
                          onChange={(e) => field.handleChange(e.target.value)}
                          onBlur={field.handleBlur}
                        />
                        <FieldError errors={fieldErrors(field.state.meta.errors as unknown[])} />
                      </Field>
                    )}
                  </form.Field>
                )
              }
            </form.Subscribe>

            <form.Field name="note">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Catatan (opsional)</FieldLabel>
                  <Textarea
                    id={field.name}
                    placeholder="Tambahkan catatan untuk perubahan status ini..."
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
              disabled={transitionMutation.isPending}
            >
              {transitionMutation.isPending ? "Memproses..." : "Simpan"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
