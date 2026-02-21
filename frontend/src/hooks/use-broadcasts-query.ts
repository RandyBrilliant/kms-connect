/**
 * TanStack Query hooks for Broadcasts CRUD.
 */

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"

import {
  getBroadcasts,
  getBroadcast,
  createBroadcast,
  updateBroadcast,
  patchBroadcast,
  sendBroadcast,
  previewRecipients,
} from "@/api/notifications"
import type {
  BroadcastsListParams,
  BroadcastCreateInput,
  BroadcastUpdateInput,
  RecipientConfig,
} from "@/types/notification"

export const broadcastKeys = {
  all: ["broadcasts"] as const,
  lists: () => [...broadcastKeys.all, "list"] as const,
  list: (params: BroadcastsListParams) => [...broadcastKeys.lists(), params] as const,
  details: () => [...broadcastKeys.all, "detail"] as const,
  detail: (id: number) => [...broadcastKeys.details(), id] as const,
}

/**
 * Fetch paginated list of broadcasts
 */
export function useBroadcastsQuery(params: BroadcastsListParams = {}) {
  return useQuery({
    queryKey: broadcastKeys.list(params),
    queryFn: () => getBroadcasts(params),
  })
}

/**
 * Fetch single broadcast by ID
 */
export function useBroadcastQuery(id: number | null, enabled = true) {
  return useQuery({
    queryKey: broadcastKeys.detail(id ?? 0),
    queryFn: () => getBroadcast(id!),
    enabled: enabled && id != null && id > 0,
  })
}

/**
 * Create a new broadcast
 */
export function useCreateBroadcastMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: BroadcastCreateInput) => createBroadcast(input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: broadcastKeys.lists() })
    },
  })
}

/**
 * Update an existing broadcast (full update)
 */
export function useUpdateBroadcastMutation(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: BroadcastUpdateInput) => updateBroadcast(id, input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: broadcastKeys.lists() })
      queryClient.invalidateQueries({ queryKey: broadcastKeys.detail(id) })
    },
  })
}

/**
 * Partially update a broadcast
 */
export function usePatchBroadcastMutation(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: Partial<BroadcastUpdateInput>) => patchBroadcast(id, input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: broadcastKeys.lists() })
      queryClient.invalidateQueries({ queryKey: broadcastKeys.detail(id) })
    },
  })
}

/**
 * Send a broadcast immediately
 */
export function useSendBroadcastMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => sendBroadcast(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: broadcastKeys.lists() })
    },
  })
}

/**
 * Preview recipient count based on recipient config
 */
export function usePreviewRecipientsMutation() {
  return useMutation({
    mutationFn: (recipientConfig: RecipientConfig) => previewRecipients(recipientConfig),
  })
}
