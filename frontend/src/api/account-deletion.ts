/**
 * Account Deletion Requests API.
 *
 * Admin:
 *   GET  /api/deletion-requests/            – list
 *   GET  /api/deletion-requests/<id>/       – retrieve
 *   POST /api/deletion-requests/<id>/approve/
 *   POST /api/deletion-requests/<id>/reject/
 *
 * Applicant self-service:
 *   POST /api/deletion-requests/submit/     – submit own request
 *   GET  /api/deletion-requests/my/         – view own request
 *   POST /api/deletion-requests/my/cancel/  – cancel own request
 */

import { api } from "@/lib/api"
import type {
  AccountDeletionRequest,
  DeletionRequestSubmitInput,
  DeletionRequestReviewInput,
  DeletionRequestsListParams,
} from "@/types/account-deletion"

function buildQs(params: DeletionRequestsListParams): string {
  const search = new URLSearchParams()
  if (params.status) search.set("status", params.status)
  if (params.search) search.set("search", params.search)
  const qs = search.toString()
  return qs ? `?${qs}` : ""
}

// ---------------------------------------------------------------------------
// Admin
// ---------------------------------------------------------------------------

/** GET /api/deletion-requests/ */
export async function getDeletionRequests(
  params: DeletionRequestsListParams = {}
): Promise<AccountDeletionRequest[]> {
  const { data } = await api.get<{ data: AccountDeletionRequest[] }>(
    `/api/deletion-requests/${buildQs(params)}`
  )
  return data.data
}

/** GET /api/deletion-requests/<id>/ */
export async function getDeletionRequest(id: number): Promise<AccountDeletionRequest> {
  const { data } = await api.get<{ data: AccountDeletionRequest }>(
    `/api/deletion-requests/${id}/`
  )
  return data.data
}

/** POST /api/deletion-requests/<id>/approve/ */
export async function approveDeletionRequest(
  id: number,
  input: DeletionRequestReviewInput = {}
): Promise<AccountDeletionRequest> {
  const { data } = await api.post<{ data: AccountDeletionRequest }>(
    `/api/deletion-requests/${id}/approve/`,
    input
  )
  return data.data
}

/** POST /api/deletion-requests/<id>/reject/ */
export async function rejectDeletionRequest(
  id: number,
  input: DeletionRequestReviewInput = {}
): Promise<AccountDeletionRequest> {
  const { data } = await api.post<{ data: AccountDeletionRequest }>(
    `/api/deletion-requests/${id}/reject/`,
    input
  )
  return data.data
}

// ---------------------------------------------------------------------------
// Applicant self-service
// ---------------------------------------------------------------------------

/** POST /api/deletion-requests/submit/ */
export async function submitDeletionRequest(
  input: DeletionRequestSubmitInput = {}
): Promise<AccountDeletionRequest> {
  const { data } = await api.post<{ data: AccountDeletionRequest }>(
    `/api/deletion-requests/submit/`,
    input
  )
  return data.data
}

/** GET /api/deletion-requests/my/ */
export async function getMyDeletionRequest(): Promise<AccountDeletionRequest | null> {
  const { data } = await api.get<{ data: AccountDeletionRequest | null }>(
    `/api/deletion-requests/my/`
  )
  return data.data
}

/** POST /api/deletion-requests/my/cancel/ */
export async function cancelDeletionRequest(): Promise<AccountDeletionRequest> {
  const { data } = await api.post<{ data: AccountDeletionRequest }>(
    `/api/deletion-requests/my/cancel/`
  )
  return data.data
}
