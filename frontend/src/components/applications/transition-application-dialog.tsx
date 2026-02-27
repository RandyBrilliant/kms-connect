/**
 * Dialog for admin/staff to advance a JobApplication's FSM status.
 * Shows only the transitions allowed from the current status (mirrors backend TRANSITIONS dict).
 */

import { useState } from "react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
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
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form"
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
  APPLIED: ["UNDER_REVIEW", "REJECTED"],
  UNDER_REVIEW: ["SHORTLISTED", "REJECTED"],
  SHORTLISTED: ["OFFERED", "REJECTED"],
  OFFERED: ["OFFER_ACCEPTED", "OFFER_DECLINED", "REJECTED"],
  OFFER_ACCEPTED: ["PLACED"],
  PLACED: ["COMPLETED", "REJECTED"],
  OFFER_DECLINED: ["REJECTED", "SHORTLISTED"],
}

// Date is required only when transitioning to COMPLETED
const STATUSES_REQUIRING_DATE: ApplicationStatus[] = ["COMPLETED"]

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

type FormValues = z.infer<typeof formSchema>

interface TransitionApplicationDialogProps {
  application: JobApplication
  onSuccess?: () => void
  trigger?: React.ReactNode
}

export function TransitionApplicationDialog({
  application,
  onSuccess,
  trigger,
}: TransitionApplicationDialogProps) {
  const [open, setOpen] = useState(false)
  const transitionMutation = useTransitionApplicationMutation(application.id)

  const allowedStatuses = ADMIN_TRANSITIONS[application.status] ?? []

  const form = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      status: "",
      note: "",
      placement_end_date: "",
    },
  })

  const watchStatus = form.watch("status") as ApplicationStatus | ""
  const needsDate =
    watchStatus !== "" && STATUSES_REQUIRING_DATE.includes(watchStatus as ApplicationStatus)

  const onSubmit = async (values: FormValues) => {
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
  }

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

        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="status"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Status Baru</FormLabel>
                  <Select
                    onValueChange={field.onChange}
                    value={field.value}
                  >
                    <FormControl>
                      <SelectTrigger className="cursor-pointer">
                        <SelectValue placeholder="Pilih status..." />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {allowedStatuses.map((s) => (
                        <SelectItem key={s} value={s}>
                          {APPLICATION_STATUS_LABELS[s]}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />

            {needsDate && (
              <FormField
                control={form.control}
                name="placement_end_date"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Tanggal Selesai Kerja</FormLabel>
                    <FormControl>
                      <Input type="date" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            )}

            <FormField
              control={form.control}
              name="note"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Catatan (opsional)</FormLabel>
                  <FormControl>
                    <Textarea
                      placeholder="Tambahkan catatan untuk perubahan status ini..."
                      className="resize-none"
                      rows={3}
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

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
        </Form>
      </DialogContent>
    </Dialog>
  )
}
