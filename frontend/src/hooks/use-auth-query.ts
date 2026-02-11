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
    // Refetch on window focus only if previously successful
    refetchOnWindowFocus: (query) => {
      // Don't refetch if last attempt failed with 401
      return query.state.status !== "error" || (query.state.error as any)?.response?.status !== 401
    },
    // Refetch on network reconnect only if not 401
    refetchOnReconnect: (query) => {
      return query.state.status !== "error" || (query.state.error as any)?.response?.status !== 401
    },
    // Only refetch every 4 minutes if user is authenticated (not errored with 401)
    refetchInterval: (query) => {
      // Stop interval if query errored with 401 (not authenticated)
      if (query.state.status === "error") {
        const status = (query.state.error as any)?.response?.status
        if (status === 401) {
          return false // Stop refetching
        }
      }
      // Continue refetching if successful or other error
      return query.state.status === "success" ? 4 * 60 * 1000 : false
    },
    // Don't refetch in background
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
