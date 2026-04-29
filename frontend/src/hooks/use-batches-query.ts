/**
 * TanStack Query hooks for LamaranBatch (CRUD + invalidation helpers).
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"

import { assignToBatch, deleteBatch, getBatches } from "@/api/batches"
import { applicationsKeys } from "@/hooks/use-applications-query"

export function useDeleteBatchMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deleteBatch(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["batches"] })
      queryClient.invalidateQueries({ queryKey: ["batch"] })
      queryClient.invalidateQueries({ queryKey: ["applications"] })
      queryClient.invalidateQueries({ queryKey: ["batch-announcements"] })
    },
  })
}

/** Batches for a single job — used by pelamar quick-assign and similar flows. */
export function useBatchesForJobQuery(jobId: number | null, enabled = true) {
  return useQuery({
    queryKey: ["batches", { job: jobId ?? 0, scope: "for-job" }],
    queryFn: () =>
      getBatches({
        job: jobId!,
        page_size: 200,
        ordering: "-created_at",
      }),
    enabled: enabled && jobId != null && jobId > 0,
    staleTime: 30_000,
  })
}

export function useAssignApplicantsToBatchMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: {
      batchId: number
      applicantProfileIds: number[]
      note?: string
    }) =>
      assignToBatch(input.batchId, {
        applicant_ids: input.applicantProfileIds,
        note: input.note?.trim(),
      }),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: applicationsKeys.all })
      queryClient.invalidateQueries({ queryKey: ["batches"] })
      queryClient.invalidateQueries({ queryKey: ["batch", variables.batchId] })
      queryClient.invalidateQueries({ queryKey: ["eligible-applicants", variables.batchId] })
    },
  })
}
