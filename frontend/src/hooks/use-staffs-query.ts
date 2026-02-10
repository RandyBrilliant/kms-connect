/**
 * TanStack Query hooks for staff users CRUD.
 */

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import {
    getStaffs,
    getStaff,
    createStaff,
    patchStaff,
    deactivateStaff,
    activateStaff,
    sendVerificationEmail,
    sendPasswordResetEmail,
} from "@/api/staff"
import type {
    StaffsListParams,
    StaffUserCreateInput,
    StaffUserUpdateInput,
} from "@/types/staff"

export const staffsKeys = {
    all: ["staffs"] as const,
    lists: () => [...staffsKeys.all, "list"] as const,
    list: (params: StaffsListParams) => [...staffsKeys.lists(), params] as const,
    details: () => [...staffsKeys.all, "detail"] as const,
    detail: (id: number) => [...staffsKeys.details(), id] as const,
}

export function useStaffsQuery(params: StaffsListParams = {}) {
    return useQuery({
        queryKey: staffsKeys.list(params),
        queryFn: () => getStaffs(params),
    })
}

export function useStaffQuery(id: number | null, enabled = true) {
    return useQuery({
        queryKey: staffsKeys.detail(id ?? 0),
        queryFn: () => getStaff(id!),
        enabled: enabled && id != null && id > 0,
    })
}

export function useCreateStaffMutation() {
    const queryClient = useQueryClient()
    return useMutation({
        mutationFn: (input: StaffUserCreateInput) => createStaff(input),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: staffsKeys.lists() })
        },
    })
}

export function useUpdateStaffMutation(id: number) {
    const queryClient = useQueryClient()
    return useMutation({
        mutationFn: (input: Partial<StaffUserUpdateInput>) => patchStaff(id, input),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: staffsKeys.lists() })
            queryClient.invalidateQueries({ queryKey: staffsKeys.detail(id) })
        },
    })
}

export function useDeactivateStaffMutation() {
    const queryClient = useQueryClient()
    return useMutation({
        mutationFn: (id: number) => deactivateStaff(id),
        onSuccess: (_, id) => {
            queryClient.invalidateQueries({ queryKey: staffsKeys.lists() })
            queryClient.invalidateQueries({ queryKey: staffsKeys.detail(id) })
        },
    })
}

export function useActivateStaffMutation() {
    const queryClient = useQueryClient()
    return useMutation({
        mutationFn: (id: number) => activateStaff(id),
        onSuccess: (_, id) => {
            queryClient.invalidateQueries({ queryKey: staffsKeys.lists() })
            queryClient.invalidateQueries({ queryKey: staffsKeys.detail(id) })
        },
    })
}

export function useSendVerificationEmailMutation() {
    const queryClient = useQueryClient()
    return useMutation({
        mutationFn: (userId: number) => sendVerificationEmail(userId),
        onSuccess: (_, userId) => {
            queryClient.invalidateQueries({ queryKey: staffsKeys.detail(userId) })
        },
    })
}

export function useSendPasswordResetMutation() {
    return useMutation({
        mutationFn: (userId: number) => sendPasswordResetEmail(userId),
    })
}
