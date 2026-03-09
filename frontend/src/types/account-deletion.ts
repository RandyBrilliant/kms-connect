/**
 * Account Deletion Request types — matches AccountDeletionRequestSerializer.
 */

export type DeletionRequestStatus = "PENDING" | "APPROVED" | "REJECTED" | "CANCELLED"

export interface AccountDeletionRequest {
  id: number
  user: number
  user_email: string
  user_full_name: string
  user_role: string
  reason: string
  status: DeletionRequestStatus
  requested_at: string
  reviewed_at: string | null
  reviewed_by: number | null
  reviewed_by_email: string | null
  admin_notes: string
}

export interface DeletionRequestSubmitInput {
  reason?: string
}

export interface DeletionRequestReviewInput {
  admin_notes?: string
}

export interface DeletionRequestsListParams {
  status?: DeletionRequestStatus
  search?: string
}
