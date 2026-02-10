/**
 * TanStack Query hooks for Lowongan Kerja CRUD.
 */

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"

import { getJobs, getJob, createJob, patchJob, deleteJob } from "@/api/jobs"
import type { JobsListParams, JobItem } from "@/types/jobs"

export const jobsKeys = {
  all: ["jobs"] as const,
  lists: () => [...jobsKeys.all, "list"] as const,
  list: (params: JobsListParams) => [...jobsKeys.lists(), params] as const,
  details: () => [...jobsKeys.all, "detail"] as const,
  detail: (id: number) => [...jobsKeys.details(), id] as const,
}

export function useJobsQuery(params: JobsListParams = {}) {
  return useQuery({
    queryKey: jobsKeys.list(params),
    queryFn: () => getJobs(params),
  })
}

export function useJobQuery(id: number | null, enabled = true) {
  return useQuery({
    queryKey: jobsKeys.detail(id ?? 0),
    queryFn: () => getJob(id!),
    enabled: enabled && id != null && id > 0,
  })
}

export function useCreateJobMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: Partial<JobItem>) => createJob(input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: jobsKeys.lists() })
    },
  })
}

export function useUpdateJobMutation(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: Partial<JobItem>) => patchJob(id, input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: jobsKeys.lists() })
      queryClient.invalidateQueries({ queryKey: jobsKeys.detail(id) })
    },
  })
}

export function useDeleteJobMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deleteJob(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: jobsKeys.lists() })
    },
  })
}

