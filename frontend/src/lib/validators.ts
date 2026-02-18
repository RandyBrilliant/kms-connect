/**
 * Client-side validation utilities.
 * These match the backend validators in backend/account/validators.py
 * for consistent validation across frontend and backend.
 */

// ============================================================================
// NIK Validation (Indonesian ID Number)
// ============================================================================

/**
 * Validate Indonesian NIK (16 digits)
 */
export function validateNIK(nik: string): { valid: boolean; error?: string } {
  if (!nik || nik.trim() === "") {
    return { valid: false, error: "NIK harus diisi" }
  }

  // Remove spaces
  const cleanNIK = nik.replace(/\s/g, "")

  // Must be exactly 16 digits
  if (!/^\d{16}$/.test(cleanNIK)) {
    return { valid: false, error: "NIK harus 16 digit angka" }
  }

  return { valid: true }
}

// ============================================================================
// Phone Number Validation
// ============================================================================

/**
 * Validate Indonesian phone number
 * Accepts: +6281234567890, 081234567890, 6281234567890
 */
export function validatePhone(
  phone: string
): { valid: boolean; error?: string } {
  if (!phone || phone.trim() === "") {
    return { valid: false, error: "Nomor telepon harus diisi" }
  }

  // Remove spaces and dashes
  const cleanPhone = phone.replace(/[\s-]/g, "")

  // Check format
  const patterns = [
    /^\+62\d{9,13}$/, // +6281234567890
    /^0\d{9,12}$/, // 081234567890
    /^62\d{9,13}$/, // 6281234567890
  ]

  const isValid = patterns.some((pattern) => pattern.test(cleanPhone))

  if (!isValid) {
    return {
      valid: false,
      error:
        "Format nomor telepon tidak valid (contoh: +6281234567890 atau 081234567890)",
    }
  }

  return { valid: true }
}

// ============================================================================
// Passport Validation
// ============================================================================

/**
 * Validate passport number (Indonesian format: 2 letters + 7 digits)
 */
export function validatePassport(
  passport: string
): { valid: boolean; error?: string } {
  if (!passport || passport.trim() === "") {
    return { valid: false, error: "Nomor paspor harus diisi" }
  }

  // Remove spaces
  const cleanPassport = passport.replace(/\s/g, "").toUpperCase()

  // Indonesian passport format: 2 letters + 7 digits (e.g., AB1234567)
  if (!/^[A-Z]{2}\d{7}$/.test(cleanPassport)) {
    return {
      valid: false,
      error: "Format paspor tidak valid (contoh: AB1234567)",
    }
  }

  return { valid: true }
}

// ============================================================================
// Date Validation
// ============================================================================

/**
 * Validate birth date (must be between 17-65 years old)
 */
export function validateBirthDate(
  birthDate: string | Date
): { valid: boolean; error?: string } {
  if (!birthDate) {
    return { valid: false, error: "Tanggal lahir harus diisi" }
  }

  const dateObj = typeof birthDate === "string" ? new Date(birthDate) : birthDate
  const today = new Date()
  let age = today.getFullYear() - dateObj.getFullYear()
  const monthDiff = today.getMonth() - dateObj.getMonth()

  if (
    monthDiff < 0 ||
    (monthDiff === 0 && today.getDate() < dateObj.getDate())
  ) {
    age--
  }

  if (age < 17) {
    return { valid: false, error: "Usia minimal 17 tahun" }
  }

  if (age > 65) {
    return { valid: false, error: "Usia maksimal 65 tahun" }
  }

  return { valid: true }
}

/**
 * Validate passport expiry date (must be in the future)
 */
export function validatePassportExpiry(
  expiryDate: string | Date
): { valid: boolean; error?: string } {
  if (!expiryDate) {
    return { valid: false, error: "Tanggal kadaluarsa harus diisi" }
  }

  const dateObj =
    typeof expiryDate === "string" ? new Date(expiryDate) : expiryDate
  const today = new Date()

  if (dateObj <= today) {
    return { valid: false, error: "Paspor sudah kadaluarsa" }
  }

  return { valid: true }
}

/**
 * Validate work experience dates
 */
export function validateWorkDates(
  startDate: string | Date,
  endDate: string | Date | null
): { valid: boolean; error?: string } {
  if (!startDate) {
    return { valid: false, error: "Tanggal mulai harus diisi" }
  }

  const start = typeof startDate === "string" ? new Date(startDate) : startDate

  // If has end date, validate it's after start date
  if (endDate) {
    const end = typeof endDate === "string" ? new Date(endDate) : endDate

    if (end <= start) {
      return {
        valid: false,
        error: "Tanggal selesai harus setelah tanggal mulai",
      }
    }
  }

  return { valid: true }
}

