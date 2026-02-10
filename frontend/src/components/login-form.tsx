import { useState } from "react"
import type { AxiosError } from "axios"
import { useForm } from "@tanstack/react-form"
import { EyeIcon, EyeOffIcon } from "lucide-react"
import { cn } from "@/lib/utils"
import { toast } from "@/lib/toast"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { useLoginMutation } from "@/hooks/use-login-mutation"
import { requestPasswordReset } from "@/api/auth"
import type { ApiErrorResponse } from "@/types/api"
import type { LoginFormValues } from "@/schemas/login"
import { forgotPasswordSchema } from "@/schemas/forgot-password"

import logoImg from "@/img/logo.png"

export function LoginForm({ className, ...props }: React.ComponentProps<"div">) {
  const [showPassword, setShowPassword] = useState(false)
  const [forgotOpen, setForgotOpen] = useState(false)
  const [forgotEmail, setForgotEmail] = useState("")
  const [forgotLoading, setForgotLoading] = useState(false)

  // Backend field-level errors (from ApiErrorResponse.errors)
  const [serverFieldErrors, setServerFieldErrors] = useState<
    Partial<Record<keyof LoginFormValues, string>>
  >({})

  const mutation = useLoginMutation()

  const form = useForm({
    defaultValues: {
      email: "",
      password: "",
    },
    onSubmit: async ({ value }) => {
      setServerFieldErrors({})
      try {
        await mutation.mutateAsync(value)
      } catch (err: unknown) {
        const axiosError = err as AxiosError<ApiErrorResponse>
        const data = axiosError.response?.data

        // Map backend field errors (if any) to our local state
        if (data?.errors) {
          const next: Partial<Record<keyof LoginFormValues, string>> = {}
          if (Array.isArray(data.errors.email) && data.errors.email.length) {
            next.email = data.errors.email[0]
          }
          if (Array.isArray(data.errors.password) && data.errors.password.length) {
            next.password = data.errors.password[0]
          }
          setServerFieldErrors(next)
        }

        const message =
          data?.detail ??
          (err instanceof Error ? err.message : "Login gagal. Coba lagi.")
        toast.error("Login gagal", message)
      }
    },
  })

  const handleForgotSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const result = forgotPasswordSchema.safeParse({ email: forgotEmail })
    if (!result.success) {
      toast.error("Email tidak valid", result.error.issues[0]?.message)
      return
    }
    setForgotLoading(true)
    try {
      await requestPasswordReset(result.data.email)
      toast.success(
        "Permintaan dikirim",
        "Jika email terdaftar, tautan reset password akan dikirim."
      )
      setForgotOpen(false)
      setForgotEmail("")
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { detail?: string } } })?.response?.data
          ?.detail ?? "Gagal mengirim permintaan. Coba lagi."
      toast.error("Gagal", message)
    } finally {
      setForgotLoading(false)
    }
  }

  return (
    <div className={cn("flex flex-col gap-6", className)} {...props}>
      <Card>
        <CardHeader className="flex flex-col items-center gap-4 text-center">
          <img
            src={logoImg}
            alt="KMS-Connect"
            className="h-20 w-auto object-contain"
          />
          <div>
            <CardTitle className="text-2xl font-bold mb-2">KMS Connect Dashboard</CardTitle>
            <CardDescription className="text-sm text-muted-foreground">
              Masukkan email dan password untuk mengakses dashboard KMS-Connect
            </CardDescription>
          </div>
        </CardHeader>
        <CardContent>
          <form
            onSubmit={(e) => {
              e.preventDefault()
              e.stopPropagation()
              void form.handleSubmit()
            }}
          >
            <FieldGroup>
              <form.Field
                name="email"
              >
                {(field) => (
                  <Field>
                    <FieldLabel htmlFor={field.name}>Email</FieldLabel>
                    <Input
                      id={field.name}
                      type="email"
                      placeholder="john@kms-connect.com"
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                      disabled={mutation.isPending}
                      autoComplete="email"
                    />
                    <FieldError>
                      {(() => {
                        const err = field.state.meta.errors[0]
                        if (!err) return serverFieldErrors.email
                        if (typeof err === "string") return err
                        return (err as { message?: string }).message ?? serverFieldErrors.email
                      })()}
                    </FieldError>
                  </Field>
                )}
              </form.Field>
              <form.Field
                name="password"
              >
                {(field) => (
                  <Field>
                    <div className="flex items-center justify-between">
                      <FieldLabel htmlFor={field.name}>Password</FieldLabel>
                      <Dialog open={forgotOpen} onOpenChange={setForgotOpen}>
                        <DialogTrigger asChild>
                          <button
                            type="button"
                            className="text-muted-foreground hover:text-foreground text-sm underline-offset-4 hover:underline cursor-pointer"
                          >
                            Lupa password?
                          </button>
                        </DialogTrigger>
                        <DialogContent>
                          <DialogHeader>
                            <DialogTitle>Lupa Password</DialogTitle>
                            <DialogDescription>
                              Masukkan email Anda. Jika terdaftar, kami akan mengirim
                              tautan untuk mengatur ulang password.
                            </DialogDescription>
                          </DialogHeader>
                          <form onSubmit={handleForgotSubmit}>
                            <Field className="py-4">
                              <FieldLabel htmlFor="forgot-email">Email</FieldLabel>
                              <Input
                                id="forgot-email"
                                type="email"
                                placeholder="email@contoh.com"
                                value={forgotEmail}
                                onChange={(e) => setForgotEmail(e.target.value)}
                                disabled={forgotLoading}
                                autoComplete="email"
                              />
                            </Field>
                            <DialogFooter>
                              <Button
                                type="button"
                                variant="outline"
                                onClick={() => setForgotOpen(false)}
                              >
                                Batal
                              </Button>
                              <Button type="submit" disabled={forgotLoading}>
                                {forgotLoading ? "Mengirim..." : "Kirim tautan reset"}
                              </Button>
                            </DialogFooter>
                          </form>
                        </DialogContent>
                      </Dialog>
                    </div>
                    <div className="relative">
                      <Input
                        id={field.name}
                        type={showPassword ? "text" : "password"}
                        value={field.state.value}
                        onChange={(e) => field.handleChange(e.target.value)}
                        onBlur={field.handleBlur}
                        disabled={mutation.isPending}
                        autoComplete="current-password"
                        className="pr-10"
                      />
                      <button
                        type="button"
                        onClick={() => setShowPassword((p) => !p)}
                        className="text-muted-foreground hover:text-foreground absolute top-1/2 right-3 -translate-y-1/2"
                        tabIndex={-1}
                        aria-label={showPassword ? "Sembunyikan password" : "Tampilkan password"}
                      >
                        {showPassword ? (
                          <EyeOffIcon className="size-4" />
                        ) : (
                          <EyeIcon className="size-4" />
                        )}
                      </button>
                    </div>
                    <FieldError>
                      {(() => {
                        const err = field.state.meta.errors[0]
                        if (!err) return serverFieldErrors.password
                        if (typeof err === "string") return err
                        return (err as { message?: string }).message ?? serverFieldErrors.password
                      })()}
                    </FieldError>
                  </Field>
                )}
              </form.Field>
              <Field>
                <Button
                  type="submit"
                  disabled={mutation.isPending}
                  className="w-full cursor-pointer"
                >
                  {mutation.isPending ? "Memproses..." : "Login"}
                </Button>
              </Field>
            </FieldGroup>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}
