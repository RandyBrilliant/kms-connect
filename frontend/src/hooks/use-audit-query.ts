/**
 * TanStack Query hooks for audit events (Master Admin).
 */

import { useQuery } from "@tanstack/react-query"
import { getAuditEvent, getAuditEvents } from "@/api/audit"
import type { AuditEventsListParams } from "@/types/audit"

export const auditKeys = {
  all: ["audit-events"] as const,
  lists: () => [...auditKeys.all, "list"] as const,
  list: (params: AuditEventsListParams) => [...auditKeys.lists(), params] as const,
  details: () => [...auditKeys.all, "detail"] as const,
  detail: (id: number) => [...auditKeys.details(), id] as const,
}

export function useAuditEventsQuery(params: AuditEventsListParams = {}) {
  return useQuery({
    queryKey: auditKeys.list(params),
    queryFn: () => getAuditEvents(params),
  })
}

export function useAuditEventQuery(id: number | null, enabled = true) {
  return useQuery({
    queryKey: auditKeys.detail(id ?? 0),
    queryFn: () => getAuditEvent(id!),
    enabled: enabled && id != null && id > 0,
  })
}