// ============================================================================
// Email Validation
// ============================================================================

/**
 * Validate email format
 */
export function validateEmail(
  email: string
): { valid: boolean; error?: string } {
  if (!email || email.trim() === "") {
    return { valid: false, error: "Email harus diisi" }
  }

  // Basic email regex
  const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

  if (!emailPattern.test(email)) {
    return { valid: false, error: "Format email tidak valid" }
  }

  return { valid: true }
}

// ============================================================================
// Required Field Validation
// ============================================================================

/**
 * Validate required text field
 */
export function validateRequired(
  value: string | null | undefined,
  fieldName: string = "Field"
): { valid: boolean; error?: string } {
  if (!value || value.trim() === "") {
    return { valid: false, error: `${fieldName} harus diisi` }
  }

  return { valid: true }
}

/**
 * Validate minimum length
 */
export function validateMinLength(
  value: string,
  minLength: number,
  fieldName: string = "Field"
): { valid: boolean; error?: string } {
  if (value.length < minLength) {
    return {
      valid: false,
      error: `${fieldName} minimal ${minLength} karakter`,
    }
  }

  return { valid: true }
}

/**
 * Validate maximum length
 */
export function validateMaxLength(
  value: string,
  maxLength: number,
  fieldName: string = "Field"
): { valid: boolean; error?: string } {
  if (value.length > maxLength) {
    return {
      valid: false,
      error: `${fieldName} maksimal ${maxLength} karakter`,
    }
  }

  return { valid: true }
}

// ============================================================================
// Number Validation
// ============================================================================

/**
 * Validate number is within range
 */
export function validateNumberRange(
  value: number,
  min: number,
  max: number,
  fieldName: string = "Nilai"
): { valid: boolean; error?: string } {
  if (value < min || value > max) {
    return {
      valid: false,
      error: `${fieldName} harus antara ${min} dan ${max}`,
    }
  }

  return { valid: true }
}

/**
 * Validate height (in cm)
 */
export function validateHeight(
  height: number
): { valid: boolean; error?: string } {
  return validateNumberRange(height, 100, 250, "Tinggi badan")
}

/**
 * Validate weight (in kg)
 */
export function validateWeight(
  weight: number
): { valid: boolean; error?: string } {
  return validateNumberRange(weight, 30, 200, "Berat badan")
}

// ============================================================================
// File Validation
// ============================================================================

/**
 * Validate file size (in bytes)
 */
export function validateFileSize(
  file: File,
  maxSizeInMB: number = 5
): { valid: boolean; error?: string } {
  const maxBytes = maxSizeInMB * 1024 * 1024

  if (file.size > maxBytes) {
    return {
      valid: false,
      error: `Ukuran file maksimal ${maxSizeInMB} MB`,
    }
  }

  return { valid: true }
}

/**
 * Validate file type
 */
export function validateFileType(
  file: File,
  allowedTypes: string[]
): { valid: boolean; error?: string } {
  if (!allowedTypes.includes(file.type)) {
    return {
      valid: false,
      error: `Tipe file tidak valid. Hanya ${allowedTypes.join(", ")} yang diperbolehkan`,
    }
  }

  return { valid: true }
}

/**
 * Validate image file (JPEG, PNG only, max 5MB)
 */
export function validateImageFile(
  file: File
): { valid: boolean; error?: string } {
  // Check type
  const typeCheck = validateFileType(file, ["image/jpeg", "image/png"])
  if (!typeCheck.valid) {
    return typeCheck
  }

  // Check size
  const sizeCheck = validateFileSize(file, 5)
  if (!sizeCheck.valid) {
    return sizeCheck
  }

  return { valid: true }
}

/**
 * Validate document file (PDF only, max 10MB)
 */
export function validateDocumentFile(
  file: File
): { valid: boolean; error?: string } {
  // Check type
  const typeCheck = validateFileType(file, ["application/pdf"])
  if (!typeCheck.valid) {
    return { valid: false, error: "Hanya file PDF yang diperbolehkan" }
  }

  // Check size
  const sizeCheck = validateFileSize(file, 10)
  if (!sizeCheck.valid) {
    return sizeCheck
  }

  return { valid: true }
}
