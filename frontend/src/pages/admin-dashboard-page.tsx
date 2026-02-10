import { SectionCards } from "@/components/section-cards"
import { ApplicantGrowthChart } from "@/components/dashboard/applicant-growth-chart"
import { LatestApplicantsTable } from "@/components/dashboard/latest-applicants-table"
import {
  useAdminApplicantSummaryQuery,
  useAdminApplicantTimeseriesQuery,
  useAdminLatestApplicantsQuery,
} from "@/hooks/use-dashboard-query"

export function AdminDashboardPage() {
  const { data: summary, isLoading: loadingSummary } =
    useAdminApplicantSummaryQuery()
  const { data: timeseries = [], isLoading: loadingTimeseries } =
    useAdminApplicantTimeseriesQuery()
  const { data: latest = [], isLoading: loadingLatest } =
    useAdminLatestApplicantsQuery()

  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:gap-6 md:px-8 md:py-8">
      {/* Summary cards */}
      {summary ? (
        <SectionCards
          totalApplicants={summary.total_applicants}
          totalActiveWorkers={summary.total_active_workers}
          totalInactiveWorkers={summary.total_inactive_workers}
          growthRate30d={summary.growth_rate_30d}
        />
      ) : (
        loadingSummary && (
          <div className="grid grid-cols-1 gap-4 @xl/main:grid-cols-2 @5xl/main:grid-cols-4">
            {Array.from({ length: 4 }).map((_, i) => (
              <div
                key={i}
                className="h-24 animate-pulse rounded-xl bg-muted/60"
              />
            ))}
          </div>
        )
      )}

      {/* Applicants growth chart */}
      <ApplicantGrowthChart data={timeseries} isLoading={loadingTimeseries} />

      {/* Latest applicants table */}
      <LatestApplicantsTable data={latest} isLoading={loadingLatest} />
    </div>
  )
}
