/**
 * Admin-only tab for additional applicant process & finance data.
 * Uses TanStack Form to submit a partial ApplicantProfile update.
 */

import type { ReactNode } from "react"
import { useCallback, useEffect, useMemo, useState } from "react"
import { useForm } from "@tanstack/react-form"
import type { LucideIcon } from "lucide-react"
import {
  BadgeCheck,
  Brain,
  Plane,
  Receipt,
  ShieldCheck,
  Stethoscope,
} from "lucide-react"

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { DatePicker } from "@/components/ui/date-picker"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import type { ApplicantProfile } from "@/types/applicant"
import { INBOUND_TRANSPORT_STAGES } from "@/lib/inbound-transport-stages"
import { applicantProfileUpdateSchema } from "@/schemas/applicant"
import { formatApiValidationErrors } from "@/lib/format-api-validation-errors"
import { defaultDisnakerFromApplicantProfile } from "@/lib/applicant-disnaker-default"
import { toast } from "@/lib/toast"
import { cn } from "@/lib/utils"
import { format, parseISO } from "date-fns"
import type { AxiosError } from "axios"

function ProcessSectionCard({
  icon: Icon,
  title,
  description,
  compactLayout,
  children,
}: {
  icon: LucideIcon
  title: string
  description: string
  compactLayout?: boolean
  children: ReactNode
}) {
  return (
    <Card className="min-w-0 overflow-hidden rounded-xl border border-border/60 bg-card shadow-sm">
      <CardHeader
        className={cn(
          "border-b border-border/50 bg-muted/15 dark:bg-muted/10",
          compactLayout ? "px-4 py-3.5" : "px-5 py-4"
        )}
      >
        <div className="flex gap-3">
          <div className="bg-primary/10 text-primary flex size-10 shrink-0 items-center justify-center rounded-xl shadow-sm">
            <Icon className="size-5" strokeWidth={2} aria-hidden />
          </div>
          <div className="min-w-0 space-y-0.5">
            <CardTitle className="text-base font-semibold tracking-tight">{title}</CardTitle>
            <CardDescription className="text-muted-foreground text-xs leading-relaxed sm:text-sm">
              {description}
            </CardDescription>
          </div>
        </div>
      </CardHeader>
      <CardContent
        className={cn(
          "min-w-0 space-y-4",
          compactLayout ? "px-4 py-4" : "px-5 py-5"
        )}
      >
        {children}
      </CardContent>
    </Card>
  )
}

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
    disnaker: (() => {
      const stored = (p.disnaker ?? "").trim()
      if (stored) return stored.toUpperCase()
      return defaultDisnakerFromApplicantProfile(p)
    })(),
    no_sip: p.no_sip ?? "",
    no_jo: p.no_jo ?? "",
    biaya_ready_paspor: p.biaya_ready_paspor != null ? String(p.biaya_ready_paspor) : "",
    pengembalian_biaya: p.pengembalian_biaya != null ? String(p.pengembalian_biaya) : "",
    tgl_pengembalian: p.tgl_pengembalian ?? "",
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

type InboundStageCostFormRow = {
  stage_code: string
  label: string
  amount: string
  keterangan: string
  /** ISO date (yyyy-MM-dd) from lamaran sub-tahapan; read-only, not submitted */
  tanggal_proses: string | null
}

function formatTanggalProsesDisplay(iso: string | null | undefined): string {
  if (!iso?.trim()) return "—"
  try {
    return format(parseISO(iso), "dd/MM/yyyy")
  } catch {
    return iso
  }
}

function buildInboundStageCostRowsFromProfile(
  p: ApplicantProfile
): InboundStageCostFormRow[] {
  const fromApi = p.inbound_transport_stage_costs
  if (fromApi && fromApi.length > 0) {
    return fromApi.map((r) => ({
      stage_code: r.stage_code,
      label: r.label,
      amount: r.amount != null && !Number.isNaN(r.amount) ? String(r.amount) : "",
      keterangan: r.keterangan ?? "",
      tanggal_proses: r.tanggal_proses ?? null,
    }))
  }
  return INBOUND_TRANSPORT_STAGES.map(([code, label]) => ({
    stage_code: code,
    label,
    amount: "",
    keterangan: "",
    tanggal_proses: null,
  }))
}

