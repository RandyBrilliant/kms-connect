"use client"

import { useState } from "react"
import { useNavigate, useSearchParams } from "react-router-dom"

import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { confirmResetPassword } from "@/api/auth"
import { toast } from "@/lib/toast"

type Step = "form" | "success" | "error"

export function ResetPasswordPage() {
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()

  const uid = searchParams.get("uid") || ""
  const token = searchParams.get("token") || ""

  const [step, setStep] = useState<Step>(
    uid && token ? "form" : "error"
  )
  const [password, setPassword] = useState("")
  const [confirmPassword, setConfirmPassword] = useState("")
  const [passwordError, setPasswordError] = useState<string | null>(null)
  const [confirmError, setConfirmError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [globalError, setGlobalError] = useState<string | null>(
    uid && token ? null : "Tautan reset password tidak valid atau sudah kedaluwarsa."
  )

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setPasswordError(null)
    setConfirmError(null)
    setGlobalError(null)

    if (!password) {
      setPasswordError("Password baru wajib diisi.")
      return
    }
    if (password.length < 8) {
      setPasswordError("Password minimal 8 karakter.")
      return
    }
    if (password !== confirmPassword) {
      setConfirmError("Konfirmasi password tidak sama.")
      return
    }

    if (!uid || !token) {
      setGlobalError("Tautan reset password tidak valid atau sudah kedaluwarsa.")
      setStep("error")
      return
    }

    setSubmitting(true)
    try {
      await confirmResetPassword({
        uid,
        token,
        new_password: password,
      })
      toast.success("Berhasil", "Password Anda telah diperbarui.")
      setStep("success")
    } catch (err: any) {
      const data = err?.response?.data
      const detail: string =
        data?.detail ||
        (err instanceof Error ? err.message : "Gagal mengatur ulang password.")

      if (data?.errors?.new_password && Array.isArray(data.errors.new_password)) {
        setPasswordError(String(data.errors.new_password[0]))
      } else {
        setGlobalError(detail)
      }
      setStep("error")
    } finally {
      setSubmitting(false)
    }
  }

  const handleGoLogin = () => {
    navigate("/login")
  }

  const title =
    step === "success"
      ? "Password Berhasil Diatur Ulang"
      : step === "error"
        ? "Reset Password"
        : "Atur Ulang Password"

  return (
    <div className="bg-background text-foreground flex min-h-screen items-center justify-center px-4">
      <Card className="max-w-md w-full">
        <CardHeader>
          <CardTitle>{title}</CardTitle>
          <CardDescription>
            {step === "success"
              ? "Anda dapat menggunakan password baru untuk login ke dashboard."
              : "Masukkan password baru Anda. Tautan ini hanya dapat digunakan sekali dan berlaku terbatas."}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {globalError && (
            <div className="mb-4 rounded-md border border-destructive/40 bg-destructive/5 px-3 py-2 text-sm text-destructive">
              {globalError}
            </div>
          )}

          {step !== "success" && uid && token && (
            <form onSubmit={handleSubmit}>
              <FieldGroup>
                <Field>
                  <FieldLabel htmlFor="new-password">
                    Password Baru <span className="text-destructive">*</span>
                  </FieldLabel>
                  <Input
                    id="new-password"
                    type="password"
                    value={password}
                    onChange={(e) => {
                      setPassword(e.target.value)
                      setPasswordError(null)
                    }}
                    disabled={submitting}
                    autoComplete="new-password"
                  />
                  {passwordError && (
                    <FieldError errors={[{ message: passwordError }]} />
                  )}
                </Field>
                <Field>
                  <FieldLabel htmlFor="confirm-password">
                    Konfirmasi Password Baru <span className="text-destructive">*</span>
                  </FieldLabel>
                  <Input
                    id="confirm-password"
                    type="password"
                    value={confirmPassword}
                    onChange={(e) => {
                      setConfirmPassword(e.target.value)
                      setConfirmError(null)
                    }}
                    disabled={submitting}
                    autoComplete="new-password"
                  />
                  {confirmError && (
                    <FieldError errors={[{ message: confirmError }]} />
                  )}
                </Field>
              </FieldGroup>
              <div className="mt-6 flex justify-end gap-2">
                <Button
                  type="button"
                  variant="outline"
                  onClick={handleGoLogin}
                  className="cursor-pointer"
                >
                  Batal
                </Button>
                <Button
                  type="submit"
                  disabled={submitting}
                  className="cursor-pointer"
                >
                  {submitting ? "Menyimpan..." : "Simpan Password Baru"}
                </Button>
              </div>
            </form>
          )}

          {step === "success" && (
            <div className="mt-4 flex justify-end">
              <Button
                type="button"
                onClick={handleGoLogin}
                className="cursor-pointer"
              >
                Ke Halaman Login
              </Button>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}

export default ResetPasswordPage

