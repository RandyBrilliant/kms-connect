import { z } from "zod"

export const forgotPasswordSchema = z.object({
  email: z.string().email("Masukkan email yang valid"),
})

export type ForgotPasswordFormValues = z.infer<typeof forgotPasswordSchema>
