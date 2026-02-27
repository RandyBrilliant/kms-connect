/**
 * Admin — Application detail page with tabs: Info, Riwayat Status, Chat.
 * Opens with `?tab=chat` to jump directly to the chat panel.
 */

import { useParams, useSearchParams, Link } from "react-router-dom"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import { IconArrowLeft, IconClipboardList } from "@tabler/icons-react"

import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { ApplicationStatusBadge } from "@/components/applications/application-status-badge"
import { StatusHistoryTimeline } from "@/components/applications/status-history-timeline"
import { TransitionApplicationDialog } from "@/components/applications/transition-application-dialog"
import { ChatPanel } from "@/components/chat/chat-panel"
import { useApplicationQuery } from "@/hooks/use-applications-query"
import { useChatThreadsQuery } from "@/hooks/use-chat-query"
import { useAuth } from "@/hooks/use-auth"

const BASE_PATH = "/admin/lamaran"

function DetailRow({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-0.5 py-2 border-b last:border-b-0">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="text-sm font-medium">{value ?? "-"}</dd>
    </div>
  )
}

function formatDate(value: string | null | undefined) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy", { locale: idLocale })
}

export function AdminApplicationDetailPage() {
  const { id } = useParams<{ id: string }>()
  const appId = Number(id)
  const [searchParams, setSearchParams] = useSearchParams()
  const activeTab = searchParams.get("tab") ?? "info"

  const { data: application, isLoading, isError } = useApplicationQuery(appId)
  const { data: threadsPage } = useChatThreadsQuery(
    { application: appId, page_size: 1 },
  )

  const { user } = useAuth()
  const currentUserId = user?.id ?? 0

  const threadId = threadsPage?.results?.[0]?.id ?? null

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-24">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    )
  }

  if (isError || !application) {
    return (
      <div className="p-6">
        <p className="text-destructive">Data lamaran tidak ditemukan.</p>
        <Button asChild variant="outline" className="mt-4 cursor-pointer">
          <Link to={BASE_PATH}>
            <IconArrowLeft className="mr-2 size-4" />
            Kembali
          </Link>
        </Button>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-6 p-6">
      <BreadcrumbNav
        items={[
          { label: "Lamaran", href: BASE_PATH },
          { label: application.applicant_name },
        ]}
      />

      {/* Header */}
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div className="flex items-center gap-3">
          <Button asChild variant="ghost" size="icon" className="cursor-pointer">
            <Link to={BASE_PATH}>
              <IconArrowLeft className="size-5" />
              <span className="sr-only">Kembali</span>
            </Link>
          </Button>
          <div>
            <div className="flex items-center gap-2">
              <IconClipboardList className="size-5 text-muted-foreground" />
              <h1 className="text-2xl font-bold">{application.applicant_name}</h1>
            </div>
            <p className="text-muted-foreground text-sm">
              {application.job_title}
              {application.company_name ? ` — ${application.company_name}` : ""}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <ApplicationStatusBadge status={application.status} />
          <TransitionApplicationDialog
            application={application}
            onSuccess={() => window.location.reload()}
          />
        </div>
      </div>

      <Tabs
        value={activeTab}
        onValueChange={(val) => setSearchParams({ tab: val })}
      >
        <TabsList>
          <TabsTrigger value="info">Info</TabsTrigger>
          <TabsTrigger value="history">Riwayat Status</TabsTrigger>
          <TabsTrigger value="chat">
            Chat
          </TabsTrigger>
        </TabsList>

        {/* Tab: Info */}
        <TabsContent value="info">
          <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
            {/* Applicant info */}
            <Card>
              <CardHeader>
                <CardTitle className="text-base">Data Pelamar</CardTitle>
                <CardDescription>Informasi identitas pelamar</CardDescription>
              </CardHeader>
              <CardContent>
                <dl>
                  <DetailRow label="Nama" value={application.applicant_name} />
                  <DetailRow label="Email" value={application.applicant_email} />
                  <DetailRow label="ID Pelamar" value={application.applicant} />
                </dl>
              </CardContent>
            </Card>

            {/* Application meta */}
            <Card>
              <CardHeader>
                <CardTitle className="text-base">Detail Lamaran</CardTitle>
                <CardDescription>Informasi lamaran dan status</CardDescription>
              </CardHeader>
              <CardContent>
                <dl>
                  <DetailRow label="Lowongan" value={application.job_title} />
                  <DetailRow label="Perusahaan" value={application.company_name} />
                  <DetailRow
                    label="Sumber"
                    value={
                      application.source === "ADMIN_ASSIGN"
                        ? "Ditugaskan Admin"
                        : "Mandiri"
                    }
                  />
                  <DetailRow label="Tanggal Lamar" value={formatDate(application.applied_at)} />
                  <DetailRow label="Tanggal Review" value={formatDate(application.reviewed_at)} />
                  <DetailRow
                    label="Tanggal Selesai Kerja"
                    value={formatDate(application.placement_end_date)}
                  />
                  <DetailRow
                    label="Dapat Melamar Kembali"
                    value={formatDate(application.cooldown_eligible_date)}
                  />
                  {application.assigned_by_name && (
                    <DetailRow
                      label="Ditugaskan oleh"
                      value={application.assigned_by_name}
                    />
                  )}
                  {application.notes && (
                    <DetailRow label="Catatan" value={application.notes} />
                  )}
                </dl>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Tab: History */}
        <TabsContent value="history">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Riwayat Perubahan Status</CardTitle>
              <CardDescription>
                Audit trail seluruh perubahan status lamaran ini.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <StatusHistoryTimeline history={application.status_history ?? []} />
            </CardContent>
          </Card>
        </TabsContent>

        {/* Tab: Chat */}
        <TabsContent value="chat">
          {!threadId ? (
            <Card>
              <CardContent className="py-8 text-center">
                <p className="text-muted-foreground text-sm">
                  Thread percakapan belum tersedia untuk lamaran ini.
                </p>
              </CardContent>
            </Card>
          ) : (
            <div className="h-[600px]">
              <ChatPanel
                threadId={threadId}
                currentUserId={currentUserId}
                canManage
              />
            </div>
          )}
        </TabsContent>
      </Tabs>
    </div>
  )
}
