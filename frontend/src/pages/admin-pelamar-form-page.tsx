/**
 * Pelamar create form page.
 */

import { Link, useNavigate } from "react-router-dom"
import { IconArrowLeft } from "@tabler/icons-react"

import { ApplicantForm } from "@/components/applicants/applicant-form"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Button } from "@/components/ui/button"
import { useCreateApplicantMutation } from "@/hooks/use-applicants-query"
import { toast } from "@/lib/toast"

const BASE_PATH = "/pelamar"

export function AdminPelamarFormPage() {
  const navigate = useNavigate()
  const createMutation = useCreateApplicantMutation()

  const handleSubmit = async (values: {
    email: string
    password: string
    applicant_profile: {
      full_name: string
      nik: string
      birth_place?: string
      birth_date?: string | null
      address?: string
      contact_phone?: string
      gender?: string
    }
  }) => {
    try {
      const created = await createMutation.mutateAsync(values)
      toast.success("Pelamar ditambahkan", "Data pelamar berhasil dibuat")
      navigate(`${BASE_PATH}/${created.id}`)
    } catch (err: unknown) {
      const res = err as {
        response?: { data?: { errors?: Record<string, string[]>; detail?: string } }
      }
      const errors = res?.response?.data?.errors
      const detail = res?.response?.data?.detail
      if (errors) {
        const msgs = Object.entries(errors)
          .flatMap(([k, v]) => (Array.isArray(v) ? v : [v]).map((m) => `${k}: ${m}`))
        toast.error("Validasi gagal", msgs.join(". "))
      } else {
        toast.error("Gagal menyimpan", detail ?? "Coba lagi nanti")
      }
      throw err
    }
  }

  return (
    <div className="w-full px-6 py-6 md:px-8 md:py-8">
      <div className="w-full">
        <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div className="flex flex-col gap-2">
            <BreadcrumbNav
              items={[
                { label: "Dashboard", href: "/" },
                { label: "Daftar Pelamar", href: BASE_PATH },
                { label: "Tambah Baru" },
              ]}
            />
            <h1 className="text-2xl font-bold">Tambah Pelamar</h1>
            <p className="text-muted-foreground">
              Buat akun pelamar baru beserta biodata dasar
            </p>
          </div>
          <Button variant="ghost" size="sm" className="w-fit cursor-pointer" asChild>
            <Link to={BASE_PATH}>
              <IconArrowLeft className="mr-2 size-4" />
              Kembali
            </Link>
          </Button>
        </div>

        <div className="max-w-2xl">
          <ApplicantForm
          onSubmit={handleSubmit}
          isSubmitting={createMutation.isPending}
        />
        </div>
      </div>
    </div>
  )
}
