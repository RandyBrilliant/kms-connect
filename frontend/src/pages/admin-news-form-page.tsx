/**
 * News form page - shared for create and edit.
 * /berita/new (create) and /berita/:id/edit (edit)
 */

import { Link, useNavigate, useParams } from "react-router-dom"
import { IconArrowLeft } from "@tabler/icons-react"

import { NewsForm } from "@/components/news/news-form"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Button } from "@/components/ui/button"
import {
  useNewsItemQuery,
  useCreateNewsMutation,
  useUpdateNewsMutation,
} from "@/hooks/use-news-query"
import { toast } from "@/lib/toast"
import type { NewsStatus } from "@/types/news"

// Admin sidebar "Berita" menu points to "/berita"
const BASE_PATH = "/berita"

export function AdminNewsFormPage() {
  const navigate = useNavigate()
  const { id } = useParams<{ id: string }>()
  const isEdit = id !== "new" && id != null
  const newsId = isEdit ? parseInt(id, 10) : null

  const { data: news, isLoading: loadingNews } = useNewsItemQuery(
    newsId ?? null,
    isEdit
  )
  const createMutation = useCreateNewsMutation()
  const updateMutation = useUpdateNewsMutation(newsId ?? 0)

  const handleSubmit = async (
    values: {
      title: string
      slug: string
      summary: string
      content: string
      status: NewsStatus
      is_pinned: boolean
    },
    heroImage?: File | null
  ) => {
    try {
      if (isEdit && newsId) {
        await updateMutation.mutateAsync({ values, heroImage })
        toast.success("Berita diperbarui", "Perubahan berhasil disimpan")
        navigate(BASE_PATH)
      } else {
        await createMutation.mutateAsync({ values, heroImage })
        toast.success("Berita ditambahkan", "Berita baru berhasil dibuat")
        navigate(BASE_PATH)
      }
    } catch (err: unknown) {
      const res = err as {
        response?: { data?: { errors?: Record<string, string[]>; detail?: string } }
      }
      const errors = res?.response?.data?.errors
      const detail = res?.response?.data?.detail
      if (errors) {
        toast.error("Validasi gagal", Object.values(errors).flat().join(". "))
      } else {
        toast.error("Gagal menyimpan", detail ?? "Coba lagi nanti")
      }
      throw err
    }
  }

  if (isEdit && loadingNews) {
    return (
      <div className="flex min-h-[200px] items-center justify-center px-6 py-8">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    )
  }

  if (isEdit && !news && !loadingNews) {
    return (
      <div className="px-6 py-8">
        <p className="text-destructive">Berita tidak ditemukan.</p>
        <Button variant="link" asChild>
          <Link to={BASE_PATH}>Kembali ke daftar</Link>
        </Button>
      </div>
    )
  }

  const isSubmitting =
    createMutation.isPending || updateMutation.isPending
  const pageTitle = isEdit ? "Edit Berita" : "Tambah Berita"
  const breadcrumbItems = isEdit
    ? [
        { label: "Dashboard", href: "/" },
        { label: "Berita", href: BASE_PATH },
        { label: "Edit" },
      ]
    : [
        { label: "Dashboard", href: "/" },
        { label: "Berita", href: BASE_PATH },
        { label: "Tambah Baru" },
      ]

  return (
    <div className="w-full px-6 py-6 md:px-8 md:py-8">
      <div className="w-full">
        <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div className="flex flex-col gap-2">
            <BreadcrumbNav items={breadcrumbItems} />
            <h1 className="text-2xl font-bold">{pageTitle}</h1>
            <p className="text-muted-foreground">
              {isEdit
                ? "Perbarui data berita"
                : "Tambah berita baru untuk halaman utama"}
            </p>
          </div>
          <Button variant="ghost" size="sm" className="w-fit cursor-pointer" asChild>
            <Link to={BASE_PATH}>
              <IconArrowLeft className="mr-2 size-4" />
              Kembali
            </Link>
          </Button>
        </div>

        <div className="max-w-3xl">
          <NewsForm
            news={news ?? null}
            onSubmit={handleSubmit}
            isSubmitting={isSubmitting}
          />
        </div>
      </div>
    </div>
  )
}

