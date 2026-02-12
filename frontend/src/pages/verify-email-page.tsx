"use client"

import { useEffect, useState } from "react"
import { useNavigate, useSearchParams } from "react-router-dom"

import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { verifyEmail } from "@/api/auth"

type Status = "idle" | "loading" | "success" | "error"

export function VerifyEmailPage() {
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()
  const [status, setStatus] = useState<Status>("idle")
  const [message, setMessage] = useState<string>("")
  const [email, setEmail] = useState<string | null>(null)

  useEffect(() => {
    const token = searchParams.get("token")
    if (!token) {
      setStatus("error")
      setMessage("Token verifikasi tidak ditemukan di URL.")
      return
    }

    let cancelled = false

    const run = async () => {
      setStatus("loading")
      try {
        const res = await verifyEmail(token)
        if (cancelled) return
        setStatus("success")
        setEmail(res.data?.email ?? null)
        setMessage(res.detail || "Email berhasil diverifikasi.")
      } catch (err: any) {
        if (cancelled) return
        const detail =
          err?.response?.data?.detail ||
          (err instanceof Error ? err.message : "Verifikasi email gagal.")
        setStatus("error")
        setMessage(detail)
      }
    }

    void run()

    return () => {
      cancelled = true
    }
  }, [searchParams])

  const handleGoLogin = () => {
    navigate("/login")
  }

  const title =
    status === "success"
      ? "Email Berhasil Diverifikasi"
      : status === "error"
        ? "Verifikasi Email Gagal"
        : "Memverifikasi Email..."

  return (
    <div className="bg-background text-foreground flex min-h-screen items-center justify-center px-4">
      <Card className="max-w-md w-full">
        <CardHeader>
          <CardTitle>{title}</CardTitle>
          <CardDescription>
            {status === "loading"
              ? "Mohon tunggu, kami sedang memverifikasi tautan Anda."
              : message}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {email && status === "success" && (
            <p className="text-sm text-muted-foreground">
              Akun dengan email <span className="font-medium">{email}</span> sudah terverifikasi.
            </p>
          )}
          {status === "loading" && (
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <div className="h-4 w-4 animate-spin rounded-full border-2 border-primary border-t-transparent" />
              <span>Memproses verifikasi...</span>
            </div>
          )}
          <div className="flex justify-end gap-2 pt-2">
            <Button type="button" variant="outline" onClick={handleGoLogin} className="cursor-pointer">
              Ke Halaman Login
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

export default VerifyEmailPage

