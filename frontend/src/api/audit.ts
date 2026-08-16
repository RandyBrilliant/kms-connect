/**
 * Audit events API — Master Admin only.
 * Backend: /api/audit-events/
 */

import { api } from "@/lib/api"
import type {
  AuditEvent,
  AuditEventsListParams,
  CursorPaginatedResponse,
} from "@/types/audit"

function buildQueryString(params: AuditEventsListParams): string {
  const search = new URLSearchParams()
  if (params.page_size != null) search.set("page_size", String(params.page_size))
  if (params.cursor) search.set("cursor", params.cursor)
  if (params.search) search.set("search", params.search)
  if (params.action) search.set("action", params.action)
  if (params.resource_type) search.set("resource_type", params.resource_type)
  if (params.actor != null) search.set("actor", String(params.actor))
  if (params.created_after) search.set("created_after", params.created_after)
  if (params.created_before) search.set("created_before", params.created_before)
  const qs = search.toString()
  return qs ? `?${qs}` : ""
}

/** Extract cursor query value from a DRF next/previous URL. */
export function cursorFromUrl(url: string | null | undefined): string | null {
  if (!url) return null
  try {
    const parsed = new URL(url, window.location.origin)
    return parsed.searchParams.get("cursor")
  } catch {
    return null
  }
}

/** GET /api/audit-events/ */
export async function getAuditEvents(
  params: AuditEventsListParams = {}
): Promise<CursorPaginatedResponse<AuditEvent>> {
  const { data } = await api.get<CursorPaginatedResponse<AuditEvent>>(
    `/api/audit-events/${buildQueryString(params)}`
  )
  return data
}

/** GET /api/audit-events/:id/ */
export async function getAuditEvent(id: number): Promise<AuditEvent> {
  const { data } = await api.get<AuditEvent>(`/api/audit-events/${id}/`)
  return data
}
