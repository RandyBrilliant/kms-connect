import { Link } from "react-router-dom"
import { IconExternalLink } from "@tabler/icons-react"

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { useApplicantQuery } from "@/hooks/use-applicants-query"
import { getVerificationStatusLabel } from "@/constants/applicant"
import { formatDate } from "@/lib/formatters"
import { cn } from "@/lib/utils"

function FieldItem({
  label,
  value,
  className,
}: {
  label: string
  value: string | number | null | undefined
  className?: string
}) {
  const text = value == null || value === "" ? "-" : String(value)
  return (
    <div className={cn("space-y-1", className)}>
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="text-sm font-medium break-words">{text}</p>
    </div>
  )
}

function yesNo(value: boolean | null | undefined): string {
  if (value == null) return "-"
  return value ? "Ya" : "Tidak"
}

interface ApplicantDetailPreviewDialogProps {
  applicantUserId: number | null
  applicantLabel: string
  applicantDetailPath: string
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function ApplicantDetailPreviewDialog({
  applicantUserId,
  applicantLabel,
  applicantDetailPath,
  open,
  onOpenChange,
}: ApplicantDetailPreviewDialogProps) {
  const { data: applicant, isLoading } = useApplicantQuery(
    applicantUserId,
    open && applicantUserId != null
  )
  const profile = applicant?.applicant_profile
  const referrerName =
    profile?.referrer_display?.display_name ||
    profile?.referrer_display?.full_name ||
    "-"
  const referrerCode = profile?.referrer_display?.referral_code || "-"

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="w-[calc(100vw-1.5rem)] max-w-4xl p-0">
        <DialogHeader className="px-4 py-4 sm:px-6 sm:py-5 border-b">
          <DialogTitle>Detail Pelamar</DialogTitle>
          <DialogDescription>
            Preview data pelamar tanpa edit. Gunakan tombol edit untuk membuka halaman pelamar.
          </DialogDescription>
        </DialogHeader>

        <div className="max-h-[75vh] overflow-y-auto px-4 py-4 sm:px-6 sm:py-5 space-y-4">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <div className="h-7 w-7 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : !applicant || !profile ? (
            <p className="text-sm text-muted-foreground">
              Data pelamar tidak ditemukan untuk {applicantLabel || "pelamar ini"}.
            </p>
          ) : (
            <>
              <Card>
                <CardHeader className="pb-3">
                  <CardTitle className="text-base">Ringkasan</CardTitle>
                </CardHeader>
                <CardContent className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  <FieldItem label="Nama" value={profile.full_name} />
                  <FieldItem label="Email" value={applicant.email} />
                  <FieldItem label="NIK" value={profile.nik} />
                  <FieldItem label="Staff Rujukan" value={referrerName} />
                  <FieldItem label="Kode Rujukan" value={referrerCode} />
                  <FieldItem label="No. Register" value={profile.register_number} />
                  <FieldItem
                    label="Status Verifikasi"
                    value={getVerificationStatusLabel(profile.verification_status)}
                  />
                  <FieldItem label="No. HP / WA" value={profile.contact_phone} />
                  <FieldItem label="Skor Kesiapan" value={profile.score ?? "-"} />
                  <FieldItem
                    label="Tanggal Pendaftaran"
                    value={formatDate(profile.registration_date)}
                  />
                  <FieldItem label="Negara Tujuan" value={profile.destination_country} />
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="pb-3">
                  <CardTitle className="text-base">Data CPMI</CardTitle>
                </CardHeader>
                <CardContent className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  <FieldItem label="Tempat Lahir" value={profile.birth_place_display ?? "-"} />
                  <FieldItem label="Tanggal Lahir" value={formatDate(profile.birth_date)} />
                  <FieldItem label="Alamat" value={profile.address} className="lg:col-span-3" />
                  <FieldItem label="Provinsi" value={profile.village_display?.province ?? "-"} />
                  <FieldItem label="Kab/Kota" value={profile.village_display?.regency ?? "-"} />
                  <FieldItem label="Kecamatan" value={profile.village_display?.district ?? "-"} />
                  <FieldItem label="Kelurahan/Desa" value={profile.village_display?.village ?? "-"} />
                  <FieldItem label="Jumlah Saudara" value={profile.sibling_count} />
                  <FieldItem label="Anak ke-" value={profile.birth_order} />
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="pb-3">
                  <CardTitle className="text-base">Data Tambahan</CardTitle>
                </CardHeader>
                <CardContent className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  <FieldItem label="Agama" value={profile.religion} />
                  <FieldItem label="Pendidikan" value={profile.education_level} />
                  <FieldItem label="Jurusan" value={profile.education_major} />
                  <FieldItem label="Status Pernikahan" value={profile.marital_status} />
                  <FieldItem label="Tinggi Badan (cm)" value={profile.height_cm} />
                  <FieldItem label="Berat Badan (kg)" value={profile.weight_kg} />
                  <FieldItem label="Menulis dengan tangan" value={profile.writing_hand} />
                  <FieldItem label="Memakai kacamata" value={yesNo(profile.wears_glasses)} />
                  <FieldItem label="Ukuran sepatu" value={profile.shoe_size} />
                  <FieldItem label="Ukuran baju" value={profile.shirt_size} />
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="pb-3">
                  <CardTitle className="text-base">Orangtua / Keluarga</CardTitle>
                </CardHeader>
                <CardContent className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  <FieldItem label="Nama Ayah" value={profile.father_name} />
                  <FieldItem label="Umur Ayah" value={profile.father_age} />
                  <FieldItem label="Pekerjaan Ayah" value={profile.father_occupation} />
                  <FieldItem label="No. HP Ayah" value={profile.father_phone} />
                  <FieldItem label="Ayah Almarhum" value={yesNo(profile.father_almarhum)} />
                  <FieldItem label="Nama Ibu" value={profile.mother_name} />
                  <FieldItem label="Umur Ibu" value={profile.mother_age} />
                  <FieldItem label="Pekerjaan Ibu" value={profile.mother_occupation} />
                  <FieldItem label="No. HP Ibu" value={profile.mother_phone} />
                  <FieldItem label="Ibu Almarhumah" value={yesNo(profile.mother_almarhum)} />
                  <FieldItem label="Nama Suami/Istri" value={profile.spouse_name} />
                  <FieldItem label="Umur Suami/Istri" value={profile.spouse_age} />
                  <FieldItem label="Pekerjaan Suami/Istri" value={profile.spouse_occupation} />
                  <FieldItem label="Suami/Istri Almarhum" value={yesNo(profile.spouse_almarhum)} />
                  <FieldItem
                    label="Alamat Keluarga"
                    value={profile.family_address}
                    className="lg:col-span-3"
                  />
                  <FieldItem
                    label="Provinsi Keluarga"
                    value={profile.family_village_display?.province ?? "-"}
                  />
                  <FieldItem
                    label="Kab/Kota Keluarga"
                    value={profile.family_village_display?.regency ?? "-"}
                  />
                  <FieldItem
                    label="Kecamatan Keluarga"
                    value={profile.family_village_display?.district ?? "-"}
                  />
                  <FieldItem
                    label="Kel/Desa Keluarga"
                    value={profile.family_village_display?.village ?? "-"}
                  />
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="pb-3">
                  <CardTitle className="text-base">Ahli Waris & Paspor</CardTitle>
                </CardHeader>
                <CardContent className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  <FieldItem label="Nama Ahli Waris" value={profile.heir_name} />
                  <FieldItem
                    label="Hubungan Ahli Waris"
                    value={profile.heir_relationship_display || profile.heir_relationship}
                  />
                  <FieldItem label="No. HP Ahli Waris" value={profile.heir_contact_phone} />
                  <FieldItem label="Memiliki Paspor" value={yesNo(profile.has_passport)} />
                  <FieldItem label="Nomor Paspor" value={profile.passport_number} />
                  <FieldItem label="Tempat Terbit Paspor" value={profile.passport_issue_place} />
                  <FieldItem
                    label="Tanggal Terbit Paspor"
                    value={formatDate(profile.passport_issue_date)}
                  />
                  <FieldItem
                    label="Tanggal Kadaluarsa Paspor"
                    value={formatDate(profile.passport_expiry_date)}
                  />
                  <FieldItem label="Nomor KK" value={profile.family_card_number} />
                  <FieldItem label="Nomor Ijazah" value={profile.diploma_number} />
                  <FieldItem label="Nomor BPJS" value={profile.bpjs_number} />
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="pb-3">
                  <CardTitle className="text-base">Data Proses / Admin</CardTitle>
                </CardHeader>
                <CardContent className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  <FieldItem label="Tanggal Medical" value={formatDate(profile.tgl_medical)} />
                  <FieldItem label="Hasil Medical" value={profile.hasil_medical} />
                  <FieldItem
                    label="Tanggal Bayar SML"
                    value={formatDate(profile.tgl_bayar_sml)}
                  />
                  <FieldItem
                    label="Tanggal FWCM/Psikotes"
                    value={formatDate(profile.tgl_fwcm_psikotes)}
                  />
                  <FieldItem
                    label="Tanggal Bayar Psikotes"
                    value={formatDate(profile.tgl_bayar_psikotes)}
                  />
                  <FieldItem
                    label="Tanggal Bayar BPJS Pra"
                    value={formatDate(profile.tgl_bayar_bpjs_pra)}
                  />
                  <FieldItem
                    label="Tanggal Bayar BPJS Purna"
                    value={formatDate(profile.tgl_bayar_bpjs_purna)}
                  />
                  <FieldItem label="No ID SISKO" value={profile.no_id_sisko} />
                  <FieldItem label="Disnaker" value={profile.disnaker} />
                  <FieldItem label="No SIP" value={profile.no_sip} />
                  <FieldItem label="No JO" value={profile.no_jo} />
                  <FieldItem label="Biaya Ready Paspor" value={profile.biaya_ready_paspor} />
                  <FieldItem label="Pengembalian Biaya" value={profile.pengembalian_biaya} />
                  <FieldItem
                    label="Tgl Pengembalian"
                    value={formatDate(profile.tgl_pengembalian)}
                  />
                  <FieldItem
                    label="Jumlah Uang Transport"
                    value={profile.jlh_uang_transport}
                  />
                  <FieldItem label="Bank" value={profile.bank} />
                  <FieldItem label="No Rekening" value={profile.no_rek} />
                  <FieldItem
                    label="Tanggal Pengembalian Transfer"
                    value={formatDate(profile.tanggal_pengembalian)}
                  />
                  <FieldItem
                    label="Tgl Kirim Bio ke MLY"
                    value={formatDate(profile.tgl_kirim_bio_ke_mly)}
                  />
                  <FieldItem
                    label="Tgl Calling Visa"
                    value={formatDate(profile.tgl_calling_visa)}
                  />
                  <FieldItem label="No Calling Visa" value={profile.no_calling_visa} />
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="pb-3">
                  <CardTitle className="text-base">Metadata</CardTitle>
                </CardHeader>
                <CardContent className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  <FieldItem
                    label="Dikirim untuk Verifikasi"
                    value={formatDate(profile.submitted_at)}
                  />
                  <FieldItem
                    label="Diverifikasi Pada"
                    value={formatDate(profile.verified_at)}
                  />
                  <FieldItem
                    label="Catatan Verifikasi"
                    value={profile.verification_notes}
                    className="lg:col-span-3"
                  />
                  <FieldItem
                    label="Catatan Tambahan"
                    value={profile.notes}
                    className="lg:col-span-3"
                  />
                  <FieldItem label="Profil Dibuat" value={formatDate(profile.created_at)} />
                  <FieldItem label="Profil Diperbarui" value={formatDate(profile.updated_at)} />
                </CardContent>
              </Card>
            </>
          )}
        </div>

        <div className="border-t px-4 py-3 sm:px-6 flex justify-end gap-2">
          <Button asChild className="cursor-pointer" disabled={!applicantUserId}>
            <Link to={applicantDetailPath}>
              Edit di Halaman Pelamar
              <IconExternalLink className="ml-2 size-4" />
            </Link>
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  )
}

