import { z } from "zod"

const nikSchema = z
  .string()
  .min(16, "NIK harus 16 digit")
  .max(16, "NIK harus 16 digit")
  .regex(/^\d+$/, "NIK harus angka saja")

/** Create pelamar: account + full biodata (required: email, password, full_name, nik). */
export const applicantCreateSchema = z
  .object({
    // Account (required)
    email: z.string().email("Format email tidak valid"),
    password: z.string().min(8, "Password minimal 8 karakter"),
    confirmPassword: z.string(),
    // Biodata required
    full_name: z.string().min(1, "Nama lengkap wajib diisi"),
    nik: nikSchema,
    // Biodata optional – data CPMI
    birth_place: z.number().int().positive().nullable().optional(),
    birth_date: z.string().nullable().optional(),
    address: z.string().optional(),
    province: z.number().int().positive().nullable().optional(),
    district: z.number().int().positive().nullable().optional(),
    village: z.number().int().positive().nullable().optional(),
    contact_phone: z.string().optional(),
    gender: z.enum(["M", "F", "O", ""]).optional(),
    // Data keluarga
    sibling_count: z.number().int().min(0).nullable().optional(),
    birth_order: z.number().int().min(0).nullable().optional(),
    father_name: z.string().optional(),
    father_age: z.number().int().min(0).nullable().optional(),
    father_occupation: z.string().optional(),
    father_phone: z.string().optional(),
    father_almarhum: z.boolean().optional(),
    mother_name: z.string().optional(),
    mother_age: z.number().int().min(0).nullable().optional(),
    mother_occupation: z.string().optional(),
    mother_phone: z.string().optional(),
    mother_almarhum: z.boolean().optional(),
    spouse_name: z.string().optional(),
    spouse_age: z.number().int().min(0).nullable().optional(),
    spouse_occupation: z.string().optional(),
    spouse_almarhum: z.boolean().optional(),
    family_address: z.string().optional(),
    family_province: z.number().int().positive().nullable().optional(),
    family_district: z.number().int().positive().nullable().optional(),
    family_village: z.number().int().positive().nullable().optional(),
    // Ahli waris (next of kin)
    heir_name: z.string().optional(),
    heir_relationship: z.string().optional(),
    heir_contact_phone: z.string().optional(),
    // Data pribadi
    religion: z.string().optional(),
    education_level: z.string().optional(),
    education_major: z.string().optional(),
    marital_status: z.string().optional(),
    height_cm: z.number().int().min(0).nullable().optional(),
    weight_kg: z.number().int().min(0).nullable().optional(),
    wears_glasses: z.boolean().nullable().optional(),
    writing_hand: z.string().optional(),
    // Paspor
    passport_number: z.string().optional(),
    passport_issue_date: z.string().nullable().optional(),
    passport_issue_place: z.string().optional(),
    passport_expiry_date: z.string().nullable().optional(),
    // Rujukan & catatan
    referrer: z.number().int().positive().nullable().optional(),
    notes: z.string().optional(),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Password dan konfirmasi password tidak sama",
    path: ["confirmPassword"],
  })

