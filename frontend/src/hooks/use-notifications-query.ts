/**
 * TanStack Query hooks for in-app notifications.
 * Shared by the notifications page and the header dropdown.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"

import {
  deleteNotification,
  getNotifications,
  getUnreadNotificationCount,
  markAllNotificationsRead,
  markNotificationRead,
} from "@/api/notifications"
import type { NotificationsListParams } from "@/types/notification"

export const notificationsKeys = {
  all: ["notifications"] as const,
  lists: () => [...notificationsKeys.all, "list"] as const,
  list: (params: NotificationsListParams) =>
    [...notificationsKeys.lists(), params] as const,
  unreadCount: () => [...notificationsKeys.all, "unread-count"] as const,
}

export function useNotificationsQuery(
  params: NotificationsListParams = {},
  options?: { enabled?: boolean }
) {
  return useQuery({
    queryKey: notificationsKeys.list(params),
    queryFn: () => getNotifications(params),
    enabled: options?.enabled ?? true,
  })
}

export function useUnreadNotificationCountQuery() {
  return useQuery({
    queryKey: notificationsKeys.unreadCount(),
    queryFn: getUnreadNotificationCount,
    refetchInterval: 30_000,
  })
}

export function useMarkNotificationReadMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => markNotificationRead(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: notificationsKeys.all })
    },
  })
}

export function useMarkAllNotificationsReadMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: () => markAllNotificationsRead(),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: notificationsKeys.all })
    },
  })
}

export function useDeleteNotificationMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deleteNotification(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: notificationsKeys.all })
    },
  })
}
