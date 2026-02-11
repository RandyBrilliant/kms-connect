/**
 * TanStack Query hooks for authentication and user session management.
 *
 * Token refresh is handled transparently by the axios interceptor (lib/api.ts).
 * This hook simply fetches the current user.  If the access token is expired,
 * the interceptor will refresh it automatically before this query ever sees a 401.
 * A 401 that reaches this hook means the refresh token itself is expired.
 */

import { useQuery } from "@tanstack/react-query"
import { getMe } from "@/api/auth"

export const authKeys = {
  all: ["auth"] as const,
  me: () => [...authKeys.all, "me"] as const,
}

/**
 * Query for current authenticated user.
 *
 * - On mount: calls GET /api/me/.  If access token expired, the axios interceptor
 *   will silently refresh it first, so the query sees a successful response.
 * - While authenticated: refetches every 4 minutes (keeps access token alive)
 *   and on window focus / reconnect.
 * - If not authenticated: runs once, gets 401 (after interceptor tried refresh),
 *   and then stops.  No infinite loop.
 */
export function useMeQuery() {
  return useQuery({
    queryKey: authKeys.me(),
    queryFn: getMe,
    // Cache user data
    staleTime: 5 * 60 * 1000,  // 5 min - data considered fresh
    gcTime: 30 * 60 * 1000,    // 30 min - keep in garbage-collection cache
    // Don't retry on failure - the interceptor already tried refreshing
    retry: false,
    // Only auto-refetch when we have a user (authenticated)
    refetchOnWindowFocus: (query) => query.state.data != null,
    refetchOnReconnect: (query) => query.state.data != null,
    refetchInterval: (query) =>
      query.state.data != null ? 4 * 60 * 1000 : false,
    refetchIntervalInBackground: false,
  })
}
