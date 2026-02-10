import { z } from "zod"

export const loginSchema = z.object({
  email: z.string().email("Masukkan email yang valid"),
  password: z.string().min(1, "Password wajib diisi"),
})

export type LoginFormValues = z.infer<typeof loginSchema>
