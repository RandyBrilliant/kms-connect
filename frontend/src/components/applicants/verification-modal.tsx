/**
 * Verification Modal for approving or rejecting applicants.
 * Supports single and bulk verification with notes.
 */

import { useState } from "react"
import { IconChecks, IconX, IconAlertTriangle } from "@tabler/icons-react"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Alert, AlertDescription } from "@/components/ui/alert"
import type { ApplicantUser } from "@/types/applicant"

interface VerificationModalProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  action: "approve" | "reject"
  applicants: ApplicantUser[]
  onConfirm: (notes: string) => void | Promise<void>
  isLoading?: boolean
}

export function VerificationModal({
  open,
  onOpenChange,
  action,
  applicants,
  onConfirm,
  isLoading = false,
}: VerificationModalProps) {
  const [notes, setNotes] = useState("")
  const [error, setError] = useState("")

  const handleConfirm = async () => {
    // Validate notes for rejection
    if (action === "reject" && !notes.trim()) {
      setError("Catatan harus diisi untuk penolakan")
      return
    }

    setError("")
    await onConfirm(notes.trim())
    setNotes("") // Clear notes after confirmation
  }

  const handleCancel = () => {
    setNotes("")
    setError("")
    onOpenChange(false)
  }

  const isBulk = applicants.length > 1
  const title =
    action === "approve"
      ? isBulk
        ? `Terima ${applicants.length} Pelamar`
        : "Terima Pelamar"
      : isBulk
        ? `Tolak ${applicants.length} Pelamar`
        : "Tolak Pelamar"

  const description =
    action === "approve"
      ? isBulk
        ? `Anda akan menerima ${applicants.length} pelamar yang dipilih. Tindakan ini dapat dibatalkan nanti.`
        : `Anda akan menerima pelamar ${applicants[0]?.applicant_profile?.full_name || "ini"}. Tindakan ini dapat dibatalkan nanti.`
      : isBulk
        ? `Anda akan menolak ${applicants.length} pelamar yang dipilih. Tindakan ini dapat dibatalkan nanti.`
        : `Anda akan menolak pelamar ${applicants[0]?.applicant_profile?.full_name || "ini"}. Tindakan ini dapat dibatalkan nanti.`

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            {action === "approve" ? (
              <IconChecks className="size-5 text-green-600" />
            ) : (
              <IconX className="size-5 text-destructive" />
            )}
            {title}
          </DialogTitle>
          <DialogDescription>{description}</DialogDescription>
        </DialogHeader>

        <div className="space-y-4 py-4">
          {isBulk && (
            <Alert>
              <IconAlertTriangle className="size-4" />
              <AlertDescription>
                Verifikasi akan diterapkan ke {applicants.length} pelamar yang
                dipilih.
              </AlertDescription>
            </Alert>
          )}

          {/* List of applicants */}
          {isBulk && applicants.length <= 10 && (
            <div className="rounded-lg border p-3">
              <div className="text-sm font-medium mb-2">Pelamar yang dipilih:</div>
              <ul className="text-sm text-muted-foreground space-y-1">
                {applicants.map((applicant, index) => (
                  <li key={applicant.id} className="truncate">
                    {index + 1}. {applicant.applicant_profile?.full_name || applicant.email}
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* Notes field */}
          <div className="space-y-2">
            <Label htmlFor="notes">
              Catatan {action === "reject" && <span className="text-destructive">*</span>}
            </Label>
            <Textarea
              id="notes"
              placeholder={
                action === "approve"
                  ? "Tambahkan catatan (opsional)"
                  : "Jelaskan alasan penolakan"
              }
              value={notes}
              onChange={(e) => {
                setNotes(e.target.value)
                if (error) setError("")
              }}
              rows={4}
              className={error ? "border-destructive" : ""}
            />
            {error && <p className="text-destructive text-sm">{error}</p>}
          </div>
        </div>

        <DialogFooter>
          <Button
            variant="outline"
            onClick={handleCancel}
            disabled={isLoading}
            className="cursor-pointer"
          >
            Batal
          </Button>
          <Button
            variant={action === "approve" ? "default" : "destructive"}
            onClick={handleConfirm}
            disabled={isLoading}
            className="cursor-pointer gap-2"
          >
            {isLoading ? (
              <>
                <div className="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
                Memproses...
              </>
            ) : (
              <>
                {action === "approve" ? (
                  <IconChecks className="size-4" />
                ) : (
                  <IconX className="size-4" />
                )}
                {action === "approve" ? "Terima" : "Tolak"}
              </>
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
