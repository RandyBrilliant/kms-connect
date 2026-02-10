/**
 * TanStack Query hooks for admin users CRUD.
 */

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import {
  getAdmins,
  getAdmin,
  createAdmin,
  patchAdmin,
  deactivateAdmin,
  activateAdmin,
  sendVerificationEmail,
  sendPasswordResetEmail,
} from "@/api/admins"
import type {
  AdminsListParams,
  AdminUserCreateInput,
  AdminUserUpdateInput,
} from "@/types/admin"

export const adminsKeys = {
  all: ["admins"] as const,
  lists: () => [...adminsKeys.all, "list"] as const,
  list: (params: AdminsListParams) => [...adminsKeys.lists(), params] as const,
  details: () => [...adminsKeys.all, "detail"] as const,
  detail: (id: number) => [...adminsKeys.details(), id] as const,
}

export function useAdminsQuery(params: AdminsListParams = {}) {
  return useQuery({
    queryKey: adminsKeys.list(params),
    queryFn: () => getAdmins(params),
  })
}

export function useAdminQuery(id: number | null, enabled = true) {
  return useQuery({
    queryKey: adminsKeys.detail(id ?? 0),
    queryFn: () => getAdmin(id!),
    enabled: enabled && id != null && id > 0,
  })
}

export function useCreateAdminMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: AdminUserCreateInput) => createAdmin(input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: adminsKeys.lists() })
    },
  })
}

export function useUpdateAdminMutation(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: Partial<AdminUserUpdateInput>) => patchAdmin(id, input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: adminsKeys.lists() })
      queryClient.invalidateQueries({ queryKey: adminsKeys.detail(id) })
    },
  })
}

export function useDeactivateAdminMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deactivateAdmin(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: adminsKeys.lists() })
      queryClient.invalidateQueries({ queryKey: adminsKeys.detail(id) })
    },
  })
}

export function useActivateAdminMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => activateAdmin(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: adminsKeys.lists() })
      queryClient.invalidateQueries({ queryKey: adminsKeys.detail(id) })
    },
  })
}

export function useSendVerificationEmailMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (userId: number) => sendVerificationEmail(userId),
    onSuccess: (_, userId) => {
      queryClient.invalidateQueries({ queryKey: adminsKeys.detail(userId) })
    },
  })
}

export function useSendPasswordResetMutation() {
  return useMutation({
    mutationFn: (userId: number) => sendPasswordResetEmail(userId),
  })
}