export const applicantProfileUpdateSchema = z.object({
  full_name: z.string().min(1, "Nama lengkap wajib diisi").optional(),
  nik: nikSchema.optional(),
  birth_place: z.number().int().positive().nullable().optional(),
  birth_date: z.string().nullable().optional(),
  address: z.string().optional(),
  province: z.number().int().positive().nullable().optional(),
  district: z.number().int().positive().nullable().optional(),
  village: z.number().int().positive().nullable().optional(),
  contact_phone: z.string().optional(),
  gender: z.enum(["M", "F", "O", ""]).optional(),
  sibling_count: z.number().int().min(0).nullable().optional(),
  birth_order: z.number().int().min(0).nullable().optional(),
  father_name: z.string().optional(),
  father_age: z.number().int().min(0).nullable().optional(),
  father_occupation: z.string().optional(),
  father_phone: z.string().optional(),
  father_almarhum: z.boolean().optional(),
  mother_name: z.string().optional(),
  mother_age: z.number().int().min(0).nullable().optional(),
  mother_occupation: z.string().optional(),
  mother_phone: z.string().optional(),
  mother_almarhum: z.boolean().optional(),
  spouse_name: z.string().optional(),
  spouse_age: z.number().int().min(0).nullable().optional(),
  spouse_occupation: z.string().optional(),
  spouse_almarhum: z.boolean().optional(),
  family_address: z.string().optional(),
  family_province: z.number().int().positive().nullable().optional(),
  family_district: z.number().int().positive().nullable().optional(),
  family_village: z.number().int().positive().nullable().optional(),
  // Ahli waris (next of kin)
  heir_name: z.string().optional(),
  heir_relationship: z.string().optional(),
  heir_contact_phone: z.string().optional(),
  religion: z.string().optional(),
  education_level: z.string().optional(),
  education_major: z.string().optional(),
  diploma_number: z.string().optional(),
  marital_status: z.string().optional(),
  height_cm: z.number().int().min(0).nullable().optional(),
  weight_kg: z.number().int().min(0).nullable().optional(),
  wears_glasses: z.boolean().nullable().optional(),
  writing_hand: z.string().optional(),
  passport_number: z.string().optional(),
  passport_issue_date: z.string().nullable().optional(),
  passport_issue_place: z.string().optional(),
  passport_expiry_date: z.string().nullable().optional(),
  referrer: z.number().int().positive().nullable().optional(),
  notes: z.string().optional(),
  // Admin-only process & finance fields
  tgl_medical: z.string().nullable().optional(),
  hasil_medical: z.string().optional(),
  tgl_bayar_sml: z.string().nullable().optional(),
  tgl_fwcm_psikotes: z.string().nullable().optional(),
  tgl_bayar_psikotes: z.string().nullable().optional(),
  tgl_bayar_bpjs_pra: z.string().nullable().optional(),
  tgl_bayar_bpjs_purna: z.string().nullable().optional(),
  no_id_sisko: z.string().optional(),
  disnaker: z.string().optional(),
  no_sip: z.string().optional(),
  no_jo: z.string().optional(),
  biaya_ready_paspor: z.number().nullable().optional(),
  pengembalian_biaya: z.number().nullable().optional(),
  tgl_pengembalian: z.string().nullable().optional(),
  jlh_uang_transport: z.number().nullable().optional(),
  bank: z.string().optional(),
  no_rek: z.string().optional(),
  tanggal_pengembalian: z.string().nullable().optional(),
  tgl_kirim_bio_ke_mly: z.string().nullable().optional(),
  tgl_calling_visa: z.string().nullable().optional(),
  no_calling_visa: z.string().optional(),
  verification_status: z
    .enum(["DRAFT", "SUBMITTED", "ACCEPTED", "REJECTED"])
    .optional(),
  verification_notes: z.string().optional(),
})

export const workExperienceSchema = z
  .object({
    company_name: z.string().min(1, "Nama perusahaan wajib diisi"),
    location: z.string().optional(),
    country: z.string().max(2).optional(),
    industry_type: z.string().optional(),
    position: z.string().optional(),
    department: z.string().optional(),
    start_date: z.string().nullable().optional(),
    end_date: z.string().nullable().optional(),
    still_employed: z.boolean().optional(),
    description: z.string().optional(),
    sort_order: z.number().int().min(0).optional(),
  })
  .refine(
    (data) => {
      // If still_employed is true, end_date should be null (handled by UI)
      if (data.still_employed) return true
      // If both dates are provided, end_date must be >= start_date
      if (data.start_date && data.end_date) {
        const start = new Date(data.start_date)
        const end = new Date(data.end_date)
        return end >= start
      }
      return true
    },
    {
      message: "Tanggal selesai harus lebih besar atau sama dengan tanggal mulai",
      path: ["end_date"],
    }
  )

export type ApplicantCreateSchema = z.infer<typeof applicantCreateSchema>
export type ApplicantProfileUpdateSchema = z.infer<
  typeof applicantProfileUpdateSchema
>
export type WorkExperienceSchema = z.infer<typeof workExperienceSchema>
