/**
 * Reusable badge for ApplicationStatus — consistent coloring across all views.
 */

import { Badge } from "@/components/ui/badge"
import {
  APPLICATION_STATUS_LABELS,
  APPLICATION_STATUS_VARIANTS,
  type ApplicationStatus,
} from "@/types/job-applications"

interface ApplicationStatusBadgeProps {
  status: ApplicationStatus
  className?: string
}

export function ApplicationStatusBadge({
  status,
  className,
}: ApplicationStatusBadgeProps) {
  return (
    <Badge variant={APPLICATION_STATUS_VARIANTS[status]} className={className}>
      {APPLICATION_STATUS_LABELS[status] ?? status}
    </Badge>
  )
}
