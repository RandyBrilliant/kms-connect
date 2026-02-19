import { z } from "zod"

export const staffCreateSchema = z
  .object({
    email: z.string().trim().email("Format email tidak valid"),
    password: z.string().min(8, "Password minimal 8 karakter"),
    confirmPassword: z.string(),
    full_name: z.string().trim().min(1, "Nama lengkap wajib diisi"),
    contact_phone: z.string().trim().optional(),
    is_active: z.boolean().default(true),
    email_verified: z.boolean().default(false),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Password dan konfirmasi password tidak sama",
    path: ["confirmPassword"],
  })

/** Edit: staff can only change email and profile data (no password, no email_verified) */
export const staffUpdateSchema = z.object({
  email: z.string().trim().email("Format email tidak valid"),
  full_name: z.string().trim().min(1, "Nama lengkap wajib diisi"),
  contact_phone: z.string().trim().optional(),
})

export type StaffCreateSchema = z.infer<typeof staffCreateSchema>
export type StaffUpdateSchema = z.infer<typeof staffUpdateSchema>
