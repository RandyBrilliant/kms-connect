import { SidebarProvider, SidebarInset } from "@/components/ui/sidebar"
import { AppSidebar } from "@/components/app-sidebar"
import { Separator } from "@/components/ui/separator"
import { SiteHeader } from "@/components/site-header"

export function StaffDashboardPage({ children }: { children?: React.ReactNode }) {
  return (
    <SidebarProvider>
      <AppSidebar />
      <SidebarInset>
        <SiteHeader />
        <Separator />
        <div className="flex flex-1 flex-col gap-4 p-4">
          {children ?? (
            <div>
              <h1 className="text-2xl font-bold">Dashboard Staff</h1>
              <p className="text-muted-foreground">
                Selamat datang di KMS-Connect Staff Dashboard
              </p>
            </div>
          )}
        </div>
      </SidebarInset>
    </SidebarProvider>
  )
}
