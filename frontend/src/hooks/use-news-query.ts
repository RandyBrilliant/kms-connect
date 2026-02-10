/**
 * TanStack Query hooks for News CRUD.
 */

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"

import { getNews, getNewsItem, createNews, patchNews, deleteNews } from "@/api/news"
import type { NewsListParams, NewsItem } from "@/types/news"

export const newsKeys = {
  all: ["news"] as const,
  lists: () => [...newsKeys.all, "list"] as const,
  list: (params: NewsListParams) => [...newsKeys.lists(), params] as const,
  details: () => [...newsKeys.all, "detail"] as const,
  detail: (id: number) => [...newsKeys.details(), id] as const,
}

export function useNewsQuery(params: NewsListParams = {}) {
  return useQuery({
    queryKey: newsKeys.list(params),
    queryFn: () => getNews(params),
  })
}

export function useNewsItemQuery(id: number | null, enabled = true) {
  return useQuery({
    queryKey: newsKeys.detail(id ?? 0),
    queryFn: () => getNewsItem(id!),
    enabled: enabled && id != null && id > 0,
  })
}

export function useCreateNewsMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: { values: Partial<NewsItem>; heroImage?: File | null }) =>
      createNews(input.values, input.heroImage),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: newsKeys.lists() })
    },
  })
}

export function useUpdateNewsMutation(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: { values: Partial<NewsItem>; heroImage?: File | null }) =>
      patchNews(id, input.values, input.heroImage),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: newsKeys.lists() })
      queryClient.invalidateQueries({ queryKey: newsKeys.detail(id) })
    },
  })
}

export function useDeleteNewsMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deleteNews(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: newsKeys.lists() })
    },
  })
}