export function ApplicantAdminProcessTab({
  profile,
  onSubmit,
  isSubmitting = false,
  compactLayout = false,
}: ApplicantAdminProcessTabProps) {
  const g3 = compactLayout ? grid3Compact : grid3
  const g2 = grid2

  const [inboundStageRows, setInboundStageRows] = useState<InboundStageCostFormRow[]>(() =>
    buildInboundStageCostRowsFromProfile(profile)
  )

  const updateInboundRow = useCallback(
    (index: number, patch: Partial<InboundStageCostFormRow>) => {
      setInboundStageRows((prev) => {
        const next = [...prev]
        const cur = next[index]
        if (!cur) return prev
        next[index] = { ...cur, ...patch }
        return next
      })
    },
    []
  )

  const inboundTransportTotalPreview = useMemo(() => {
    let sum = 0
    let any = false
    for (const r of inboundStageRows) {
      const n = toNumber(r.amount)
      if (n != null) {
        sum += n
        any = true
      }
    }
    return any ? sum : null
  }, [inboundStageRows])

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
          disnaker: (value.disnaker ?? "").trim().toUpperCase(),
          no_sip: value.no_sip || "",
          no_jo: value.no_jo || "",
          biaya_ready_paspor: toNumber(value.biaya_ready_paspor),
          pengembalian_biaya: toNumber(value.pengembalian_biaya),
          tgl_pengembalian: value.tgl_pengembalian || null,
          bank: value.bank || "",
          no_rek: value.no_rek || "",
          tanggal_pengembalian: value.tanggal_pengembalian || null,
          tgl_kirim_bio_ke_mly: value.tgl_kirim_bio_ke_mly || null,
          tgl_calling_visa: value.tgl_calling_visa || null,
          no_calling_visa: value.no_calling_visa || "",
          inbound_transport_stage_costs: inboundStageRows.map((r) => ({
            stage_code: r.stage_code,
            amount: toNumber(r.amount),
            keterangan: (r.keterangan ?? "").trim(),
          })),
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

  const inboundServerKey = JSON.stringify(
    profile.inbound_transport_stage_costs ?? null
  )

  useEffect(() => {
    setInboundStageRows(buildInboundStageCostRowsFromProfile(profile))
    form.reset(toFormValues(profile))
  }, [profile.id, profile.updated_at, inboundServerKey, form, profile])

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
      <ProcessSectionCard
        icon={Stethoscope}
        title="Medical"
        description="Jadwal medical, hasil pemeriksaan, dan tanggal pembayaran medical."
        compactLayout={compactLayout}
      >
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
            {renderDateField(
              "tgl_bayar_sml",
              "Tgl. Bayar Medical",
              "Pilih tanggal pembayaran medical",
            )}
          </div>
        </FieldGroup>
      </ProcessSectionCard>

      <ProcessSectionCard
        icon={Brain}
        title="FWCMS & Psikotes"
        description="Jadwal FWCMS/psikotes dan tanggal pembayaran psikotes."
        compactLayout={compactLayout}
      >
        <FieldGroup>
          <div className={g2}>
            {renderDateField(
              "tgl_fwcm_psikotes",
              "Tgl. FWCMS & Psikotes",
              "Pilih tanggal FWCMS & psikotes",
            )}
            {renderDateField(
              "tgl_bayar_psikotes",
              "Tgl. Bayar Psikotes",
              "Pilih tanggal bayar psikotes",
            )}
          </div>
        </FieldGroup>
      </ProcessSectionCard>

      <ProcessSectionCard
        icon={ShieldCheck}
        title="BPJS Kesehatan"
        description="Tanggal pembayaran iuran BPJS tahap pra dan purna penempatan."
        compactLayout={compactLayout}
      >
        <FieldGroup>
          <div className={g2}>
            {renderDateField(
              "tgl_bayar_bpjs_pra",
              "Tgl. Bayar BPJS Pra",
              "Pilih tanggal bayar BPJS pra",
            )}
            {renderDateField(
              "tgl_bayar_bpjs_purna",
              "Tgl. Bayar BPJS Purna",
              "Pilih tanggal bayar BPJS purna",
            )}
          </div>
        </FieldGroup>
      </ProcessSectionCard>

      <ProcessSectionCard
        icon={BadgeCheck}
        title="SISKO, Disnaker, SIP & JO"
        description="Nomor referensi administrasi penempatan (ID SISKO, Disnaker, SIP, dan JO)."
        compactLayout={compactLayout}
      >
        <FieldGroup>
          <div className={g2}>
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
                    autoComplete="off"
                  />
                  <FieldError errors={field.state.meta.errors as any} />
                </Field>
              )}
            </form.Field>
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
      </ProcessSectionCard>

      <ProcessSectionCard
        icon={Receipt}
        title="Biaya & Pengembalian"
        description="Biaya transport per sub-tahapan Diterima (PDF Inbound), ringkasan pengembalian, dan rekening."
        compactLayout={compactLayout}
      >
        <FieldGroup>
          <div className="space-y-2">
            <p className="text-sm text-muted-foreground">
              Tgl. proses diambil otomatis dari sub-tahapan Diterima (konfirmasi pelamar
              atau saat admin memajukan langkah). Total uang transport dihitung dari
              jumlah per baris.
            </p>
            {inboundTransportTotalPreview != null && (
              <p className="text-sm font-medium tabular-nums">
                Total uang transport (pratinjau): Rp{" "}
                {inboundTransportTotalPreview.toLocaleString("id-ID")}
              </p>
            )}
            <div className="overflow-x-auto rounded-lg border border-border/60">
              <Table>
                <TableHeader>
                  <TableRow className="bg-muted/30 hover:bg-muted/30">
                    <TableHead className="whitespace-normal">Tahapan</TableHead>
                    <TableHead className="w-[9.5rem] whitespace-normal">
                      Tgl. proses
                    </TableHead>
                    <TableHead className="w-[8.5rem] whitespace-normal">
                      Jumlah (Rp)
                    </TableHead>
                    <TableHead className="min-w-[10rem] whitespace-normal">
                      Keterangan
                    </TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {inboundStageRows.map((row, index) => (
                    <TableRow key={row.stage_code}>
                      <TableCell className="align-top font-medium whitespace-normal">
                        {row.label}
                      </TableCell>
                      <TableCell className="align-top text-muted-foreground tabular-nums">
                        {formatTanggalProsesDisplay(row.tanggal_proses)}
                      </TableCell>
                      <TableCell className="align-top">
                        <Input
                          type="number"
                          inputMode="numeric"
                          className="h-9 tabular-nums"
                          value={row.amount}
                          onChange={(e) =>
                            updateInboundRow(index, { amount: e.target.value })
                          }
                          disabled={isSubmitting}
                          placeholder="0"
                        />
                      </TableCell>
                      <TableCell className="align-top">
                        <Input
                          className="h-9"
                          value={row.keterangan}
                          onChange={(e) =>
                            updateInboundRow(index, {
                              keterangan: e.target.value,
                            })
                          }
                          disabled={isSubmitting}
                          placeholder="—"
                        />
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          </div>

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
      </ProcessSectionCard>

      <ProcessSectionCard
        icon={Plane}
        title="Calling Visa & Keberangkatan"
        description="Pengiriman biodata ke Malaysia dan data calling visa."
        compactLayout={compactLayout}
      >
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
      </ProcessSectionCard>

      <div className="flex gap-2">
        <Button type="submit" disabled={isSubmitting} className="cursor-pointer">
          {isSubmitting ? "Menyimpan..." : "Simpan Data Proses"}
        </Button>
      </div>
    </form>
  )
}

