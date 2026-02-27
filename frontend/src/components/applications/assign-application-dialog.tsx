/**
 * Dialog for admin to assign a job to an applicant (admin-initiated placement).
 * Accepts jobId and/or applicantId as pre-filled props to support multiple contexts.
 */

import { useState, useEffect } from "react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
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
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { useAssignApplicationMutation } from "@/hooks/use-applications-query"
import { toast } from "@/lib/toast"

const formSchema = z.object({
  job: z.coerce
    .number({ required_error: "ID lowongan wajib diisi" })
    .int()
    .positive("ID lowongan harus positif"),
  applicant: z.coerce
    .number({ required_error: "ID pelamar wajib diisi" })
    .int()
    .positive("ID pelamar harus positif"),
  note: z.string().max(500, "Catatan maksimal 500 karakter").optional(),
})

type FormValues = z.infer<typeof formSchema>

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

export function AssignApplicationDialog({
  defaultJobId,
  defaultApplicantId,
  onSuccess,
  trigger,
}: AssignApplicationDialogProps) {
  const [open, setOpen] = useState(false)
  const assignMutation = useAssignApplicationMutation()

  const form = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      job: defaultJobId,
      applicant: defaultApplicantId,
      note: "",
    },
  })

  // Sync pre-filled props when dialog opens
  useEffect(() => {
    if (open) {
      form.reset({
        job: defaultJobId,
        applicant: defaultApplicantId,
        note: "",
      })
    }
  }, [open, defaultJobId, defaultApplicantId, form])

  const onSubmit = async (values: FormValues) => {
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
  }

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

        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="job"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>ID Lowongan</FormLabel>
                  <FormControl>
                    <Input
                      type="number"
                      placeholder="Masukkan ID lowongan"
                      {...field}
                      value={field.value ?? ""}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="applicant"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>ID Pelamar</FormLabel>
                  <FormControl>
                    <Input
                      type="number"
                      placeholder="Masukkan ID pelamar"
                      {...field}
                      value={field.value ?? ""}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="note"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Catatan (opsional)</FormLabel>
                  <FormControl>
                    <Textarea
                      placeholder="Catatan untuk penugasan ini..."
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
                disabled={assignMutation.isPending}
              >
                {assignMutation.isPending ? "Memproses..." : "Tugaskan"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  )
}
