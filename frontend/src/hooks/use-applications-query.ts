/**
 * TanStack Query hooks for JobApplication CRUD + assign + transition.
 */

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"

import {
  getApplications,
  getApplication,
  assignApplication,
  transitionApplication,
  patchApplication,
} from "@/api/applications"
import type {
  ApplicationsListParams,
  AssignApplicationInput,
  TransitionApplicationInput,
  JobApplication,
} from "@/types/job-applications"

export const applicationsKeys = {
  all: ["applications"] as const,
  lists: () => [...applicationsKeys.all, "list"] as const,
  list: (params: ApplicationsListParams) =>
    [...applicationsKeys.lists(), params] as const,
  details: () => [...applicationsKeys.all, "detail"] as const,
  detail: (id: number) => [...applicationsKeys.details(), id] as const,
}

export function useApplicationsQuery(params: ApplicationsListParams = {}, enabled = true) {
  return useQuery({
    queryKey: applicationsKeys.list(params),
    queryFn: () => getApplications(params),
    enabled,
  })
}

export function useApplicationQuery(id: number | null, enabled = true) {
  return useQuery({
    queryKey: applicationsKeys.detail(id ?? 0),
    queryFn: () => getApplication(id!),
    enabled: enabled && id != null && id > 0,
  })
}

export function useAssignApplicationMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: AssignApplicationInput) => assignApplication(input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: applicationsKeys.lists() })
    },
  })
}

export function useTransitionApplicationMutation(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: TransitionApplicationInput) =>
      transitionApplication(id, input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: applicationsKeys.lists() })
      queryClient.invalidateQueries({ queryKey: applicationsKeys.detail(id) })
    },
  })
}

export function usePatchApplicationMutation(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: Pick<JobApplication, "notes">) =>
      patchApplication(id, input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: applicationsKeys.detail(id) })
    },
  })
}
