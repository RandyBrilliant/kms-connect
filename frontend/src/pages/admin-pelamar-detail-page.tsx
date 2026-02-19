/**
 * Pelamar detail page with tabs: Biodata, Pengalaman Kerja, Dokumen.
 * Metadata & account actions are shown on the Biodata tab sidebar.
 */

import { Link, useParams } from "react-router-dom"
import { IconArrowLeft, IconMail, IconKey } from "@tabler/icons-react"

import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { ApplicantBiodataTab } from "@/components/applicants/applicant-biodata-tab"
import { ApplicantWorkExperienceTab } from "@/components/applicants/applicant-work-experience-tab"
import { ApplicantDocumentsTab } from "@/components/applicants/applicant-documents-tab"
import { ApplicantMetadataTab } from "@/components/applicants/applicant-metadata-tab"
import {
  useApplicantQuery,
  useUpdateApplicantMutation,
  useDeactivateApplicantMutation,
  useActivateApplicantMutation,
  useSendVerificationEmailMutation,
  useSendPasswordResetMutation,
} from "@/hooks/use-applicants-query"
import { toast } from "@/lib/toast"
import type { ApplicantUser } from "@/types/applicant"
import { usePageTitle } from "@/hooks/use-page-title"

const BASE_PATH = "/pelamar"

function ApplicantSidebar({ applicant }: { applicant: ApplicantUser }) {
  const deactivateMutation = useDeactivateApplicantMutation()
  const activateMutation = useActivateApplicantMutation()
  const sendVerificationMutation = useSendVerificationEmailMutation()
  const sendPasswordResetMutation = useSendPasswordResetMutation()

  const handleToggleActive = async () => {
    try {
      if (applicant.is_active) {
        await deactivateMutation.mutateAsync(applicant.id)
        toast.success("Pelamar dinonaktifkan", "Akun tidak dapat login")
      } else {
        await activateMutation.mutateAsync(applicant.id)
        toast.success("Pelamar diaktifkan", "Akun dapat login kembali")
      }
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error("Gagal", res?.response?.data?.detail ?? "Coba lagi nanti")
    }
  }

  const handleSendVerification = async () => {
    try {
      await sendVerificationMutation.mutateAsync(applicant.id)
      toast.success(
        "Email terkirim",
        "Email verifikasi telah dikirim ke " + applicant.email
      )
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error("Gagal mengirim", res?.response?.data?.detail ?? "Coba lagi nanti")
    }
  }

  const handleSendPasswordReset = async () => {
    try {
      await sendPasswordResetMutation.mutateAsync(applicant.id)
      toast.success(
        "Email terkirim",
        "Email reset password telah dikirim ke " + applicant.email
      )
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error("Gagal mengirim", res?.response?.data?.detail ?? "Coba lagi nanti")
    }
  }

  return (
    <div className="flex flex-col gap-6">
      {/* Status: Aktif / Nonaktif */}
      <Card>
        <CardHeader>
          <CardTitle>Status Akun</CardTitle>
          <CardDescription>
            {applicant.is_active
              ? "Akun aktif dan dapat login"
              : "Akun nonaktif dan tidak dapat login"}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button
            type="button"
            variant={applicant.is_active ? "destructive" : "default"}
            className={
              applicant.is_active
                ? "cursor-pointer"
                : "cursor-pointer border-green-600 bg-green-600 hover:bg-green-700 hover:text-white"
            }
            onClick={handleToggleActive}
            disabled={
              deactivateMutation.isPending || activateMutation.isPending
            }
          >
            {applicant.is_active ? "Nonaktifkan" : "Aktifkan"}
          </Button>
        </CardContent>
      </Card>

      {/* Send email verification */}
      <Card>
        <CardHeader>
          <CardTitle>Email Verifikasi</CardTitle>
          <CardDescription>
            Kirim email verifikasi ke {applicant.email}. Hanya untuk akun yang
            belum terverifikasi.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="cursor-pointer"
            onClick={handleSendVerification}
            disabled={
              applicant.email_verified || sendVerificationMutation.isPending
            }
          >
            <IconMail className="mr-2 size-4" />
            Kirim Email Verifikasi
          </Button>
        </CardContent>
      </Card>

      {/* Send password reset */}
      <Card>
        <CardHeader>
          <CardTitle>Reset Password</CardTitle>
          <CardDescription>
            Kirim email reset password ke {applicant.email}. Pengguna akan
            menerima tautan untuk mengganti password.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="cursor-pointer"
            onClick={handleSendPasswordReset}
            disabled={sendPasswordResetMutation.isPending}
          >
            <IconKey className="mr-2 size-4" />
            Kirim Email Reset Password
          </Button>
        </CardContent>
      </Card>
    </div>
  )
}

