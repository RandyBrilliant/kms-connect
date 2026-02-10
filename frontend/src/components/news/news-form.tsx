/**
 * Shared news form for create and edit.
 * Fields: title, slug, summary, content, status, is_pinned, published_at (read-only).
 */

import { useState } from "react"
import { useForm } from "@tanstack/react-form"
import { format } from "date-fns"
import { id } from "date-fns/locale"

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Switch } from "@/components/ui/switch"
import type { NewsItem, NewsStatus } from "@/types/news"

interface NewsFormProps {
  news?: NewsItem | null
  onSubmit: (values: {
    title: string
    slug: string
    summary: string
    content: string
    status: NewsStatus
    is_pinned: boolean
  }, heroImage?: File | null) => Promise<void>
  isSubmitting?: boolean
}

type NewsFormValues = {
  title: string
  slug: string
  summary: string
  content: string
  status: NewsStatus
  is_pinned: boolean
}

function formatDateTime(value: string | null) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy HH:mm", { locale: id })
}

function slugify(value: string): string {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/g, "")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
}

export function NewsForm({
  news,
  onSubmit,
  isSubmitting = false,
}: NewsFormProps) {
  const isEdit = !!news
  const [errors, setErrors] = useState<Partial<Record<keyof NewsFormValues, string>>>({})
  const [heroImageFile, setHeroImageFile] = useState<File | null>(null)

  const form = useForm({
    defaultValues: {
      title: news?.title ?? "",
      slug: news?.slug ?? "",
      summary: news?.summary ?? "",
      content: news?.content ?? "",
      status: news?.status ?? "DRAFT",
      is_pinned: news?.is_pinned ?? false,
    },
    onSubmit: async ({ value }) => {
      setErrors({})

      const newErrors: Partial<Record<keyof NewsFormValues, string>> = {}
      if (!value.title.trim()) newErrors.title = "Judul wajib diisi"
      if (!value.slug.trim()) newErrors.slug = "Slug wajib diisi"
      if (!value.content.trim()) newErrors.content = "Konten wajib diisi"

      if (Object.keys(newErrors).length > 0) {
        setErrors(newErrors)
        return
      }

      await onSubmit(
        {
          title: value.title.trim(),
          slug: value.slug.trim(),
          summary: value.summary.trim(),
          content: value.content,
          status: value.status,
          is_pinned: value.is_pinned,
        },
        heroImageFile ?? undefined,
      )
    },
  })

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault()
        e.stopPropagation()
        void form.handleSubmit()
      }}
      className="flex flex-col gap-6"
    >
      <Card>
        <CardHeader>
          <CardTitle>Informasi Berita</CardTitle>
          <CardDescription>
            {isEdit
              ? "Perbarui judul, konten, dan status berita."
              : "Masukkan informasi untuk berita baru. Field dengan * wajib diisi."}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FieldGroup>
            <form.Field name="title">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    Judul <span className="text-destructive">*</span>
                  </FieldLabel>
                  <Input
                    id={field.name}
                    type="text"
                    placeholder="Contoh: Pengumuman Program Penempatan Baru"
                    value={field.state.value}
                    onChange={(e) => {
                      const nextTitle = e.target.value
                      field.handleChange(nextTitle)
                      // Auto-fill slug only when user hasn't manually edited slug
                      const currentSlug = form.state.values.slug
                      if (!currentSlug || currentSlug === slugify(field.state.value)) {
                        form.setFieldValue("slug", slugify(nextTitle))
                      }
                    }}
                    onBlur={field.handleBlur}
                  />
                  <FieldError
                    errors={[
                      ...(field.state.meta.errors as unknown[]).map((err) => {
                        const e = err as { message?: string } | string
                        if (typeof e === "string") return { message: e }
                        return { message: e?.message ?? String(e) }
                      }),
                      ...(errors.title ? [{ message: errors.title! }] : []),
                    ]}
                  />
                </Field>
              )}
            </form.Field>

            <form.Field name="slug">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    Slug <span className="text-destructive">*</span>
                  </FieldLabel>
                  <Input
                    id={field.name}
                    type="text"
                    placeholder="contoh: pengumuman-program-baru"
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                    onBlur={field.handleBlur}
                  />
                  <FieldError
                    errors={[
                      ...(field.state.meta.errors as unknown[]).map((err) => {
                        const e = err as { message?: string } | string
                        if (typeof e === "string") return { message: e }
                        return { message: e?.message ?? String(e) }
                      }),
                      ...(errors.slug ? [{ message: errors.slug! }] : []),
                    ]}
                  />
                </Field>
              )}
            </form.Field>

            <form.Field name="summary">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Ringkasan</FieldLabel>
                  <Textarea
                    id={field.name}
                    placeholder="Ringkasan singkat yang akan ditampilkan di daftar berita."
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                    onBlur={field.handleBlur}
                    rows={3}
                  />
                  <FieldError
                    errors={(field.state.meta.errors as unknown[]).map((err) => {
                      const e = err as { message?: string } | string
                      if (typeof e === "string") return { message: e }
                      return { message: e?.message ?? String(e) }
                    })}
                  />
                </Field>
              )}
            </form.Field>

            <form.Field name="content">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>
                    Konten <span className="text-destructive">*</span>
                  </FieldLabel>
                  <Textarea
                    id={field.name}
                    placeholder="Isi lengkap berita. Dapat berupa teks panjang atau konten yang sudah diformat."
                    value={field.state.value}
                    onChange={(e) => field.handleChange(e.target.value)}
                    onBlur={field.handleBlur}
                    rows={10}
                  />
                  <FieldError
                    errors={[
                      ...(field.state.meta.errors as unknown[]).map((err) => {
                        const e = err as { message?: string } | string
                        if (typeof e === "string") return { message: e }
                        return { message: e?.message ?? String(e) }
                      }),
                      ...(errors.content ? [{ message: errors.content! }] : []),
                    ]}
                  />
                </Field>
              )}
            </form.Field>

            {/* Hero image upload */}
            <Field>
              <FieldLabel htmlFor="hero_image">Gambar Utama (Banner)</FieldLabel>
              <Input
                id="hero_image"
                type="file"
                accept="image/*"
                onChange={(e) => {
                  const file = e.target.files?.[0] ?? null
                  setHeroImageFile(file)
                }}
              />
              <p className="text-muted-foreground mt-1 text-xs">
                Opsional. Gambar ini akan digunakan sebagai banner/hero untuk berita.
              </p>
              {news?.hero_image && !heroImageFile && (
                <p className="text-muted-foreground mt-1 text-xs">
                  Gambar saat ini sudah tersimpan. Pilih file baru untuk mengganti.
                </p>
              )}
            </Field>
          </FieldGroup>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Pengaturan Publikasi</CardTitle>
          <CardDescription>
            Atur status publikasi dan apakah berita disematkan di bagian atas daftar.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <FieldGroup>
            <form.Field name="status">
              {(field) => (
                <Field>
                  <FieldLabel htmlFor={field.name}>Status</FieldLabel>
                  <Select
                    value={field.state.value}
                    onValueChange={(v) => field.handleChange(v as NewsStatus)}
                  >
                    <SelectTrigger id={field.name} className="w-[200px] cursor-pointer">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="DRAFT">Draf</SelectItem>
                      <SelectItem value="PUBLISHED">Dipublikasikan</SelectItem>
                      <SelectItem value="ARCHIVED">Diarsipkan</SelectItem>
                    </SelectContent>
                  </Select>
                  <FieldError
                    errors={(field.state.meta.errors as unknown[]).map((err) => {
                      const e = err as { message?: string } | string
                      if (typeof e === "string") return { message: e }
                      return { message: e?.message ?? String(e) }
                    })}
                  />
                </Field>
              )}
            </form.Field>

            <form.Field name="is_pinned">
              {(field) => (
                <Field>
                  <div className="flex items-center justify-between gap-4">
                    <FieldLabel htmlFor={field.name}>Sematkan di atas</FieldLabel>
                    <Switch
                      id={field.name}
                      checked={field.state.value}
                      onCheckedChange={(v) => field.handleChange(v)}
                    />
                  </div>
                  <p className="text-muted-foreground mt-1 text-xs">
                    Jika aktif, berita akan muncul di bagian atas daftar.
                  </p>
                </Field>
              )}
            </form.Field>

            {news && (
              <div className="grid gap-2 text-sm text-muted-foreground">
                <div className="flex justify-between">
                  <span>Dibuat oleh</span>
                  <span className="font-medium">
                    {news.created_by_name || "-"}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span>Dibuat pada</span>
                  <span className="font-medium">
                    {formatDateTime(news.created_at)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span>Diperbarui pada</span>
                  <span className="font-medium">
                    {formatDateTime(news.updated_at)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span>Dipublikasikan pada</span>
                  <span className="font-medium">
                    {formatDateTime(news.published_at)}
                  </span>
                </div>
              </div>
            )}
          </FieldGroup>
        </CardContent>
      </Card>

      <div className="flex gap-2">
        <Button type="submit" disabled={isSubmitting} className="cursor-pointer">
          {isSubmitting
            ? "Menyimpan..."
            : isEdit
              ? "Simpan Perubahan"
              : "Tambah Berita"}
        </Button>
      </div>
    </form>
  )
}

