/**
 * News (Berita) types - matches backend main.NewsSerializer.
 */

export type NewsStatus = "DRAFT" | "PUBLISHED" | "ARCHIVED"

export interface NewsItem {
  id: number
  title: string
  slug: string
  summary: string
  content: string
  hero_image: string | null
  status: NewsStatus
  is_pinned: boolean
  published_at: string | null
  created_by: number | null
  created_by_name?: string | null
  created_at: string
  updated_at: string
}

export interface NewsListParams {
  page?: number
  page_size?: number
  search?: string
  status?: NewsStatus | "ALL"
  ordering?: string
}