export function AdminPelamarDetailPage() {
  const { id } = useParams<{ id: string }>()
  const applicantId = id ? parseInt(id, 10) : null

  usePageTitle("Detail Pelamar")

  const { data: applicant, isLoading, isError } = useApplicantQuery(
    applicantId,
    !!applicantId
  )
  const updateMutation = useUpdateApplicantMutation(applicantId ?? 0)

  const handleBiodataSubmit = async (
    data: Parameters<typeof updateMutation.mutateAsync>[0]["applicant_profile"]
  ) => {
    try {
      await updateMutation.mutateAsync({
        applicant_profile: data,
      })
      toast.success("Biodata diperbarui")
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
        const msgs: string[] = []
        Object.entries(errors).forEach(([key, value]) => {
          if (
            key === "applicant_profile" &&
            value &&
            typeof value === "object" &&
            !Array.isArray(value)
          ) {
            // Flatten nested applicant_profile errors like { birth_date: ["..."], nik: ["..."] }
            Object.entries(value as Record<string, unknown>).forEach(
              ([subKey, subVal]) => {
                const arr = Array.isArray(subVal) ? subVal : [subVal]
                arr.forEach((m) => msgs.push(`${subKey}: ${String(m)}`))
              }
            )
          } else {
            const arr = Array.isArray(value) ? value : [value]
            arr.forEach((m) => msgs.push(`${key}: ${String(m)}`))
          }
        })
        toast.error("Validasi gagal", msgs.join(". "))
      } else {
        toast.error("Gagal menyimpan", detail ?? "Coba lagi nanti")
      }
    }
  }

  if (isLoading || !applicantId) {
    return (
      <div className="flex min-h-[200px] items-center justify-center px-6 py-8">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    )
  }

  if (isError || !applicant) {
    return (
      <div className="px-6 py-8">
        <p className="text-destructive">Pelamar tidak ditemukan.</p>
        <Button variant="link" asChild>
          <Link to={BASE_PATH}>Kembali ke daftar</Link>
        </Button>
      </div>
    )
  }

  const profile = applicant.applicant_profile
  const displayName = profile?.full_name || applicant.email
  const score = profile?.score

  return (
    <div className="w-full px-6 py-6 md:px-8 md:py-8">
      <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex flex-col gap-2">
          <BreadcrumbNav
            items={[
              { label: "Dashboard", href: "/" },
              { label: "Daftar Pelamar", href: BASE_PATH },
              { label: displayName },
            ]}
          />
          <h1 className="text-2xl font-bold">{displayName}</h1>
          <p className="text-muted-foreground">
            {applicant.email}
            {profile?.nik && ` • NIK: ${profile.nik}`}
          </p>
          {typeof score === "number" && (
            <p className="text-sm text-muted-foreground">
              Skor kesiapan: {Math.round(score)} / 100
            </p>
          )}
        </div>
        <Button variant="ghost" size="sm" className="w-fit cursor-pointer" asChild>
          <Link to={BASE_PATH}>
            <IconArrowLeft className="mr-2 size-4" />
            Kembali
          </Link>
        </Button>
      </div>

      <Tabs defaultValue="biodata" className="space-y-6">
        <TabsList className="justify-start">
          <TabsTrigger value="biodata" className="cursor-pointer">
            Biodata
          </TabsTrigger>
          <TabsTrigger value="pengalaman" className="cursor-pointer">
            Pengalaman Kerja
          </TabsTrigger>
          <TabsTrigger value="dokumen" className="cursor-pointer">
            Dokumen
          </TabsTrigger>
        </TabsList>

        <TabsContent value="biodata" className="mt-6">
          <div className="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,1.2fr)]">
            <div>
              <ApplicantBiodataTab
                profile={profile}
                onSubmit={handleBiodataSubmit}
                isSubmitting={updateMutation.isPending}
              />
            </div>
            <div className="flex flex-col gap-6">
              <ApplicantSidebar applicant={applicant} />
              <ApplicantMetadataTab applicant={applicant} />
            </div>
          </div>
        </TabsContent>

        <TabsContent value="pengalaman">
          <ApplicantWorkExperienceTab applicantId={applicant.id} />
        </TabsContent>

        <TabsContent value="dokumen">
          <ApplicantDocumentsTab applicantId={applicant.id} />
        </TabsContent>
      </Tabs>
    </div>
  )
}
