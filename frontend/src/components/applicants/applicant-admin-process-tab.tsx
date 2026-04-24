/**
 * Admin-only tab for additional applicant process & finance data.
 * Uses TanStack Form to submit a partial ApplicantProfile update.
 */

import { useForm } from "@tanstack/react-form"

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { DatePicker } from "@/components/ui/date-picker"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import type { ApplicantProfile } from "@/types/applicant"
import { applicantProfileUpdateSchema } from "@/schemas/applicant"
import { formatApiValidationErrors } from "@/lib/format-api-validation-errors"
import { toast } from "@/lib/toast"
import { format } from "date-fns"
import type { AxiosError } from "axios"

interface ApplicantAdminProcessTabProps {
  profile: ApplicantProfile
  onSubmit: (data: Partial<ApplicantProfile>) => Promise<void>
  isSubmitting?: boolean
  /** Narrow modals: responsive columns + min-w-0 so fields do not overlap */
  compactLayout?: boolean
}

type AdminProcessFormValues = {
  tgl_medical: string
  hasil_medical: string
  tgl_bayar_sml: string
  tgl_fwcm_psikotes: string
  tgl_bayar_psikotes: string
  tgl_bayar_bpjs_pra: string
  tgl_bayar_bpjs_purna: string
  no_id_sisko: string
  disnaker: string
  no_sip: string
  no_jo: string
  biaya_ready_paspor: string
  pengembalian_biaya: string
  tgl_pengembalian: string
  jlh_uang_transport: string
  bank: string
  no_rek: string
  tanggal_pengembalian: string
  tgl_kirim_bio_ke_mly: string
  tgl_calling_visa: string
  no_calling_visa: string
}

function toFormValues(p: ApplicantProfile): AdminProcessFormValues {
  return {
    tgl_medical: p.tgl_medical ?? "",
    hasil_medical: p.hasil_medical ?? "",
    tgl_bayar_sml: p.tgl_bayar_sml ?? "",
    tgl_fwcm_psikotes: p.tgl_fwcm_psikotes ?? "",
    tgl_bayar_psikotes: p.tgl_bayar_psikotes ?? "",
    tgl_bayar_bpjs_pra: p.tgl_bayar_bpjs_pra ?? "",
    tgl_bayar_bpjs_purna: p.tgl_bayar_bpjs_purna ?? "",
    no_id_sisko: p.no_id_sisko ?? "",
    disnaker: p.disnaker ?? "",
    no_sip: p.no_sip ?? "",
    no_jo: p.no_jo ?? "",
    biaya_ready_paspor: p.biaya_ready_paspor != null ? String(p.biaya_ready_paspor) : "",
    pengembalian_biaya: p.pengembalian_biaya != null ? String(p.pengembalian_biaya) : "",
    tgl_pengembalian: p.tgl_pengembalian ?? "",
    jlh_uang_transport: p.jlh_uang_transport != null ? String(p.jlh_uang_transport) : "",
    bank: p.bank ?? "",
    no_rek: p.no_rek ?? "",
    tanggal_pengembalian: p.tanggal_pengembalian ?? "",
    tgl_kirim_bio_ke_mly: p.tgl_kirim_bio_ke_mly ?? "",
    tgl_calling_visa: p.tgl_calling_visa ?? "",
    no_calling_visa: p.no_calling_visa ?? "",
  }
}

function toNumber(value: string): number | null {
  if (!value.trim()) return null
  const normalized = value.replace(/,/g, "").trim()
  const n = Number(normalized)
  return Number.isNaN(n) ? null : n
}

const grid3 =
  "grid gap-4 grid-cols-1 sm:grid-cols-3 [&>*]:min-w-0 [&>*]:max-w-full"
const grid3Compact =
  "grid gap-4 grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 [&>*]:min-w-0 [&>*]:max-w-full"
const grid2 =
  "grid gap-4 grid-cols-1 sm:grid-cols-2 [&>*]:min-w-0 [&>*]:max-w-full"

