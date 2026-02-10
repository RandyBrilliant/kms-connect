/**
 * Metadata tab - verification status, dates, actions.
 */

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { useUpdateApplicantMutation } from "@/hooks/use-applicants-query"
import { toast } from "@/lib/toast"
import type { ApplicantUser } from "@/types/applicant"
import type { ApplicantVerificationStatus } from "@/types/applicant"
import { format } from "date-fns"
import { id } from "date-fns/locale"

const VERIFICATION_LABELS: Record<ApplicantVerificationStatus, string> = {
  DRAFT: "Draf",
  SUBMITTED: "Dikirim",
  ACCEPTED: "Diterima",
  REJECTED: "Ditolak",
}

function formatDate(value: string | null) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy HH:mm", { locale: id })
}

interface ApplicantMetadataTabProps {
  applicant: ApplicantUser
  onUpdated?: () => void
}

export function ApplicantMetadataTab({
  applicant,
  onUpdated,
}: ApplicantMetadataTabProps) {
  const profile = applicant.applicant_profile
  const updateMutation = useUpdateApplicantMutation(applicant.id)

  const handleStatusChange = async (value: ApplicantVerificationStatus) => {
    try {
      await updateMutation.mutateAsync({
        applicant_profile: {
          verification_status: value,
        },
      })
      toast.success("Status verifikasi diperbarui")
      onUpdated?.()
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error("Gagal", res?.response?.data?.detail ?? "Coba lagi nanti")
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <Card>
        <CardHeader>
          <CardTitle>Status Verifikasi</CardTitle>
          <CardDescription>
            Ubah status verifikasi pelamar. Dikirim = menunggu verifikasi. Diterima/Ditolak = hasil verifikasi.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center gap-4">
            <span className="text-muted-foreground text-sm">Status saat ini:</span>
            <Select
              value={profile.verification_status}
              onValueChange={(v) =>
                handleStatusChange(v as ApplicantVerificationStatus)
              }
              disabled={updateMutation.isPending}
            >
              <SelectTrigger className="w-[180px] cursor-pointer">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {Object.entries(VERIFICATION_LABELS).map(([val, label]) => (
                  <SelectItem key={val} value={val}>
                    {label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Metadata</CardTitle>
          <CardDescription>Informasi sistem terkait pelamar</CardDescription>
        </CardHeader>
        <CardContent>
          <dl className="space-y-4 text-sm">
            <div>
              <dt className="text-muted-foreground">ID User</dt>
              <dd className="font-medium">{applicant.id}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">ID Profil</dt>
              <dd className="font-medium">{profile.id}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Dibuat pada</dt>
              <dd className="font-medium">{formatDate(profile.created_at)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Diperbarui pada</dt>
              <dd className="font-medium">{formatDate(profile.updated_at)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Dikirim untuk verifikasi</dt>
              <dd className="font-medium">{formatDate(profile.submitted_at)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Diverifikasi pada</dt>
              <dd className="font-medium">{formatDate(profile.verified_at)}</dd>
            </div>
            <div>
              <dt className="text-muted-foreground">Bergabung (User)</dt>
              <dd className="font-medium">{formatDate(applicant.date_joined)}</dd>
            </div>
            {profile.verification_notes && (
              <div>
                <dt className="text-muted-foreground">Catatan verifikasi</dt>
                <dd className="font-medium">{profile.verification_notes}</dd>
              </div>
            )}
          </dl>
        </CardContent>
      </Card>
    </div>
  )
}
