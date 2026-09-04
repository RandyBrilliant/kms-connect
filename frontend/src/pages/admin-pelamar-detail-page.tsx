/**
 * Pelamar detail page with tabs: Biodata, Pengalaman Kerja, Dokumen, Lamaran.
 * Metadata & account actions are shown on the Biodata tab sidebar.
 * Lamaran tab lists applications and supports quick assign to an OPEN job batch.
 */

import { useNavigate, useParams } from "react-router-dom"
import { useEffect, useState } from "react"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import {
  IconArrowLeft,
  IconMail,
  IconKey,
  IconAlertCircle,
  IconFileTypePdf,
  IconTrash,
} from "@tabler/icons-react"

import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Textarea } from "@/components/ui/textarea"
import { ApplicantBiodataTab } from "@/components/applicants/applicant-biodata-tab"
import { ApplicantWorkExperienceTab } from "@/components/applicants/applicant-work-experience-tab"
import { ApplicantDocumentsTab } from "@/components/applicants/applicant-documents-tab"
import { ApplicantAdminProcessTab } from "../components/applicants/applicant-admin-process-tab"
import { ApplicantApplicationsTab } from "@/components/applicants/applicant-applications-tab"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  useApplicantQuery,
  useUpdateApplicantMutation,
  useDeactivateApplicantMutation,
  useActivateApplicantMutation,
  useSendVerificationEmailMutation,
  useSendPasswordResetMutation,
  useSendSubmissionSummaryMutation,
  usePermanentDeleteApplicantMutation,
} from "@/hooks/use-applicants-query"
import { toast } from "@/lib/toast"
import {
  viewBiodataPdf,
  viewCvPdf,
  viewInbondPdf,
  viewMedicalReferralPdf,
  viewPsychologyReferralPdf,
} from "@/api/applicants"
import type {
  ApplicantUser,
  ApplicantVerificationStatus,
  ApplicantProfile,
  ScoreBreakdown,
} from "@/types/applicant"
import { usePageTitle } from "@/hooks/use-page-title"
import {
  joinAdminPath,
  useAdminDashboard,
} from "@/contexts/admin-dashboard-context"
import { useAuth } from "@/hooks/use-auth"
import { isMasterAdmin, isRestrictedAdmin, type UserRole } from "@/types/auth"
import { goBackOrDefault } from "@/lib/back-navigation"