export function ApplicantAdminProcessTab({
  profile,
  onSubmit,
  isSubmitting = false,
  compactLayout = false,
}: ApplicantAdminProcessTabProps) {
  const g3 = compactLayout ? grid3Compact : grid3
  const g2 = grid2
  const form = useForm({
    defaultValues: toFormValues(profile),
    onSubmit: async ({ value }) => {
      try {
        const candidate: Record<string, unknown> = {
          tgl_medical: value.tgl_medical || null,
          hasil_medical: value.hasil_medical || "",
          tgl_bayar_sml: value.tgl_bayar_sml || null,
          tgl_fwcm_psikotes: value.tgl_fwcm_psikotes || null,
          tgl_bayar_psikotes: value.tgl_bayar_psikotes || null,
          tgl_bayar_bpjs_pra: value.tgl_bayar_bpjs_pra || null,
          tgl_bayar_bpjs_purna: value.tgl_bayar_bpjs_purna || null,
          no_id_sisko: value.no_id_sisko || "",
          disnaker: value.disnaker || "",
          no_sip: value.no_sip || "",
          no_jo: value.no_jo || "",
          biaya_ready_paspor: toNumber(value.biaya_ready_paspor),
          pengembalian_biaya: toNumber(value.pengembalian_biaya),
          tgl_pengembalian: value.tgl_pengembalian || null,
          jlh_uang_transport: toNumber(value.jlh_uang_transport),
          bank: value.bank || "",
          no_rek: value.no_rek || "",
          tanggal_pengembalian: value.tanggal_pengembalian || null,
          tgl_kirim_bio_ke_mly: value.tgl_kirim_bio_ke_mly || null,
          tgl_calling_visa: value.tgl_calling_visa || null,
          no_calling_visa: value.no_calling_visa || "",
        }

        const parsed = applicantProfileUpdateSchema.safeParse(candidate)
        if (!parsed.success) {
          const msgs = parsed.error.issues.map((i) => i.message).join(". ")
          toast.error("Validasi gagal", msgs)
          return
        }

        await onSubmit(parsed.data as Partial<ApplicantProfile>)
        toast.success("Data proses & biaya diperbarui")
      } catch (e: unknown) {
        const ax = e as AxiosError<{ detail?: string; errors?: unknown }>
        const payload = ax.response?.data
        const fieldDetail = formatApiValidationErrors(payload)
        toast.error(
          "Gagal menyimpan",
          fieldDetail ?? payload?.detail ?? "Coba lagi nanti"
        )
      }
    },
  })

  const renderDateField = (
    name: keyof AdminProcessFormValues,
    label: string,
    placeholder: string,
  ) => (
    <form.Field name={name}>
      {(field) => {
        const selectedDate = field.state.value ? new Date(field.state.value) : null
        return (
          <Field>
            <FieldLabel htmlFor={field.name}>{label}</FieldLabel>
            <DatePicker
              date={selectedDate}
              onDateChange={(d) =>
                field.handleChange(d ? format(d, "yyyy-MM-dd") : "")
              }
              placeholder={placeholder}
            />
            <FieldError errors={field.state.meta.errors as any} />
          </Field>
        )
      }}
    </form.Field>
  )

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault()
        e.stopPropagation()
        void form.handleSubmit()
      }}
      className="flex min-w-0 flex-col gap-6"
    >
      <Card className="min-w-0 overflow-hidden shadow-sm">
        <CardHeader>
          <CardTitle>Proses Medical &amp; Pembayaran</CardTitle>
          <CardDescription>
            Tahapan medical dan pembayaran terkait proses penempatan.
          </CardDescription>
        </CardHeader>
        <CardContent className="min-w-0 space-y-6">
          <FieldGroup>
            <div className={g3}>
              {renderDateField("tgl_medical", "Tgl. Medical", "Pilih tanggal medical")}
              <form.Field name="hasil_medical">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Hasil Medical</FieldLabel>
                    <Select
                      value={field.state.value || "PENDING"}
                      onValueChange={(v) => field.handleChange(v === "PENDING" ? "" : v)}
                      disabled={isSubmitting}
                    >
                      <SelectTrigger id={field.name} className="cursor-pointer">
                        <SelectValue placeholder="Pilih hasil medical" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="PENDING">Belum diisi</SelectItem>
                        <SelectItem value="FIT">FIT</SelectItem>
                        <SelectItem value="UNFIT">UNFIT</SelectItem>
                      </SelectContent>
                    </Select>
                    <FieldError errors={field.state.meta.errors as any} />
                  </Field>
                )}
              </form.Field>
              {renderDateField("tgl_bayar_sml", "Tgl. Bayar SML", "Pilih tanggal bayar SML")}
            </div>

            <div className={g3}>
              {renderDateField("tgl_fwcm_psikotes", "Tgl. FWCMS & Psikotes", "Pilih tanggal FWCMS & psikotes")}
              {renderDateField("tgl_bayar_psikotes", "Tgl. Bayar Psikotes", "Pilih tanggal bayar psikotes")}
              {renderDateField("tgl_bayar_bpjs_pra", "Tgl. Bayar BPJS Pra", "Pilih tanggal bayar BPJS pra")}
            </div>

            <div className={g3}>
              {renderDateField("tgl_bayar_bpjs_purna", "Tgl. Bayar BPJS Purna", "Pilih tanggal bayar BPJS purna")}
              <form.Field name="no_id_sisko">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>No. ID SISKO</FieldLabel>
                    <Input
                      id={field.name}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      disabled={isSubmitting}
                    />
                    <FieldError errors={field.state.meta.errors as any} />
                  </Field>
                )}
              </form.Field>
              <form.Field name="disnaker">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Disnaker</FieldLabel>
                    <Input
                      id={field.name}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      disabled={isSubmitting}
                    />
                    <FieldError errors={field.state.meta.errors as any} />
                  </Field>
                )}
              </form.Field>
            </div>

            <div className={g2}>
              <form.Field name="no_sip">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>No. SIP</FieldLabel>
                    <Input
                      id={field.name}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      disabled={isSubmitting}
                    />
                    <FieldError errors={field.state.meta.errors as any} />
                  </Field>
                )}
              </form.Field>
              <form.Field name="no_jo">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>No. JO</FieldLabel>
                    <Input
                      id={field.name}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      disabled={isSubmitting}
                    />
                    <FieldError errors={field.state.meta.errors as any} />
                  </Field>
                )}
              </form.Field>
            </div>
          </FieldGroup>
        </CardContent>
      </Card>

      <Card className="min-w-0 overflow-hidden shadow-sm">
        <CardHeader>
          <CardTitle>Biaya &amp; Pengembalian</CardTitle>
          <CardDescription>
            Ringkasan biaya, pengembalian, dan data rekening.
          </CardDescription>
        </CardHeader>
        <CardContent className="min-w-0 space-y-6">
          <FieldGroup>
            <div className={g3}>
              <form.Field name="biaya_ready_paspor">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Biaya Ready Paspor (Rp)</FieldLabel>
                    <Input
                      id={field.name}
                      type="number"
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      disabled={isSubmitting}
                      placeholder="Contoh: 500000"
                    />
                    <FieldError errors={field.state.meta.errors as any} />
                  </Field>
                )}
              </form.Field>
              <form.Field name="pengembalian_biaya">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Pengembalian Biaya (Rp)</FieldLabel>
                    <Input
                      id={field.name}
                      type="number"
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      disabled={isSubmitting}
                      placeholder="Contoh: 250000"
                    />
                    <FieldError errors={field.state.meta.errors as any} />
                  </Field>
                )}
              </form.Field>
              {renderDateField("tgl_pengembalian", "Tgl. Pengembalian", "Pilih tanggal pengembalian")}
            </div>

            <div className={g3}>
              <form.Field name="jlh_uang_transport">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Jlh Uang Transport (Rp)</FieldLabel>
                    <Input
                      id={field.name}
                      type="number"
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      disabled={isSubmitting}
                      placeholder="Contoh: 100000"
                    />
                    <FieldError errors={field.state.meta.errors as any} />
                  </Field>
                )}
              </form.Field>
              <form.Field name="bank">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Bank</FieldLabel>
                    <Input
                      id={field.name}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      disabled={isSubmitting}
                      placeholder="Contoh: BCA"
                    />
                    <FieldError errors={field.state.meta.errors as any} />
                  </Field>
                )}
              </form.Field>
              <form.Field name="no_rek">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>No. Rekening</FieldLabel>
                    <Input
                      id={field.name}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      disabled={isSubmitting}
                    />
                    <FieldError errors={field.state.meta.errors as any} />
                  </Field>
                )}
              </form.Field>
            </div>

            {renderDateField(
              "tanggal_pengembalian",
              "Tanggal Pengembalian (Transfer)",
              "Pilih tanggal pengembalian (transfer)",
            )}
          </FieldGroup>
        </CardContent>
      </Card>

      <Card className="min-w-0 overflow-hidden shadow-sm">
        <CardHeader>
          <CardTitle>Calling Visa &amp; Keberangkatan</CardTitle>
          <CardDescription>
            Informasi pengiriman biodata dan calling visa.
          </CardDescription>
        </CardHeader>
        <CardContent className="min-w-0 space-y-6">
          <FieldGroup>
            <div className={g3}>
              {renderDateField(
                "tgl_kirim_bio_ke_mly",
                "Tgl. Kirim Bio ke MY",
                "Pilih tanggal kirim biodata",
              )}
              {renderDateField(
                "tgl_calling_visa",
                "Tgl. Calling Visa",
                "Pilih tanggal calling visa",
              )}
              <form.Field name="no_calling_visa">
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>No. Calling Visa</FieldLabel>
                    <Input
                      id={field.name}
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      disabled={isSubmitting}
                    />
                    <FieldError errors={field.state.meta.errors as any} />
                  </Field>
                )}
              </form.Field>
            </div>
          </FieldGroup>
        </CardContent>
      </Card>

      <div className="flex gap-2">
        <Button type="submit" disabled={isSubmitting} className="cursor-pointer">
          {isSubmitting ? "Menyimpan..." : "Simpan Data Proses"}
        </Button>
      </div>
    </form>
  )
}

