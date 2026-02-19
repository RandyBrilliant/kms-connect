/**
 * Biodata form configuration: required vs optional fields and section metadata.
 * Single source of truth for add pelamar and edit biodata tabs.
 * Developer-friendly: add new fields here and in schema; forms stay in sync.
 */

/** Fields that are required when creating a new pelamar (backend-enforced). */
export const REQUIRED_FIELDS_CREATE = [
  "email",
  "password",
  "full_name",
  "nik",
] as const

/** Fields that are required on the biodata profile (create and edit). */
export const REQUIRED_BIODATA_FIELDS = ["full_name", "nik"] as const

export type RequiredBiodataField = (typeof REQUIRED_BIODATA_FIELDS)[number]

/** Section definitions for biodata form layout (title, description). */
export const BIODATA_SECTIONS = {
  account: {
    title: "Informasi Akun",
    description: "Email dan password untuk akun pelamar. Field bertanda * wajib diisi.",
  },
  dataCpmi: {
    title: "Data CPMI",
    description: "Data utama pelamar. Field bertanda * wajib diisi.",
  },
  dataKeluarga: {
    title: "Data Orangtua / Keluarga",
    description: "Ayah, Ibu, Suami/Istri, dan alamat keluarga.",
  },
  dataPribadi: {
    title: "Data Pribadi Tambahan",
    description: "Agama, pendidikan, status pernikahan, dan informasi tambahan.",
  },
  ciriFisik: {
    title: "Ciri Fisik",
    description: "Tinggi, berat badan, dan tangan dominan.",
  },
  dataPaspor: {
    title: "Data Paspor",
    description: "Informasi paspor jika sudah memiliki.",
  },
  referrer: {
    title: "Informasi Rujukan",
    description: "Staff/Admin yang merujuk pelamar (opsional).",
  },
  notes: {
    title: "Catatan",
    description: "Keterangan tambahan.",
  },
} as const

/** Check if a field key is required on create. */
export function isRequiredOnCreate(field: string): boolean {
  return (REQUIRED_FIELDS_CREATE as readonly string[]).includes(field)
}

/** Check if a biodata field is required. */
export function isRequiredBiodata(field: string): boolean {
  return (REQUIRED_BIODATA_FIELDS as readonly string[]).includes(field)
}
