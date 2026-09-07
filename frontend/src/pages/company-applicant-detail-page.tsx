/**
 * Company applicant detail page - read-only view of applicant details.
 */

import { useNavigate, useParams } from "react-router-dom"
import { IconArrowLeft, IconUser, IconPhone } from "@tabler/icons-react"
import { format } from "date-fns"
import { id } from "date-fns/locale"

import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { useCompanyApplicantQuery } from "@/hooks/use-company-self-service-query"
import { usePageTitle } from "@/hooks/use-page-title"
import { goBackOrDefault } from "@/lib/back-navigation"

function formatDate(value: string | null | undefined) {
  if (!value) return "-"
  return format(new Date(value), "dd MMMM yyyy", { locale: id })
}

function verificationStatusLabel(status: string) {
  switch (status) {
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

export function CompanyApplicantDetailPage() {
  const { id: applicantId } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const handleBack = () => goBackOrDefault(navigate, "/company/pelamar")
  const numericId = applicantId ? Number(applicantId) : null

  const { data: applicant, isLoading, isError } = useCompanyApplicantQuery(numericId)
  
  const profile = applicant?.applicant_profile

  usePageTitle(applicant ? `Detail ${profile?.full_name || applicant.email}` : "Detail Pelamar")

  if (isLoading) {
    return (
      <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
        <p>Memuat data...</p>
      </div>
    )
  }

  if (isError || !applicant) {
    return (
      <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
        <p className="text-destructive">Data pelamar tidak ditemukan.</p>
        <Button variant="outline" onClick={handleBack}>
          <IconArrowLeft className="size-4" />
          Kembali
        </Button>
      </div>
    )
  }

  return (
    <div className="w-full px-6 py-6 md:px-8 md:py-8">
      <div className="w-full max-w-4xl">
        <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div className="flex flex-col gap-2">
            <BreadcrumbNav
              items={[
                { label: "Dashboard", href: "/company" },
                { label: "Pelamar", href: "/company/pelamar" },
                { label: "Detail" },
              ]}
            />
            <h1 className="text-2xl font-bold">Detail Pelamar</h1>
            <p className="text-muted-foreground">
              Data lengkap pelamar (hanya tampilan).
            </p>
          </div>
          <Button variant="ghost" size="sm" onClick={handleBack}>
            <IconArrowLeft className="size-4" />
            Kembali
          </Button>
        </div>

        <div className="space-y-6">
          {/* Account Info */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <IconUser className="size-5" />
                Informasi Akun
              </CardTitle>
            </CardHeader>
            <CardContent className="grid gap-4 @xl/main:grid-cols-2">
              <div>
                <p className="text-muted-foreground text-sm">Email</p>
                <p className="font-medium">{applicant.email}</p>
              </div>
              <div>
                <p className="text-muted-foreground text-sm">Nama Lengkap</p>
                <p className="font-medium">{profile?.full_name || "-"}</p>
              </div>
              <div>
                <p className="text-muted-foreground text-sm">Status Akun</p>
                <Badge variant={applicant.is_active ? "default" : "secondary"}>
                  {applicant.is_active ? "Aktif" : "Nonaktif"}
                </Badge>
              </div>
              <div>
                <p className="text-muted-foreground text-sm">Email Terverifikasi</p>
                <Badge variant={applicant.email_verified ? "default" : "outline"}>
                  {applicant.email_verified ? "Terverifikasi" : "Belum Terverifikasi"}
                </Badge>
              </div>
              <div>
                <p className="text-muted-foreground text-sm">Terdaftar</p>
                <p className="font-medium">{formatDate(applicant.date_joined)}</p>
              </div>
              {profile && (
                <div>
                  <p className="text-muted-foreground text-sm">Status Verifikasi</p>
                  <Badge variant={verificationStatusVariant(profile.verification_status)}>
                    {verificationStatusLabel(profile.verification_status)}
                  </Badge>
                </div>
              )}
            </CardContent>
          </Card>

          {/* Profile Info */}
          {profile && (
            <>
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <IconUser className="size-5" />
                    Data Pribadi
                  </CardTitle>
                  <CardDescription>Informasi data diri pelamar</CardDescription>
                </CardHeader>
                <CardContent className="grid gap-4 @xl/main:grid-cols-2">
                  <div>
                    <p className="text-muted-foreground text-sm">NIK</p>
                    <p className="font-medium">{profile.nik || "-"}</p>
                  </div>
                  <div>
                    <p className="text-muted-foreground text-sm">Jenis Kelamin</p>
                    <p className="font-medium">
                      {profile.gender === "M" ? "Laki-laki" : profile.gender === "F" ? "Perempuan" : "-"}
                    </p>
                  </div>
                  <div>
                    <p className="text-muted-foreground text-sm">Tempat Lahir</p>
                    <p className="font-medium">
                      {(profile.birth_place_display ?? profile.birth_place_text) || "-"}
                    </p>
                  </div>
                  <div>
                    <p className="text-muted-foreground text-sm">Tanggal Lahir</p>
                    <p className="font-medium">{formatDate(profile.birth_date)}</p>
                  </div>
                  <div>
                    <p className="text-muted-foreground text-sm">Agama</p>
                    <p className="font-medium">{profile.religion || "-"}</p>
                  </div>
                  <div>
                    <p className="text-muted-foreground text-sm">Status Pernikahan</p>
                    <p className="font-medium">{profile.marital_status || "-"}</p>
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <IconPhone className="size-5" />
                    Kontak
                  </CardTitle>
                </CardHeader>
                <CardContent className="grid gap-4 @xl/main:grid-cols-2">
                  <div>
                    <p className="text-muted-foreground text-sm">Telepon</p>
                    <p className="font-medium">{profile.contact_phone || "-"}</p>
                  </div>
                  <div>
                    <p className="text-muted-foreground text-sm">Alamat Email</p>
                    <p className="font-medium">{applicant.email}</p>
                  </div>
                  <div className="@xl/main:col-span-2">
                    <p className="text-muted-foreground text-sm">Alamat Lengkap</p>
                    <p className="font-medium">{profile.address || "-"}</p>
                  </div>
                </CardContent>
              </Card>

            </>
          )}

          {!profile && (
            <Card>
              <CardContent className="py-8 text-center">
                <p className="text-muted-foreground">
                  Pelamar belum melengkapi profil.
                </p>
              </CardContent>
            </Card>
          )}
        </div>
      </div>
    </div>
  )
}
