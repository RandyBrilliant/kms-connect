/**
 * TanStack Query hooks for authentication and user session management.
 * Provides automatic token refresh, retry logic, and session persistence.
 */

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getMe, refreshToken as refreshTokenApi } from "@/api/auth"

export const authKeys = {
  all: ["auth"] as const,
  me: () => [...authKeys.all, "me"] as const,
}

/**
 * Query for current authenticated user.
 * Automatically refetches on window focus and reconnect.
 * Retries on network errors but not on 401 (not authenticated).
 */
export function useMeQuery() {
  return useQuery({
    queryKey: authKeys.me(),
    queryFn: getMe,
    // Keep user data in cache for session duration
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 30 * 60 * 1000, // 30 minutes
    // Retry on network errors but not on 401
    retry: (failureCount, error: any) => {
      // Don't retry if user is not authenticated (401)
      if (error?.response?.status === 401) {
        return false
      }
      // Retry network errors up to 2 times
      return failureCount < 2
    },
    retryDelay: 1000,
    // Refetch on window focus to keep session fresh
    refetchOnWindowFocus: true,
    // Refetch on network reconnect
    refetchOnReconnect: true,
    // Refetch every 4 minutes to keep session alive (before 5min token expiry)
    refetchInterval: 4 * 60 * 1000,
    // Only refetch in background if user is authenticated
    refetchIntervalInBackground: false,
  })
}

/**
 * Mutation for refreshing the access token.
 * Should be called before token expires or when 401 is received.
 */
export function useRefreshTokenMutation() {
  const queryClient = useQueryClient()
  
  return useMutation({
    mutationFn: refreshTokenApi,
    onSuccess: () => {
      // After successful refresh, refetch user data to ensure session is valid
      queryClient.invalidateQueries({ queryKey: authKeys.me() })
    },
    onError: () => {
      // If refresh fails, clear user data (session expired)
      queryClient.setQueryData(authKeys.me(), null)
      queryClient.clear()
    },
    // Don't retry refresh - if it fails, session is likely expired
    retry: false,
  })
}

/**
 * Custom hook to trigger token refresh manually.
 * Useful for proactive refresh before token expires.
 */
export function useTokenRefresh() {
  const refreshMutation = useRefreshTokenMutation()
  
  return {
    refresh: refreshMutation.mutate,
    refreshAsync: refreshMutation.mutateAsync,
    isRefreshing: refreshMutation.isPending,
  }
}
