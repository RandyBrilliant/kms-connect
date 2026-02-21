/**
 * Staff applicant detail page - shows detailed information about a referred applicant (read-only).
 */

import { useParams, Link, useNavigate } from "react-router-dom"
import { IconArrowLeft, IconUser, IconPhone, IconCalendar } from "@tabler/icons-react"
import { format } from "date-fns"
import { id } from "date-fns/locale"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { useStaffReferredApplicantQuery } from "@/hooks/use-staff-self-service-query"
import { usePageTitle } from "@/hooks/use-page-title"

function formatDate(value: string | null | undefined) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy", { locale: id })
}

function verificationStatusLabel(status: string) {
  switch (status) {
    case "DRAFT":
      return "Draf"
    case "SUBMITTED":
      return "Dikirim"
    case "ACCEPTED":
      return "Diterima"
    case "REJECTED":
      return "Ditolak"
    default:
      return status
  }
}

function verificationStatusVariant(status: string) {
  switch (status) {
    case "DRAFT":
      return "outline"
    case "SUBMITTED":
      return "secondary"
    case "ACCEPTED":
      return "default"
    case "REJECTED":
      return "destructive"
    default:
      return "outline"
  }
}

function InfoRow({ label, value }: { label: string; value: string | null | undefined }) {
  return (
    <div className="flex flex-col gap-1 @lg/card:flex-row @lg/card:items-start">
      <span className="text-muted-foreground min-w-[140px] text-sm">{label}</span>
      <span className="font-medium text-sm">{value || "-"}</span>
    </div>
  )
}

export function StaffApplicantDetailPage() {
  const { id: applicantId } = useParams()
  const navigate = useNavigate()
  const { data: applicant, isLoading, isError } = useStaffReferredApplicantQuery(Number(applicantId))

  usePageTitle(applicant ? `Detail Pelamar - ${applicant.applicant_profile?.full_name || applicant.email}` : "Detail Pelamar")

  if (isLoading) {
    return (
      <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
        <Button variant="ghost" size="sm" onClick={() => navigate(-1)} className="w-fit">
          <IconArrowLeft className="size-4" />
          Kembali
        </Button>
        <p className="text-muted-foreground">Memuat data pelamar...</p>
      </div>
    )
  }

  if (isError || !applicant) {
    return (
      <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
        <Button variant="ghost" size="sm" onClick={() => navigate(-1)} className="w-fit">
          <IconArrowLeft className="size-4" />
          Kembali
        </Button>
        <p className="text-destructive">Gagal memuat data pelamar.</p>
      </div>
    )
  }

  const profile = applicant.applicant_profile

  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:gap-6 md:px-8 md:py-8">
      {/* Header */}
      <div className="flex flex-col gap-4 @xl/main:flex-row @xl/main:items-center @xl/main:justify-between">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="sm" onClick={() => navigate(-1)}>
            <IconArrowLeft className="size-4" />
            Kembali
          </Button>
          <div>
            <h1 className="text-2xl font-bold">
              {profile?.full_name || applicant.email}
            </h1>
            <p className="text-muted-foreground text-sm">Detail informasi pelamar rujukan</p>
          </div>
        </div>
        {profile?.verification_status && (
          <Badge variant={verificationStatusVariant(profile.verification_status)} className="w-fit">
            {verificationStatusLabel(profile.verification_status)}
          </Badge>
        )}
      </div>

      {/* Account Information */}
      <Card className="@container/card">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <IconUser className="size-5" />
            Informasi Akun
          </CardTitle>
          <CardDescription>Data akun pengguna pelamar</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <InfoRow label="Email" value={applicant.email} />
          <InfoRow label="Nama Lengkap" value={profile?.full_name} />
          <InfoRow label="Status Aktif" value={applicant.is_active ? "Aktif" : "Nonaktif"} />
          <InfoRow label="Tanggal Terdaftar" value={formatDate(applicant.date_joined)} />
        </CardContent>
      </Card>

      {/* Personal Data */}
      <Card className="@container/card">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <IconCalendar className="size-5" />
            Data Pribadi
          </CardTitle>
          <CardDescription>Informasi pribadi pelamar</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <InfoRow label="NIK" value={profile?.nik} />
          <InfoRow label="Jenis Kelamin" value={profile?.gender} />
          <InfoRow label="Tempat Lahir" value={profile?.birth_place?.toString()} />
          <InfoRow label="Tanggal Lahir" value={formatDate(profile?.birth_date)} />
          <InfoRow label="Agama" value={profile?.religion} />
        </CardContent>
      </Card>

      {/* Contact Information */}
      <Card className="@container/card">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <IconPhone className="size-5" />
            Informasi Kontak
          </CardTitle>
          <CardDescription>Data kontak pelamar</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <InfoRow label="No. Telepon" value={profile?.contact_phone} />
          <InfoRow label="Email" value={applicant.email} />
          <InfoRow label="Alamat" value={profile?.address} />
          <InfoRow label="Provinsi" value={profile?.village_display?.province} />
          <InfoRow label="Kota/Kabupaten" value={profile?.village_display?.regency} />
          <InfoRow label="Kecamatan" value={profile?.village_display?.district} />
          <InfoRow label="Kelurahan" value={profile?.village_display?.village} />
        </CardContent>
      </Card>

      {/* Education & Skills */}
      <Card className="@container/card">
        <CardHeader>
          <CardTitle>Pendidikan & Keterampilan</CardTitle>
          <CardDescription>Latar belakang pendidikan dan keterampilan</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <InfoRow label="Pendidikan Terakhir" value={profile?.education_level} />
          <InfoRow label="Jurusan" value={profile?.education_major} />
        </CardContent>
      </Card>

      {/* Additional Information */}
      <Card className="@container/card">
        <CardHeader>
          <CardTitle>Informasi Tambahan</CardTitle>
          <CardDescription>Detail lainnya tentang pelamar</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <InfoRow label="Tinggi Badan (cm)" value={profile?.height_cm?.toString()} />
          <InfoRow label="Berat Badan (kg)" value={profile?.weight_kg?.toString()} />
          <InfoRow label="Memakai Kacamata" value={profile?.wears_glasses ? "Ya" : "Tidak"} />
        </CardContent>
      </Card>

      {/* Quick Actions */}
      <Card>
        <CardHeader>
          <CardTitle>Aksi Cepat</CardTitle>
          <CardDescription>Tindakan terkait pelamar ini</CardDescription>
        </CardHeader>
        <CardContent className="flex flex-wrap gap-2">
          <Button variant="outline" asChild>
            <Link to="/staff/pelamar">
              Kembali ke Daftar Pelamar
            </Link>
          </Button>
          <Button variant="outline" asChild>
            <Link to="/staff/laporan">
              Lihat Laporan
            </Link>
          </Button>
        </CardContent>
      </Card>
    </div>
  )
}
