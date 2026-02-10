/**
 * Pelamar detail page with tabs: Biodata, Pengalaman Kerja, Dokumen, Metadata.
 */

import { Link, useParams } from "react-router-dom"
import { IconArrowLeft } from "@tabler/icons-react"

import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { ApplicantBiodataTab } from "@/components/applicants/applicant-biodata-tab"
import { ApplicantWorkExperienceTab } from "@/components/applicants/applicant-work-experience-tab"
import { ApplicantDocumentsTab } from "@/components/applicants/applicant-documents-tab"
import { ApplicantMetadataTab } from "@/components/applicants/applicant-metadata-tab"
import {
  useApplicantQuery,
  useUpdateApplicantMutation,
} from "@/hooks/use-applicants-query"
import { toast } from "@/lib/toast"

const BASE_PATH = "/pelamar"

export function AdminPelamarDetailPage() {
  const { id } = useParams<{ id: string }>()
  const applicantId = id ? parseInt(id, 10) : null

  const { data: applicant, isLoading, isError } = useApplicantQuery(
    applicantId,
    !!applicantId
  )
  const updateMutation = useUpdateApplicantMutation(applicantId ?? 0)

  const handleBiodataSubmit = async (
    data: Parameters<typeof updateMutation.mutateAsync>[0]["applicant_profile"]
  ) => {
    await updateMutation.mutateAsync({
      applicant_profile: data,
    })
    toast.success("Biodata diperbarui")
  }

  if (isLoading || !applicantId) {
    return (
      <div className="flex min-h-[200px] items-center justify-center px-6 py-8">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    )
  }

  if (isError || !applicant) {
    return (
      <div className="px-6 py-8">
        <p className="text-destructive">Pelamar tidak ditemukan.</p>
        <Button variant="link" asChild>
          <Link to={BASE_PATH}>Kembali ke daftar</Link>
        </Button>
      </div>
    )
  }

  const profile = applicant.applicant_profile
  const displayName = profile?.full_name || applicant.email

  return (
    <div className="w-full px-6 py-6 md:px-8 md:py-8">
      <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex flex-col gap-2">
          <BreadcrumbNav
            items={[
              { label: "Dashboard", href: "/" },
              { label: "Daftar Pelamar", href: BASE_PATH },
              { label: displayName },
            ]}
          />
          <h1 className="text-2xl font-bold">{displayName}</h1>
          <p className="text-muted-foreground">
            {applicant.email}
            {profile?.nik && ` • NIK: ${profile.nik}`}
          </p>
        </div>
        <Button variant="ghost" size="sm" className="w-fit cursor-pointer" asChild>
          <Link to={BASE_PATH}>
            <IconArrowLeft className="mr-2 size-4" />
            Kembali
          </Link>
        </Button>
      </div>

      <Tabs defaultValue="biodata" className="space-y-6">
        <TabsList className="w-full justify-start overflow-x-auto">
          <TabsTrigger value="biodata" className="cursor-pointer">
            Biodata
          </TabsTrigger>
          <TabsTrigger value="pengalaman" className="cursor-pointer">
            Pengalaman Kerja
          </TabsTrigger>
          <TabsTrigger value="dokumen" className="cursor-pointer">
            Dokumen
          </TabsTrigger>
          <TabsTrigger value="metadata" className="cursor-pointer">
            Metadata
          </TabsTrigger>
        </TabsList>

        <TabsContent value="biodata" className="mt-6">
          <div className="max-w-2xl">
          <ApplicantBiodataTab
            profile={profile}
            onSubmit={handleBiodataSubmit}
            isSubmitting={updateMutation.isPending}
          />
          </div>
        </TabsContent>

        <TabsContent value="pengalaman">
          <ApplicantWorkExperienceTab applicantId={applicant.id} />
        </TabsContent>

        <TabsContent value="dokumen">
          <ApplicantDocumentsTab applicantId={applicant.id} />
        </TabsContent>

        <TabsContent value="metadata">
          <ApplicantMetadataTab applicant={applicant} />
        </TabsContent>
      </Tabs>
    </div>
  )
}
