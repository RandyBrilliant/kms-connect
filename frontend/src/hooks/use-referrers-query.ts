/**
 * TanStack Query hook for referrers list (Staff + Admin for pemberi rujukan dropdown).
 */

import { useQuery } from "@tanstack/react-query"
import { getReferrers } from "@/api/referrers"

export const referrersKeys = {
  all: ["referrers"] as const,
}

export function useReferrersQuery() {
  return useQuery({
    queryKey: referrersKeys.all,
    queryFn: () => getReferrers(),
  })
}