function ApplicantSidebar({
  applicant,
  hideAccountToggle,
  canSendSubmissionSummary,
}: {
  applicant: ApplicantUser
  hideAccountToggle?: boolean
  canSendSubmissionSummary?: boolean
}) {
  const deactivateMutation = useDeactivateApplicantMutation()
  const activateMutation = useActivateApplicantMutation()
  const sendVerificationMutation = useSendVerificationEmailMutation()
  const sendPasswordResetMutation = useSendPasswordResetMutation()
  const updateMutation = useUpdateApplicantMutation(applicant.id)
  const sendSubmissionSummaryMutation = useSendSubmissionSummaryMutation()

  const [isViewingPdf, setIsViewingPdf] = useState(false)
  const [isViewingCvPdf, setIsViewingCvPdf] = useState(false)
  const [isViewingInbond, setIsViewingInbond] = useState(false)
  const [isViewingPsychReferral, setIsViewingPsychReferral] = useState(false)
  const [isViewingMedicalReferral, setIsViewingMedicalReferral] = useState(false)
  const [sendSummaryDialogOpen, setSendSummaryDialogOpen] = useState(false)

  const handleViewBiodataPdf = async () => {
    setIsViewingPdf(true)
    try {
      await viewBiodataPdf(applicant.id)
    } catch {
      toast.error("Gagal membuka PDF", "Coba lagi nanti")
    } finally {
      setIsViewingPdf(false)
    }
  }

  const handleViewCvPdf = async () => {
    setIsViewingCvPdf(true)
    try {
      await viewCvPdf(applicant.id)
    } catch {
      toast.error("Gagal membuka CV PDF", "Coba lagi nanti")
    } finally {
      setIsViewingCvPdf(false)
    }
  }

  const handleViewInbondPdf = async () => {
    setIsViewingInbond(true)
    try {
      await viewInbondPdf(applicant.id)
    } catch {
      toast.error("Gagal membuka PDF Inbond Cost", "Coba lagi nanti")
    } finally {
      setIsViewingInbond(false)
    }
  }

  const handleViewPsychologyReferralPdf = async () => {
    setIsViewingPsychReferral(true)
    try {
      await viewPsychologyReferralPdf(applicant.id)
    } catch {
      toast.error("Gagal membuka PDF pengantar psikologi", "Coba lagi nanti")
    } finally {
      setIsViewingPsychReferral(false)
    }
  }

  const handleViewMedicalReferralPdf = async () => {
    setIsViewingMedicalReferral(true)
    try {
      await viewMedicalReferralPdf(applicant.id)
    } catch {
      toast.error("Gagal membuka PDF pengantar medical", "Coba lagi nanti")
    } finally {
      setIsViewingMedicalReferral(false)
    }
  }

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

  const profile = applicant.applicant_profile
  const [keteranganNotes, setKeteranganNotes] = useState(profile?.notes ?? "")
  const scoreBreakdown = (profile?.score_breakdown ?? {}) as Partial<ScoreBreakdown>
  const missingProfileFields = scoreBreakdown.profile_missing_fields ?? []
  const missingDocCodes = scoreBreakdown.missing_required_document_codes ?? []
  const isAccepted = profile?.verification_status === "ACCEPTED"
  const hasMissingData = missingProfileFields.length > 0 || missingDocCodes.length > 0

  useEffect(() => {
    // Keep textarea in sync when applicant changes or after save refetches.
    setKeteranganNotes(profile?.notes ?? "")
  }, [profile?.notes, applicant.id])

  const VERIFICATION_LABELS: Record<ApplicantVerificationStatus, string> = {
    SUBMITTED: "Dikirim",
    ACCEPTED: "Diterima",
    REJECTED: "Ditolak",
  }

  const ADMIN_SETTABLE_STATUSES = [
    "SUBMITTED",
    "ACCEPTED",
    "REJECTED",
  ] as const satisfies readonly ApplicantVerificationStatus[]

  const handleStatusChange = async (value: ApplicantVerificationStatus) => {
    if (!profile || value === profile.verification_status) return

    try {
      await updateMutation.mutateAsync({
        applicant_profile: {
          verification_status: value,
        },
      })
      toast.success("Status verifikasi diperbarui")
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
        toast.error("Gagal", detail ?? "Coba lagi nanti")
      }
    }
  }

  const prettyFieldLabels: Record<string, string> = {
    "user.full_name": "Nama Lengkap",
    nik: "NIK",
    birth_date: "Tanggal Lahir",
    gender: "Jenis Kelamin",
    address: "Alamat",
    postal_code: "Kode Pos",
    contact_phone: "No. HP / WA",
    province_id: "Provinsi (alamat KTP)",
    district_id: "Kota / Kabupaten (alamat KTP)",
    village_id: "Kelurahan / Desa (alamat KTP)",
    education_level: "Pendidikan Terakhir",
    marital_status: "Status Perkawinan",
    // Data pribadi tambahan
    registration_date: "Tanggal Pendaftaran",
    destination_country: "Negara Tujuan",
    sibling_count: "Jumlah Saudara",
    birth_order: "Anak ke-",
    religion: "Agama",
    education_major: "Jurusan Pendidikan",
    data_declaration_confirmed: "Pernyataan Data Benar",
    // Ciri fisik
    height_cm: "Tinggi Badan (cm)",
    weight_kg: "Berat Badan (kg)",
    wears_glasses: "Memakai Kacamata",
    writing_hand: "Tangan yang Digunakan untuk Menulis",
    shoe_size: "Ukuran Sepatu",
    shirt_size: "Ukuran Baju",
    family_postal_code: "Kode Pos Keluarga",
    // Data paspor
    passport_number: "Nomor Paspor",
    passport_issue_date: "Tanggal Terbit Paspor",
    passport_issue_place: "Tempat Terbit Paspor",
    passport_expiry_date: "Tanggal Kadaluarsa Paspor",
    // Informasi rujukan
    referrer_id: "Informasi Rujukan (Perujuk)",
    // Kelompok data
    parent_info: "Data Orang Tua (Ayah/Ibu)",
    heir_info: "Data Ahli Waris",
  }

  const prettyDocumentLabels: Record<string, string> = {
    "ktp": "KTP",
    "kartu-keluarga": "Kartu Keluarga",
    "ijasah": "Ijazah",
    "kartu-bpjs": "Kartu BPJS Kesehatan",
    "paspor": "Paspor",
    "pas-foto": "Pas Foto",
  }

  return (
    <div className="flex flex-col gap-6">
      {/* Skor kesiapan & data yang belum lengkap */}
      {profile && (
          <Card>
            <CardHeader className="pb-3">
              <div className="flex items-center justify-between gap-2">
                <CardTitle className="flex items-center gap-2 text-sm">
                  <IconAlertCircle className="size-4 text-amber-500" />
                  Ringkasan Kesiapan
                </CardTitle>
                <span className="rounded-full bg-primary/10 px-3 py-1 text-xs font-medium text-primary">
                  Skor {Math.round(applicant.applicant_profile.score ?? scoreBreakdown.score ?? 0)} / 100
                </span>
              </div>
              <CardDescription className="mt-1 text-xs">
                Bidang biodata dan dokumen yang masih belum lengkap.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="space-y-2 border-b pb-3">
                <p className="text-xs font-medium text-foreground">Status Verifikasi</p>
                <p className="text-xs text-muted-foreground">
                  Dikirim = menunggu verifikasi. Diterima/Ditolak = hasil verifikasi.
                </p>
                <div className="flex flex-wrap items-center gap-3">
                  <span className="text-muted-foreground text-xs">Status saat ini:</span>
                  <Select
                    value={profile.verification_status}
                    onValueChange={(v) => handleStatusChange(v as ApplicantVerificationStatus)}
                    disabled={updateMutation.isPending}
                  >
                    <SelectTrigger
                      className="w-[180px] cursor-pointer"
                      disabled={updateMutation.isPending}
                    >
                      <SelectValue>
                        {updateMutation.isPending
                          ? "Menyimpan..."
                          : VERIFICATION_LABELS[profile.verification_status]}
                      </SelectValue>
                    </SelectTrigger>
                    <SelectContent>
                      {ADMIN_SETTABLE_STATUSES.map((val) => (
                        <SelectItem key={val} value={val}>
                          {VERIFICATION_LABELS[val]}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>

              {missingProfileFields.length ? (
                <div className="space-y-1">
                  <p className="text-xs font-medium text-foreground">
                    Biodata belum lengkap:
                  </p>
                  <ul className="list-disc space-y-0.5 pl-4 text-xs text-muted-foreground">
                    {missingProfileFields.map((field) => {
                      const label = prettyFieldLabels[field] ?? field
                      return <li key={field}>{label}</li>
                    })}
                  </ul>
                </div>
              ) : null}

              {missingDocCodes.length ? (
                <div className="space-y-1">
                  <p className="text-xs font-medium text-foreground">
                    Dokumen wajib belum lengkap:
                  </p>
                  <ul className="list-disc space-y-0.5 pl-4 text-xs text-muted-foreground">
                    {missingDocCodes.map((code) => {
                      const label = prettyDocumentLabels[code] ?? code.toUpperCase()
                      return <li key={code}>{label}</li>
                    })}
                  </ul>
                </div>
              ) : null}

              {!missingProfileFields.length && !missingDocCodes.length ? (
                <p className="text-xs text-muted-foreground">
                  Tidak ada kekurangan data yang terdeteksi untuk perhitungan skor.
                </p>
              ) : null}

              {/* Admin-only: send applicant submission summary */}
              {canSendSubmissionSummary && (
                <div className="pt-1">
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    className="cursor-pointer"
                    onClick={() => setSendSummaryDialogOpen(true)}
                    disabled={
                      sendSubmissionSummaryMutation.isPending ||
                      isAccepted ||
                      !hasMissingData
                    }
                  >
                    {isAccepted ? "Sudah Diterima" : "Kirim Ringkasan Pengisian"}
                  </Button>
                </div>
              )}
            </CardContent>
          </Card>
        )}

      {/* Keterangan (catatan tambahan) */}
      {profile && (
        <Card>
          <CardHeader>
            <CardTitle>Keterangan</CardTitle>
            <CardDescription>Catatan tambahan (III. Keterangan) untuk biodata CPMI.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <Textarea
              value={keteranganNotes}
              onChange={(e) => setKeteranganNotes(e.target.value)}
              placeholder="Masukkan keterangan tambahan (opsional)..."
              rows={5}
              disabled={updateMutation.isPending}
            />
            <div className="flex justify-end gap-2">
              <Button
                type="button"
                variant="default"
                className="cursor-pointer"
                disabled={
                  updateMutation.isPending || (keteranganNotes ?? "").trim() === (profile.notes ?? "").trim()
                }
                onClick={async () => {
                  try {
                    await updateMutation.mutateAsync({
                      applicant_profile: {
                        notes: keteranganNotes ?? "",
                      },
                    })
                    toast.success("Keterangan tersimpan", "Catatan tambahan berhasil diperbarui.")
                  } catch (err: unknown) {
                    const res = err as { response?: { data?: { detail?: string } } }
                    toast.error("Gagal menyimpan keterangan", res?.response?.data?.detail ?? "Coba lagi nanti")
                  }
                }}
              >
                {updateMutation.isPending ? "Menyimpan..." : "Simpan Keterangan"}
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Status: Aktif / Nonaktif — hanya Admin Utama */}
      {!hideAccountToggle && (
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
      )}

      {/* Login sosial (Google / Apple) */}
      <Card>
        <CardHeader>
          <CardTitle>Login sosial</CardTitle>
          <CardDescription>
            ID yang dipakai untuk Google Sign-In atau Apple (jika akun pernah dihubungkan).
          </CardDescription>
        </CardHeader>
        <CardContent>
          <dl className="space-y-3 text-xs">
            <div className="flex flex-col gap-1 sm:flex-row sm:items-start sm:justify-between sm:gap-2">
              <dt className="shrink-0 text-muted-foreground">Google Sign-In</dt>
              <dd className="min-w-0 break-all font-mono font-medium sm:text-right">
                {applicant.google_id?.trim() ? applicant.google_id : "—"}
              </dd>
            </div>
            <div className="flex flex-col gap-1 sm:flex-row sm:items-start sm:justify-between sm:gap-2">
              <dt className="shrink-0 text-muted-foreground">Apple Sign-In</dt>
              <dd className="min-w-0 break-all font-mono font-medium sm:text-right">
                {applicant.apple_id?.trim() ? applicant.apple_id : "—"}
              </dd>
            </div>
          </dl>
        </CardContent>
      </Card>

      {/* Metadata & audit info */}
      {profile && (
        <Card>
          <CardHeader>
            <CardTitle>Metadata</CardTitle>
            <CardDescription>Jejak waktu & aktivitas akun.</CardDescription>
          </CardHeader>
          <CardContent>
            <dl className="space-y-3 text-xs">
              <div className="flex items-center justify-between gap-2">
                <dt className="text-muted-foreground">Profil dibuat</dt>
                <dd className="font-medium">
                  {profile.created_at
                    ? format(new Date(profile.created_at), "dd MMM yyyy HH:mm", { locale: idLocale })
                    : "-"}
                </dd>
              </div>
              <div className="flex items-center justify-between gap-2">
                <dt className="text-muted-foreground">Profil diperbarui</dt>
                <dd className="font-medium">
                  {profile.updated_at
                    ? format(new Date(profile.updated_at), "dd MMM yyyy HH:mm", { locale: idLocale })
                    : "-"}
                </dd>
              </div>
              <div className="flex items-center justify-between gap-2">
                <dt className="text-muted-foreground">User bergabung</dt>
                <dd className="font-medium">
                  {applicant.date_joined
                    ? format(new Date(applicant.date_joined), "dd MMM yyyy HH:mm", { locale: idLocale })
                    : "-"}
                </dd>
              </div>
              <div className="flex items-center justify-between gap-2">
                <dt className="text-muted-foreground">Dikirim untuk verifikasi</dt>
                <dd className="font-medium">
                  {profile.submitted_at
                    ? format(new Date(profile.submitted_at), "dd MMM yyyy HH:mm", { locale: idLocale })
                    : "-"}
                </dd>
              </div>
              <div className="flex items-center justify-between gap-2">
                <dt className="text-muted-foreground">Diverifikasi pada</dt>
                <dd className="font-medium">
                  {profile.verified_at
                    ? format(new Date(profile.verified_at), "dd MMM yyyy HH:mm", { locale: idLocale })
                    : "-"}
                </dd>
              </div>
            </dl>
          </CardContent>
        </Card>
      )}

      <AlertDialog open={sendSummaryDialogOpen} onOpenChange={setSendSummaryDialogOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Kirim ringkasan ke pelamar?</AlertDialogTitle>
            <AlertDialogDescription asChild>
              <p className="text-muted-foreground">
                Notifikasi akan dikirim ke pelamar agar dapat melengkapi biodata dan dokumen yang
                masih kurang.
              </p>
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel
              type="button"
              className="cursor-pointer"
              disabled={sendSubmissionSummaryMutation.isPending}
            >
              Batal
            </AlertDialogCancel>
            <Button
              type="button"
              variant="default"
              className="cursor-pointer"
              disabled={sendSubmissionSummaryMutation.isPending}
              onClick={async () => {
                try {
                  await sendSubmissionSummaryMutation.mutateAsync(applicant.id)
                  toast.success("Ringkasan terkirim", "Notifikasi telah dikirim ke pelamar.")
                  setSendSummaryDialogOpen(false)
                } catch (err: unknown) {
                  const res = err as { response?: { data?: { detail?: string } } }
                  toast.error("Gagal mengirim ringkasan", res?.response?.data?.detail ?? "Coba lagi nanti")
                }
              }}
            >
              {sendSubmissionSummaryMutation.isPending ? "Mengirim..." : "Kirim"}
            </Button>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

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

      {/* Download Biodata PDF */}
      <Card>
        <CardHeader>
          <CardTitle>Biodata PDF</CardTitle>
          <CardDescription>
            Buka formulir biodata CPMI yang sudah terisi dalam tab baru.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="cursor-pointer"
            onClick={handleViewBiodataPdf}
            disabled={isViewingPdf}
          >
            <IconFileTypePdf className="mr-2 size-4" />
            {isViewingPdf ? "Memproses..." : "Lihat Biodata PDF"}
          </Button>
        </CardContent>
      </Card>

      {/* Download CV PDF */}
      <Card>
        <CardHeader>
          <CardTitle>CV PDF</CardTitle>
          <CardDescription>
            Buka daftar riwayat hidup resmi yang sudah terisi, termasuk pas foto.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="cursor-pointer"
            onClick={handleViewCvPdf}
            disabled={isViewingCvPdf}
          >
            <IconFileTypePdf className="mr-2 size-4" />
            {isViewingCvPdf ? "Memproses..." : "Lihat CV PDF"}
          </Button>
        </CardContent>
      </Card>

      {/* Inbond Cost PDF */}
      <Card>
        <CardHeader>
          <CardTitle>Inbond Cost PDF</CardTitle>
          <CardDescription>
            Tanda terima pengembalian biaya transportasi CPMI.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="cursor-pointer"
            onClick={handleViewInbondPdf}
            disabled={isViewingInbond}
          >
            <IconFileTypePdf className="mr-2 size-4" />
            {isViewingInbond ? "Memproses..." : "Lihat Inbond Cost PDF"}
          </Button>
        </CardContent>
      </Card>

      {/* Surat Pengantar Tes Psikologi */}
      <Card>
        <CardHeader>
          <CardTitle>Pengantar tes psikologi</CardTitle>
          <CardDescription>
            Surat pengantar ke klinik untuk tes psikologi CPMI.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="cursor-pointer"
            onClick={handleViewPsychologyReferralPdf}
            disabled={isViewingPsychReferral}
          >
            <IconFileTypePdf className="mr-2 size-4" />
            {isViewingPsychReferral ? "Memproses..." : "Lihat PDF pengantar psikologi"}
          </Button>
        </CardContent>
      </Card>

      {/* Surat Pengantar Medical */}
      <Card>
        <CardHeader>
          <CardTitle>Pengantar medical check up</CardTitle>
          <CardDescription>
            Surat pengantar ke klinik untuk medical CPMI.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="cursor-pointer"
            onClick={handleViewMedicalReferralPdf}
            disabled={isViewingMedicalReferral}
          >
            <IconFileTypePdf className="mr-2 size-4" />
            {isViewingMedicalReferral ? "Memproses..." : "Lihat PDF pengantar medical"}
          </Button>
        </CardContent>
      </Card>
    </div>
  )
}

export function AdminPelamarDetailPage() {
  const { id } = useParams<{ id: string }>()
  const applicantId = id ? parseInt(id, 10) : null
  const { basePath } = useAdminDashboard()
  const { user } = useAuth()
  const navigate = useNavigate()
  const BASE_PATH = joinAdminPath(basePath, "/pelamar")
  const handleBack = () => goBackOrDefault(navigate, BASE_PATH)

  const lamaranBase = joinAdminPath(basePath, "/lamaran")
  const hideAccountToggle = user
    ? isRestrictedAdmin(user.role as UserRole)
    : false
  const canPermanentDelete = !!user && (isMasterAdmin(user.role as UserRole) || isRestrictedAdmin(user.role as UserRole))

  const canSendSubmissionSummary = !!user && (isMasterAdmin(user.role as UserRole) || isRestrictedAdmin(user.role as UserRole))

  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const permanentDeleteMutation = usePermanentDeleteApplicantMutation()

  usePageTitle("Detail Pelamar")

  const { data: applicant, isLoading, isError } = useApplicantQuery(
    applicantId,
    !!applicantId
  )
  const updateMutation = useUpdateApplicantMutation(applicantId ?? 0)

  const scrollToTop = () => {
    window.scrollTo({ top: 0, behavior: "smooth" })
  }

  const handleBiodataSubmit = async (
    data: Parameters<typeof updateMutation.mutateAsync>[0]["applicant_profile"]
  ) => {
    try {
      await updateMutation.mutateAsync({
        applicant_profile: data,
      })
      toast.success("Biodata diperbarui")
      scrollToTop()
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

  const handleConfirmPermanentDelete = async () => {
    if (!applicantId) return
    try {
      await permanentDeleteMutation.mutateAsync(applicantId)
      toast.success(
        "Pelamar dihapus",
        "Akun dan seluruh data terkait telah dihapus permanen."
      )
      setDeleteDialogOpen(false)
      navigate(BASE_PATH)
    } catch (err: unknown) {
      const res = err as { response?: { data?: { detail?: string } } }
      toast.error(
        "Gagal menghapus",
        res?.response?.data?.detail ?? "Coba lagi nanti"
      )
    }
  }

  if (isLoading || !applicantId) {
    return (
      <div className="flex min-h-50 items-center justify-center px-6 py-8">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    )
  }

  if (isError || !applicant) {
    return (
      <div className="px-6 py-8">
        <p className="text-destructive">Pelamar tidak ditemukan.</p>
        <Button variant="link" onClick={handleBack}>
          Kembali ke daftar
        </Button>
      </div>
    )
  }

  const profile = applicant.applicant_profile
  const displayName = profile?.full_name || applicant.email

  return (
    <div className="w-full px-6 py-6 md:px-8 md:py-8">
      <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex flex-col gap-2">
          <BreadcrumbNav
            items={[
              { label: "Dashboard", href: basePath || "/" },
              { label: "Daftar Pelamar", href: BASE_PATH },
              { label: displayName },
            ]}
          />
          <h1 className="text-2xl font-bold">{displayName}</h1>
          <p className="text-muted-foreground">
            {applicant.email}
            {profile?.nik && ` • NIK: ${profile.nik}`}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          {canPermanentDelete && (
            <Button
              type="button"
              variant="destructive"
              size="sm"
              className="cursor-pointer"
              onClick={() => setDeleteDialogOpen(true)}
            >
              <IconTrash className="mr-2 size-4" />
              Hapus pelamar
            </Button>
          )}
          <Button
            variant="ghost"
            size="sm"
            className="w-fit cursor-pointer"
            onClick={handleBack}
          >
            <IconArrowLeft className="mr-2 size-4" />
            Kembali
          </Button>
        </div>
      </div>

      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Hapus pelamar permanen?</AlertDialogTitle>
            <AlertDialogDescription asChild>
              <div className="space-y-3 text-muted-foreground text-sm">
                <p>
                  Tindakan ini tidak dapat dibatalkan. Seluruh data yang terhubung ke{" "}
                  <span className="font-medium text-foreground">{displayName}</span> akan
                  dihapus, termasuk:
                </p>
                <ul className="list-disc space-y-1 pl-4">
                  <li>Akun login dan profil biodata</li>
                  <li>Dokumen unggahan (berkas disimpan ikut dihapus)</li>
                  <li>Riwayat pengalaman kerja</li>
                  <li>Semua lamaran, status batch, dan riwayat tahapan</li>
                  <li>Pesan chat pada setiap lamaran</li>
                  <li>Notifikasi dan preferensi notifikasi akun ini</li>
                  <li>Permintaan penghapusan akun (jika ada)</li>
                </ul>
              </div>
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel
              type="button"
              className="cursor-pointer"
              disabled={permanentDeleteMutation.isPending}
            >
              Batal
            </AlertDialogCancel>
            <Button
              type="button"
              variant="destructive"
              className="cursor-pointer"
              disabled={permanentDeleteMutation.isPending}
              onClick={handleConfirmPermanentDelete}
            >
              {permanentDeleteMutation.isPending ? "Menghapus..." : "Ya, hapus semuanya"}
            </Button>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <Tabs defaultValue="biodata" className="space-y-6">
        <TabsList className="justify-start">
          <TabsTrigger value="biodata" className="cursor-pointer">
            Biodata
          </TabsTrigger>
          <TabsTrigger value="admin-data" className="cursor-pointer">
            Data Proses
          </TabsTrigger>
          <TabsTrigger value="pengalaman" className="cursor-pointer">
            Pengalaman Kerja
          </TabsTrigger>
          <TabsTrigger value="dokumen" className="cursor-pointer">
            Dokumen
          </TabsTrigger>
          <TabsTrigger value="lamaran" className="cursor-pointer">
            Lamaran
          </TabsTrigger>
        </TabsList>

        <TabsContent value="biodata" className="mt-6">
          <div className="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,1.2fr)]">
            <div>
              <ApplicantBiodataTab
                profile={profile}
                onSubmit={handleBiodataSubmit}
                isSubmitting={updateMutation.isPending}
                hideNotesField
              />
            </div>
            <div className="flex flex-col gap-6">
              <ApplicantSidebar
                applicant={applicant}
                hideAccountToggle={hideAccountToggle}
                canSendSubmissionSummary={canSendSubmissionSummary}
              />
            </div>
          </div>
        </TabsContent>

        <TabsContent value="admin-data">
          <ApplicantAdminProcessTab
            profile={profile}
            onSubmit={async (data: Partial<ApplicantProfile>) => {
              await updateMutation.mutateAsync({
                applicant_profile: data,
              })
              scrollToTop()
            }}
            isSubmitting={updateMutation.isPending}
          />
        </TabsContent>

        <TabsContent value="pengalaman">
          <ApplicantWorkExperienceTab applicantId={applicant.id} />
        </TabsContent>

        <TabsContent value="dokumen">
          <ApplicantDocumentsTab
            applicantId={applicant.id}
            fullName={profile?.full_name || applicant.email}
          />
        </TabsContent>

        <TabsContent value="lamaran">
          <ApplicantApplicationsTab
            profileId={applicant.applicant_profile?.id}
            lamaranBase={lamaranBase}
            basePath={basePath}
          />
        </TabsContent>
      </Tabs>
    </div>
  )
}
