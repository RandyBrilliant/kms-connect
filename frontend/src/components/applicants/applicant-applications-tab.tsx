/**
 * Lamaran tab on pelamar detail: quick-assign to batch + list of applications.
 */

import { Link } from "react-router-dom"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import {
  IconClipboardList,
  IconExternalLink,
  IconMessage,
  IconUsersGroup,
} from "@tabler/icons-react"

import { ApplicationStatusBadge } from "@/components/applications/application-status-badge"
import { ApplicantLamaranQuickAssign } from "@/components/applicants/applicant-lamaran-quick-assign"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { joinAdminPath } from "@/contexts/admin-dashboard-context"
import { useApplicationsQuery } from "@/hooks/use-applications-query"

export interface ApplicantApplicationsTabProps {
  profileId?: number
  lamaranBase: string
  basePath: string
}

export function ApplicantApplicationsTab({
  profileId,
  lamaranBase,
  basePath,
}: ApplicantApplicationsTabProps) {
  const { data, isLoading } = useApplicationsQuery(
    profileId ? { applicant: profileId, page_size: 50 } : {},
    !!profileId
  )

  if (!profileId) {
    return (
      <Card>
        <CardContent className="py-8 text-center text-sm text-muted-foreground">
          Profil pelamar belum tersedia.
        </CardContent>
      </Card>
    )
  }

  const applications = data?.results ?? []

  return (
    <div className="flex flex-col gap-6">
      <ApplicantLamaranQuickAssign
        applicantProfileId={profileId}
        applications={applications}
        basePath={basePath}
        disabled={isLoading}
      />

      <div className="flex flex-col gap-2">
        <h3 className="text-sm font-semibold">Daftar lamaran</h3>
        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <div className="h-7 w-7 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          </div>
        ) : applications.length === 0 ? (
          <Card>
            <CardContent className="py-8 text-center">
              <IconClipboardList className="mx-auto mb-3 size-8 text-muted-foreground/50" />
              <p className="text-sm text-muted-foreground">
                Pelamar belum memiliki lamaran. Gunakan formulir di atas untuk menambahkan ke
                batch.
              </p>
            </CardContent>
          </Card>
        ) : (
          <div className="flex flex-col gap-3">
            {applications.map((app) => (
              <Card key={app.id}>
                <CardContent className="flex flex-col gap-3 py-4 sm:flex-row sm:items-center sm:justify-between">
                  <div className="flex flex-col gap-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-medium text-sm">{app.job_title}</span>
                      {app.company_name && (
                        <span className="text-muted-foreground text-xs">— {app.company_name}</span>
                      )}
                    </div>
                    <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                      <IconUsersGroup className="size-3.5 shrink-0 opacity-80" />
                      {app.batch != null && app.batch_name ? (
                        <Link
                          to={joinAdminPath(basePath, `/batch/${app.batch}`)}
                          className="text-primary hover:underline"
                        >
                          {app.batch_name}
                        </Link>
                      ) : (
                        <span>Tanpa batch</span>
                      )}
                    </div>
                    <div className="flex items-center gap-2 flex-wrap">
                      <ApplicationStatusBadge status={app.status} />
                      <Badge variant="outline" className="text-xs">
                        {app.assigned_by != null ? "Ditugaskan Admin" : "Mandiri"}
                      </Badge>
                      <span className="text-xs text-muted-foreground">
                        {app.applied_at
                          ? format(new Date(app.applied_at), "dd MMM yyyy", { locale: idLocale })
                          : ""}
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center gap-2 shrink-0">
                    <Button
                      asChild
                      variant="outline"
                      size="sm"
                      className="cursor-pointer"
                    >
                      <Link to={`${lamaranBase}/${app.id}?tab=chat`}>
                        <IconMessage className="mr-2 size-4" />
                        Chat
                      </Link>
                    </Button>
                    <Button
                      asChild
                      variant="ghost"
                      size="sm"
                      className="cursor-pointer"
                    >
                      <Link to={`${lamaranBase}/${app.id}`}>
                        <IconExternalLink className="mr-2 size-4" />
                        Detail
                      </Link>
                    </Button>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
