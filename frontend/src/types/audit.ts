/**
 * Audit event types — matches backend audit.AuditEventSerializer.
 */

export type AuditAction =
  | "LOGIN"
  | "LOGIN_FAILED"
  | "LOGOUT"
  | "CREATE"
  | "UPDATE"
  | "DELETE"
  | "ACTIVATE"
  | "DEACTIVATE"
  | "STATUS_CHANGE"
  | "EXPORT"
  | "APPROVE"
  | "REJECT"
  | "PASSWORD_CHANGE"
  | "PASSWORD_RESET"

export type AuditResourceType =
  | "auth"
  | "user"
  | "applicant"
  | "company"
  | "staff"
  | "job"
  | "batch"
  | "cohort"
  | "application"
  | "news"
  | "broadcast"
  | "document"
  | "deletion_request"
  | "export"

export interface AuditEvent {
  id: number
  created_at: string
  actor: number | null
  actor_email: string
  actor_role: string
  actor_name: string
  action: AuditAction
  action_display: string
  resource_type: AuditResourceType
  resource_type_display: string
  resource_id: string
  resource_label: string
  summary: string
  ip_address: string | null
  user_agent: string
  metadata: Record<string, unknown>
}

export interface AuditEventsListParams {
  page_size?: number
  cursor?: string | null
  search?: string
  action?: AuditAction | ""
  resource_type?: AuditResourceType | ""
  actor?: number
  created_after?: string
  created_before?: string
}

/** Cursor-paginated list (no total count). */
export interface CursorPaginatedResponse<T> {
  next: string | null
  previous: string | null
  results: T[]
}

export const AUDIT_ACTION_LABELS: Record<AuditAction, string> = {
  LOGIN: "Login",
  LOGIN_FAILED: "Login gagal",
  LOGOUT: "Logout",
  CREATE: "Buat",
  UPDATE: "Ubah",
  DELETE: "Hapus",
  ACTIVATE: "Aktifkan",
  DEACTIVATE: "Nonaktifkan",
  STATUS_CHANGE: "Ubah status",
  EXPORT: "Ekspor",
  APPROVE: "Setujui",
  REJECT: "Tolak",
  PASSWORD_CHANGE: "Ubah password",
  PASSWORD_RESET: "Reset password",
}

export const AUDIT_RESOURCE_LABELS: Record<AuditResourceType, string> = {
  auth: "Autentikasi",
  user: "Pengguna",
  applicant: "Pelamar",
  company: "Perusahaan",
  staff: "Staf",
  job: "Lowongan",
  batch: "Batch",
  cohort: "Sesi interview",
  application: "Lamaran",
  news: "Berita",
  broadcast: "Broadcast",
  document: "Dokumen",
  deletion_request: "Hapus akun",
  export: "Ekspor",
}
