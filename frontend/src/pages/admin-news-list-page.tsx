/**
 * Admin news list page with table, search, filters.
 */

import { NewsTable } from "@/components/news/news-table"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"

// Admin sidebar "Berita" menu points to "/berita"
const BASE_PATH = "/berita"

export function AdminNewsListPage() {
  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: "/" },
          { label: "Berita" },
        ]}
      />
      <h1 className="text-2xl font-bold">Kelola Berita</h1>
      <p className="text-muted-foreground">
        Daftar dan kelola berita yang tampil di halaman utama.
      </p>

      <NewsTable basePath={BASE_PATH} />
    </div>
  )
}

