/**
 * TanStack Query invalidation after cohort-scoped application changes.
 */

import type { QueryClient } from "@tanstack/react-query"

export function invalidateCohortDashboardCaches(
  qc: QueryClient,
  opts: {
    cohortId: number
    jobId: number
    /** e.g. move-applicants target cohort */
    extraCohortIds?: number[]
  }
) {
  const cohortIds = new Set([
    opts.cohortId,
    ...(opts.extraCohortIds ?? []).filter((id) => id > 0),
  ])
  void qc.invalidateQueries({ queryKey: ["applications"] })
  for (const cid of cohortIds) {
    void qc.invalidateQueries({ queryKey: ["cohort-applications", cid] })
    void qc.invalidateQueries({ queryKey: ["cohort-diterima-apps", cid] })
    void qc.invalidateQueries({ queryKey: ["interview-cohort", cid] })
  }
  void qc.invalidateQueries({ queryKey: ["interview-cohorts"] })
  void qc.invalidateQueries({ queryKey: ["batches", { job: opts.jobId }] })
}
