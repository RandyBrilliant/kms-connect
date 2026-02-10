/**
 * News API - CRUD for berita (admin-side).
 * Backend: /api/news/
 */

import { api } from "@/lib/api"
import type { PaginatedResponse } from "@/types/admin"
import type { NewsItem, NewsListParams } from "@/types/news"

function buildQueryString(params: NewsListParams): string {
  const search = new URLSearchParams()
  if (params.page != null) search.set("page", String(params.page))
  if (params.page_size != null) search.set("page_size", String(params.page_size))
  if (params.search) search.set("search", params.search)
  if (params.status && params.status !== "ALL") search.set("status", params.status)
  if (params.ordering) search.set("ordering", params.ordering)
  const qs = search.toString()
  return qs ? `?${qs}` : ""
}

/** GET /api/news/ - List with pagination, search, filter */
export async function getNews(
  params: NewsListParams = {}
): Promise<PaginatedResponse<NewsItem>> {
  const { data } = await api.get<PaginatedResponse<NewsItem>>(
    `/api/news/${buildQueryString(params)}`
  )
  return data
}

/** GET /api/news/:id/ - Retrieve single news */
export async function getNewsItem(id: number): Promise<NewsItem> {
  const { data } = await api.get<NewsItem>(`/api/news/${id}/`)
  return data
}

/** POST /api/news/ - Create news (with optional hero image) */
export async function createNews(
  input: Partial<NewsItem>,
  heroImage?: File | null
): Promise<NewsItem> {
  // When there's an image, send multipart/form-data
  if (heroImage) {
    const formData = new FormData()
    if (input.title != null) formData.set("title", String(input.title))
    if (input.slug != null) formData.set("slug", String(input.slug))
    if (input.summary != null) formData.set("summary", String(input.summary))
    if (input.content != null) formData.set("content", String(input.content))
    if (input.status != null) formData.set("status", String(input.status))
    if (input.is_pinned != null)
      formData.set("is_pinned", input.is_pinned ? "true" : "false")

    formData.set("hero_image", heroImage)

    const { data } = await api.post<NewsItem>("/api/news/", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    })
    return data
  }

  const { data } = await api.post<NewsItem>("/api/news/", input)
  return data
}

/** PATCH /api/news/:id/ - Partial update (with optional hero image) */
export async function patchNews(
  id: number,
  input: Partial<NewsItem>,
  heroImage?: File | null
): Promise<NewsItem> {
  if (heroImage) {
    const formData = new FormData()
    if (input.title != null) formData.set("title", String(input.title))
    if (input.slug != null) formData.set("slug", String(input.slug))
    if (input.summary != null) formData.set("summary", String(input.summary))
    if (input.content != null) formData.set("content", String(input.content))
    if (input.status != null) formData.set("status", String(input.status))
    if (input.is_pinned != null)
      formData.set("is_pinned", input.is_pinned ? "true" : "false")

    formData.set("hero_image", heroImage)

    const { data } = await api.patch<NewsItem>(`/api/news/${id}/`, formData, {
      headers: { "Content-Type": "multipart/form-data" },
    })
    return data
  }

  const { data } = await api.patch<NewsItem>(`/api/news/${id}/`, input)
  return data
}

/** DELETE /api/news/:id/ */
export async function deleteNews(id: number): Promise<void> {
  await api.delete(`/api/news/${id}/`)
}

