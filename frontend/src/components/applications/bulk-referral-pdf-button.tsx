import { useState } from "react"
import { IconFileTypePdf } from "@tabler/icons-react"

import { downloadBulkReferralPdf, type BulkReferralPdfKind } from "@/api/applicants"
import { Button } from "@/components/ui/button"
import { toast } from "@/lib/toast"

type BulkReferralPdfButtonProps = {
  kind: BulkReferralPdfKind
  selectedApplicantUserIds: number[]
}

const LABELS: Record<BulkReferralPdfKind, string> = {
  medical: "PDF Pengantar Medical",
  psychology: "PDF Pengantar Psikotes",
}

const ERROR_LABELS: Record<BulkReferralPdfKind, string> = {
  medical: "Gagal membuat PDF pengantar medical",
  psychology: "Gagal membuat PDF pengantar psikotes",
}

export function BulkReferralPdfButton({
  kind,
  selectedApplicantUserIds,
}: BulkReferralPdfButtonProps) {
  const [isGenerating, setIsGenerating] = useState(false)
  const count = selectedApplicantUserIds.length

  const handleClick = async () => {
    if (!count) {
      toast.error("Pilih pelamar", "Centang minimal satu pelamar di tabel.")
      return
    }
    setIsGenerating(true)
    try {
      await downloadBulkReferralPdf(kind, selectedApplicantUserIds)
      toast.success(
        count === 1 ? "PDF berhasil dibuka." : `ZIP berisi ${count} PDF berhasil diunduh.`
      )
    } catch (err: unknown) {
      const detail = (err as { response?: { data?: { detail?: string } } })?.response?.data
        ?.detail
      toast.error(ERROR_LABELS[kind], detail ?? "Coba lagi nanti.")
    } finally {
      setIsGenerating(false)
    }
  }

  return (
    <Button
      type="button"
      variant="outline"
      size="sm"
      className="h-9 cursor-pointer"
      disabled={count === 0 || isGenerating}
      onClick={() => void handleClick()}
    >
      <IconFileTypePdf className="mr-2 size-4" />
      {isGenerating ? "Membuat PDF..." : LABELS[kind]}
      {count > 0 ? ` (${count})` : ""}
    </Button>
  )
}
