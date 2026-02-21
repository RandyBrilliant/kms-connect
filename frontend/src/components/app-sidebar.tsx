import * as React from "react"
import {
  IconBriefcase,
  IconBuilding,
  IconDashboard,
  IconInnerShadowTop,
  IconNews,
  IconShield,
  IconUsers,
  IconUsersGroup,
  IconSend,
  IconChartBar,
} from "@tabler/icons-react"

import { useAuth } from "@/hooks/use-auth"
import { NavMain } from "@/components/nav-main"
import { NavUser } from "@/components/nav-user"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"

function getNavItems(basePath: string, role?: string) {
  const dashboardUrl = basePath || "/"
  
  // Company role: only dashboard, job listings, applicants
  if (role === "COMPANY") {
    return [
      { title: "Dashboard", url: dashboardUrl, icon: IconDashboard },
      { title: "Lowongan Kerja", url: `${basePath}/lowongan-kerja`, icon: IconBriefcase },
      { title: "Pelamar", url: `${basePath}/pelamar`, icon: IconUsers },
    ]
  }
  
  // Staff role: same as admin but with /staff prefix
  if (role === "STAFF") {
    return [
      { title: "Dashboard", url: dashboardUrl, icon: IconDashboard },
      { title: "Pelamar", url: `${basePath}/pelamar`, icon: IconUsers },
      { title: "Perusahaan", url: `${basePath}/perusahaan`, icon: IconBuilding },
      { title: "Staff", url: `${basePath}/staff`, icon: IconUsersGroup },
      { title: "Admin", url: `${basePath}/admin`, icon: IconShield },
      {
        title: "Lowongan Kerja",
        url: `${basePath}/lowongan-kerja`,
        icon: IconBriefcase,
      },
      { title: "Berita", url: `${basePath}/berita`, icon: IconNews },
      { title: "Kirim Broadcast", url: `${basePath}/broadcasts`, icon: IconSend },
      { title: "Laporan", url: `${basePath}/laporan`, icon: IconChartBar },
    ]
  }
  
  // Admin role (default): full access
  return [
    { title: "Dashboard", url: dashboardUrl, icon: IconDashboard },
    { title: "Pelamar", url: `${basePath}/pelamar`, icon: IconUsers },
    { title: "Perusahaan", url: `${basePath}/perusahaan`, icon: IconBuilding },
    { title: "Staff", url: `${basePath}/staff`, icon: IconUsersGroup },
    { title: "Admin", url: `${basePath}/admin`, icon: IconShield },
    {
      title: "Lowongan Kerja",
      url: `${basePath}/lowongan-kerja`,
      icon: IconBriefcase,
    },
    { title: "Berita", url: `${basePath}/berita`, icon: IconNews },
    { title: "Kirim Broadcast", url: `${basePath}/broadcasts`, icon: IconSend },
    { title: "Laporan", url: `${basePath}/laporan`, icon: IconChartBar },
  ]
}

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
  const { user } = useAuth()
  const basePath =
    user?.role === "ADMIN"
      ? ""
      : user?.role === "STAFF"
        ? "/staff"
        : user?.role === "COMPANY"
          ? "/company"
          : ""
  const navItems = getNavItems(basePath, user?.role)
  const displayName =
    (user?.full_name && user.full_name.trim()) ||
    (user?.email ? user.email.split("@")[0] : "") ||
    "User"
  const userForNav = user
    ? {
      name: displayName,
      email: user.email,
      avatar: "",
      role: user.role,
    }
    : { name: "", email: "", avatar: "" }

  return (
    <Sidebar collapsible="offcanvas" {...props}>
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton
              asChild
              className="data-[slot=sidebar-menu-button]:!p-1.5"
            >
              <a href={basePath || "/"}>
                <IconInnerShadowTop className="!size-5" />
                <span className="text-base font-semibold">KMS-Connect</span>
              </a>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>
      <SidebarContent>
        <NavMain items={navItems} showQuickActions={false} />
      </SidebarContent>
      <SidebarFooter>
        <NavUser user={userForNav} />
      </SidebarFooter>
    </Sidebar>
  )
}
