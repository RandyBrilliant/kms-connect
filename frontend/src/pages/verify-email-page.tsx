"use client"

import { useEffect, useRef, useState } from "react"
import { useNavigate, useSearchParams } from "react-router-dom"
import { CheckCircle2Icon, MailIcon, RefreshCwIcon } from "lucide-react"

import { verifyEmailCode, resendVerificationEmail } from "@/api/auth"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  InputOTP,
  InputOTPGroup,
  InputOTPSlot,
} from "@/components/ui/input-otp"
import { toast } from "@/lib/toast"

const RESEND_COOLDOWN = 60
const REDIRECT_DELAY = 3000

export function VerifyEmailPage() {
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()
  const email = searchParams.get("email") ?? ""

  const [code, setCode] = useState("")
  const [loading, setLoading] = useState(false)
  const [success, setSuccess] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [resendLoading, setResendLoading] = useState(false)
  const [cooldown, setCooldown] = useState(0)
  const cooldownRef = useRef<ReturnType<typeof setInterval> | null>(null)

  // Redirect to login if no email provided
  useEffect(() => {
    if (!email) {
      navigate("/login", { replace: true })
    }
  }, [email, navigate])

  // Auto-submit when all 6 digits are filled
  useEffect(() => {
    if (code.length === 6 && !loading && !success) {
      void handleVerify(code)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [code])

  // Redirect to login after success
  useEffect(() => {
    if (!success) return
    const timer = setTimeout(() => {
      navigate("/login")
    }, REDIRECT_DELAY)
    return () => clearTimeout(timer)
  }, [success, navigate])

  // Cooldown countdown
  useEffect(() => {
    if (cooldown <= 0) return
    cooldownRef.current = setInterval(() => {
      setCooldown((prev) => {
        if (prev <= 1) {
          clearInterval(cooldownRef.current!)
          return 0
        }
        return prev - 1
      })
    }, 1000)
    return () => {
      if (cooldownRef.current) clearInterval(cooldownRef.current)
    }
  }, [cooldown])

  const handleVerify = async (value: string) => {
    if (!email || value.length !== 6) return
    setLoading(true)
    setErrorMessage(null)
    try {
      await verifyEmailCode(email, value)
      setSuccess(true)
      toast.success("Email terverifikasi", "Anda dapat login sekarang.")
    } catch (err: unknown) {
      const detail =
        (err as { response?: { data?: { detail?: string } } })?.response?.data
          ?.detail ?? "Kode tidak valid atau sudah kedaluwarsa."
      setErrorMessage(detail)
      setCode("")
    } finally {
      setLoading(false)
    }
  }

  const handleResend = async () => {
    if (!email || resendLoading || cooldown > 0) return
    setResendLoading(true)
    setErrorMessage(null)
    try {
      await resendVerificationEmail(email)
      setCooldown(RESEND_COOLDOWN)
      toast.success("Kode dikirim", "Silakan cek kotak masuk email Anda.")
    } catch (err: unknown) {
      const detail =
        (err as { response?: { data?: { detail?: string } } })?.response?.data
          ?.detail ?? "Gagal mengirim ulang. Coba lagi."
      toast.error("Gagal", detail)
    } finally {
      setResendLoading(false)
    }
  }

  if (!email) return null

  if (success) {
    return (
      <div className="bg-background text-foreground flex min-h-screen items-center justify-center px-4">
        <Card className="w-full max-w-md text-center">
          <CardHeader className="items-center gap-3">
            <div className="flex h-16 w-16 items-center justify-center rounded-full bg-green-100 dark:bg-green-950">
              <CheckCircle2Icon className="h-8 w-8 text-green-600 dark:text-green-400" />
            </div>
            <CardTitle className="text-2xl">Email Terverifikasi!</CardTitle>
            <CardDescription>
              Akun <span className="font-medium text-foreground">{email}</span> berhasil
              diverifikasi. Mengalihkan ke halaman login...
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button className="w-full cursor-pointer" onClick={() => navigate("/login")}>
              Login Sekarang
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="bg-background text-foreground flex min-h-screen items-center justify-center px-4">
      <Card className="w-full max-w-md">
        <CardHeader className="items-center gap-3 text-center">
          <div className="flex h-14 w-14 items-center justify-center rounded-full bg-primary/10">
            <MailIcon className="h-7 w-7 text-primary" />
          </div>
          <div>
            <CardTitle className="text-2xl">Verifikasi Email</CardTitle>
            <CardDescription className="mt-1">
              Masukkan 6-digit kode yang dikirim ke{" "}
              <span className="font-medium text-foreground">{email}</span>
            </CardDescription>
          </div>
        </CardHeader>

        <CardContent className="flex flex-col items-center gap-6">
          {/* OTP Input */}
          <div className="flex flex-col items-center gap-3">
            <InputOTP
              maxLength={6}
              value={code}
              onChange={setCode}
              disabled={loading}
              autoFocus
            >
              <InputOTPGroup>
                <InputOTPSlot index={0} />
                <InputOTPSlot index={1} />
                <InputOTPSlot index={2} />
                <InputOTPSlot index={3} />
                <InputOTPSlot index={4} />
                <InputOTPSlot index={5} />
              </InputOTPGroup>
            </InputOTP>

            {loading && (
              <p className="text-sm text-muted-foreground">Memverifikasi...</p>
            )}

            {errorMessage && (
              <p className="text-sm font-medium text-destructive">{errorMessage}</p>
            )}
          </div>

          {/* Resend */}
          <div className="flex flex-col items-center gap-2 text-sm text-muted-foreground">
            <span>Tidak menerima kode?</span>
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="cursor-pointer gap-2"
              disabled={resendLoading || cooldown > 0}
              onClick={handleResend}
            >
              <RefreshCwIcon className={`h-3.5 w-3.5 ${resendLoading ? "animate-spin" : ""}`} />
              {cooldown > 0
                ? `Kirim ulang dalam ${cooldown}s`
                : resendLoading
                  ? "Mengirim..."
                  : "Kirim ulang kode"}
            </Button>
          </div>

          {/* Back to login */}
          <Button
            type="button"
            variant="ghost"
            className="w-full cursor-pointer text-muted-foreground"
            onClick={() => navigate("/login")}
          >
            Kembali ke Login
          </Button>
        </CardContent>
      </Card>
    </div>
  )
}

export default VerifyEmailPage
