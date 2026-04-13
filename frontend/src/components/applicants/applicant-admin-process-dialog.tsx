/**
 * Modal to edit pelamar "Data Proses" (same fields as ApplicantAdminProcessTab on detail page).
 */

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"

import { ApplicantAdminProcessTab } from "@/components/applicants/applicant-admin-process-tab"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { getApplicant, patchApplicant } from "@/api/applicants"
import { applicantsKeys } from "@/hooks/use-applicants-query"
import { cn } from "@/lib/utils"
import type { ApplicantProfile, ApplicantUserUpdateInput } from "@/types/applicant"

type ApplicantAdminProcessDialogProps = {
  applicantUserId: number | null
  open: boolean
  onOpenChange: (open: boolean) => void
  /** Pelamar name for dialog title */
  applicantLabel?: string
}

export function ApplicantAdminProcessDialog({
  applicantUserId,
  open,
  onOpenChange,
  applicantLabel,
}: ApplicantAdminProcessDialogProps) {
  const queryClient = useQueryClient()

  const { data, isLoading, isError } = useQuery({
    queryKey: applicantsKeys.detail(applicantUserId ?? 0),
    queryFn: () => getApplicant(applicantUserId!),
    enabled: open && applicantUserId != null && applicantUserId > 0,
  })

  const profile: ApplicantProfile | undefined = data?.applicant_profile

  const saveMutation = useMutation({
    mutationFn: (input: Partial<ApplicantUserUpdateInput>) =>
      patchApplicant(applicantUserId!, input),
    onSuccess: () => {
      if (applicantUserId) {
        void queryClient.invalidateQueries({
          queryKey: applicantsKeys.detail(applicantUserId),
        })
      }
      void queryClient.invalidateQueries({ queryKey: ["applications"] })
      void queryClient.invalidateQueries({ queryKey: ["applicants"] })
      onOpenChange(false)
    },
  })

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        className={cn(
          "flex max-h-[min(92vh,920px)] w-[calc(100vw-1.5rem)] flex-col gap-0 overflow-hidden p-0",
          /* Override dialog default sm:max-w-lg so multi-column form fits */
          "max-w-4xl sm:max-w-4xl"
        )}
      >
        <DialogHeader className="shrink-0 border-b px-4 py-4 text-left sm:px-6">
          <DialogTitle>Data proses</DialogTitle>
          <DialogDescription>
            {applicantLabel
              ? `Medical, biaya, dan calling visa — ${applicantLabel}`
              : "Medical, biaya, dan calling visa pelamar."}
          </DialogDescription>
        </DialogHeader>
        <div className="min-h-0 min-w-0 flex-1 overflow-y-auto overflow-x-hidden px-4 py-4 sm:px-6">
          {isLoading ? (
            <div className="flex justify-center py-12">
              <div className="size-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : isError || !profile ? (
            <p className="text-destructive text-sm py-6">
              Gagal memuat data pelamar. Tutup dialog dan coba lagi.
            </p>
          ) : (
            <ApplicantAdminProcessTab
              key={profile.id}
              profile={profile}
              compactLayout
              onSubmit={async (partial: Partial<ApplicantProfile>) => {
                await saveMutation.mutateAsync({ applicant_profile: partial })
              }}
              isSubmitting={saveMutation.isPending}
            />
          )}
        </div>
      </DialogContent>
    </Dialog>
  )
}
