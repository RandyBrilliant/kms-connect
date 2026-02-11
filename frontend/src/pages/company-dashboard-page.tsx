import { SidebarProvider, SidebarInset } from "@/components/ui/sidebar"
import { AppSidebar } from "@/components/app-sidebar"
import { Separator } from "@/components/ui/separator"
import { SiteHeader } from "@/components/site-header"
import { usePageTitle } from "@/hooks/use-page-title"

export function CompanyDashboardPage({ children }: { children?: React.ReactNode }) {
  usePageTitle("Dashboard Perusahaan")
  return (
    <SidebarProvider>
      <AppSidebar />
      <SidebarInset>
        <SiteHeader />
        <Separator />
        <div className="flex flex-1 flex-col gap-4 p-4">
          {children ?? (
            <div>
              <h1 className="text-2xl font-bold">Dashboard Perusahaan</h1>
              <p className="text-muted-foreground">
                Selamat datang di KMS-Connect Company Dashboard
              </p>
            </div>
          )}
        </div>
      </SidebarInset>
    </SidebarProvider>
  )
}
