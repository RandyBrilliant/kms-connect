import { z } from "zod"

export const companyCreateSchema = z
  .object({
    email: z.string().email("Format email tidak valid"),
    password: z.string().min(8, "Password minimal 8 karakter"),
    confirmPassword: z.string(),
    company_name: z.string().min(1, "Nama perusahaan wajib diisi"),
    contact_phone: z.string().optional(),
    address: z.string().optional(),
    is_active: z.boolean().default(true),
    email_verified: z.boolean().default(false),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Password dan konfirmasi password tidak sama",
    path: ["confirmPassword"],
  })

/** Edit: company can change email and profile data (no password, no email_verified) */
export const companyUpdateSchema = z.object({
  email: z.string().email("Format email tidak valid"),
  company_name: z.string().min(1, "Nama perusahaan wajib diisi"),
  contact_phone: z.string().optional(),
  address: z.string().optional(),
})

export type CompanyCreateSchema = z.infer<typeof companyCreateSchema>
export type CompanyUpdateSchema = z.infer<typeof companyUpdateSchema>

