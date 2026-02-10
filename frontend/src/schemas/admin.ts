import { z } from "zod"

export const adminCreateSchema = z
  .object({
    email: z.string().email("Format email tidak valid"),
    full_name: z.string().optional(),
    password: z.string().min(8, "Password minimal 8 karakter"),
    confirmPassword: z.string(),
    is_active: z.boolean().default(true),
    email_verified: z.boolean().default(false),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Password dan konfirmasi password tidak sama",
    path: ["confirmPassword"],
  })

/** Edit: admin can only change email and full_name (no password, no email_verified) */
export const adminUpdateSchema = z.object({
  email: z.string().email("Format email tidak valid"),
  full_name: z.string().optional(),
})

export type AdminCreateSchema = z.infer<typeof adminCreateSchema>
export type AdminUpdateSchema = z.infer<typeof adminUpdateSchema>
