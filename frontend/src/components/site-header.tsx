import { useEffect, useState, useMemo } from "react"
import { useNavigate, useLocation } from "react-router-dom"
import {
  IconBell,
  IconLoader,
  IconCheck,
  IconAlertCircle,
  IconInfoCircle,
  IconChevronRight,
} from "@tabler/icons-react"

import { useAuth } from "@/hooks/use-auth"
import {
  getUnreadNotificationCount,
  getNotifications,
  markNotificationRead,
} from "@/api/notifications"
import type { Notification } from "@/types/notification"

import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Separator } from "@/components/ui/separator"
import { SidebarTrigger } from "@/components/ui/sidebar"
import { cn } from "@/lib/utils"

/**
 * Route-to-title mapping configuration
 * Maps route patterns to page titles
 */
const PAGE_TITLES: Record<string, string> = {
  // Dashboard
  "/": "Dashboard",
  
  // Admin routes
  "/admin": "Daftar Admin",
  "/admin/new": "Tambah Admin",
  "/pelamar": "Daftar Pelamar",
  "/pelamar/new": "Tambah Pelamar",
  "/staff": "Daftar Staff",
  "/staff/new": "Tambah Staff",
  "/company": "Daftar Perusahaan",
  "/company/new": "Tambah Perusahaan",
  
  // Content Management
  "/berita": "Kelola Berita",
  "/berita/new": "Tambah Berita",
  "/lowongan": "Kelola Lowongan",
  "/lowongan/new": "Tambah Lowongan",
  "/broadcasts": "Kelola Broadcast",
  "/broadcasts/new": "Buat Broadcast",
  
  // Reports
  "/laporan": "Laporan",
  
  // Notifications
  "/notifikasi": "Notifikasi",
  "/staff/notifikasi": "Notifikasi",
  "/company/notifikasi": "Notifikasi",
  
  // Profile & Settings
  "/profile": "Profil Saya",
  "/settings": "Pengaturan",
  
  // Company routes
  "/company/lowongan": "Lowongan Saya",
  "/company/pelamar": "Daftar Pelamar",
  
  // Staff routes
  "/staff/pelamar": "Daftar Pelamar",
  "/staff/rujukan": "Rujukan Saya",
}

/**
 * Get page title from current pathname
 * Handles exact matches, dynamic routes, and fallbacks
 */
function getPageTitle(pathname: string): string {
  // Exact match
  if (PAGE_TITLES[pathname]) {
    return PAGE_TITLES[pathname]
  }
  
  // Handle edit routes (e.g., /admin/123/edit -> "Edit Admin")
  if (pathname.includes("/edit")) {
    if (pathname.startsWith("/admin/") && !pathname.includes("pelamar")) return "Edit Admin"
    if (pathname.startsWith("/pelamar/")) return "Edit Pelamar"
    if (pathname.startsWith("/staff/")) return "Edit Staff"
    if (pathname.startsWith("/company/") && pathname.split("/").length === 3) return "Edit Perusahaan"
    if (pathname.startsWith("/berita/")) return "Edit Berita"
    if (pathname.startsWith("/lowongan/")) return "Edit Lowongan"
    if (pathname.startsWith("/broadcasts/")) return "Edit Broadcast"
  }
  
  // Handle detail/view routes (e.g., /pelamar/123 -> "Detail Pelamar")
  const detailMatch = pathname.match(/^\/(\w+)\/\d+$/)
  if (detailMatch) {
    const [, route] = detailMatch
    switch (route) {
      case "admin": return "Detail Admin"
      case "pelamar": return "Detail Pelamar"
      case "staff": return "Detail Staff"
      case "company": return "Detail Perusahaan"
      case "berita": return "Detail Berita"
      case "lowongan": return "Detail Lowongan"
      case "broadcasts": return "Detail Broadcast"
    }
  }
  
  // Handle nested routes - take the last meaningful segment
  const segments = pathname.split("/").filter(Boolean)
  if (segments.length > 0) {
    const lastSegment = segments[segments.length - 1]
    
    // Skip numeric IDs or common actions
    if (!lastSegment.match(/^\d+$/) && !["edit", "new"].includes(lastSegment)) {
      // Capitalize and convert kebab-case to Title Case
      return lastSegment
        .split("-")
        .map(word => word.charAt(0).toUpperCase() + word.slice(1))
        .join(" ")
    }
  }
  
  // Fallback to parent route title
  if (segments.length > 1) {
    const parentPath = "/" + segments.slice(0, -1).join("/")
    if (PAGE_TITLES[parentPath]) {
      return PAGE_TITLES[parentPath]
    }
  }
  
  // Ultimate fallback
  return "Dashboard"
}

/**
 * Helper: Get icon component based on notification type
 */
function getNotificationIcon(type: string) {
  switch (type) {
    case "SUCCESS":
      return IconCheck
    case "WARNING":
      return IconAlertCircle
    case "ERROR":
      return IconAlertCircle
    case "INFO":
    case "BROADCAST":
    default:
      return IconInfoCircle
  }
}

/**
 * Helper: Format notification timestamp to relative time
 */
function formatRelativeTime(dateString: string): string {
  const date = new Date(dateString)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffMins = Math.floor(diffMs / 60000)
  const diffHours = Math.floor(diffMins / 60)
  const diffDays = Math.floor(diffHours / 24)

  if (diffMins < 1) return "Baru saja"
  if (diffMins < 60) return `${diffMins} menit yang lalu`
  if (diffHours < 24) return `${diffHours} jam yang lalu`
  if (diffDays < 7) return `${diffDays} hari yang lalu`

  return date.toLocaleDateString("id-ID", {
    day: "numeric",
    month: "short",
    year: date.getFullYear() !== now.getFullYear() ? "numeric" : undefined,
  })
}

export function SiteHeader() {
  const navigate = useNavigate()
  const location = useLocation()
  const { user } = useAuth()
  const [unreadCount, setUnreadCount] = useState(0)
  const [notifications, setNotifications] = useState<Notification[]>([])
  const [isLoadingNotifications, setIsLoadingNotifications] = useState(false)
  
  // Memoize page title to avoid unnecessary recalculations
  const pageTitle = useMemo(() => getPageTitle(location.pathname), [location.pathname])

  // Get notification path based on user role
  const getNotificationPath = () => {
    switch (user?.role) {
      case "STAFF":
        return "/staff/notifikasi"
      case "COMPANY":
        return "/company/notifikasi"
      default:
        return "/notifikasi"
    }
  }

  // Fetch recent notifications (limit 5 for dropdown)
  const fetchNotifications = async () => {
    setIsLoadingNotifications(true)
    try {
      const response = await getNotifications({
        page: 1,
        page_size: 5,
        ordering: "-created_at",
      })
      setNotifications(response.results)
    } catch (error) {
      console.error("Failed to fetch notifications:", error)
    } finally {
      setIsLoadingNotifications(false)
    }
  }

  // Fetch unread count
  const fetchUnreadCount = async () => {
    try {
      const { count } = await getUnreadNotificationCount()
      setUnreadCount(count)
    } catch (error) {
      console.error("Failed to fetch unread count:", error)
    }
  }

  // Handle notification click - mark as read and navigate if has action
  const handleNotificationClick = async (notification: Notification) => {
    try {
      if (!notification.is_read) {
        await markNotificationRead(notification.id)
        await fetchUnreadCount()
        await fetchNotifications()
      }

      // Navigate to action URL if provided
      if (notification.action_url) {
        navigate(notification.action_url)
      }
    } catch (error) {
      console.error("Failed to mark notification as read:", error)
    }
  }

  // Fetch data on mount and set up polling
  useEffect(() => {
    fetchUnreadCount()

    // Poll for updates every 30 seconds
    const interval = setInterval(fetchUnreadCount, 30000)

    // Listen for new notification events from Firebase
    const handleNewNotification = () => {
      fetchUnreadCount()
      fetchNotifications()
    }
    window.addEventListener("newNotification", handleNewNotification)

    return () => {
      clearInterval(interval)
      window.removeEventListener("newNotification", handleNewNotification)
    }
  }, [])

  // Fetch notifications when dropdown opens
  const handleDropdownOpenChange = (open: boolean) => {
    if (open && notifications.length === 0) {
      fetchNotifications()
    }
  }

  return (
    <header className="flex h-(--header-height) shrink-0 items-center gap-2 border-b transition-[width,height] ease-linear group-has-data-[collapsible=icon]/sidebar-wrapper:h-(--header-height)">
      <div className="flex w-full items-center gap-1 px-6 py-4 lg:gap-2 lg:px-8">
        <SidebarTrigger className="-ml-1" />
        <Separator
          orientation="vertical"
          className="mx-2 data-[orientation=vertical]:h-4"
        />
        <h1 className="text-base font-medium">{pageTitle}</h1>
        <div className="ml-auto flex items-center gap-2">
          <DropdownMenu onOpenChange={handleDropdownOpenChange}>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" className="relative">
                <IconBell className="size-5" />
                {unreadCount > 0 && (
                  <span className="bg-primary absolute -right-0.5 -top-0.5 flex size-4 items-center justify-center rounded-full text-[10px] font-medium text-primary-foreground">
                    {unreadCount > 99 ? "99+" : unreadCount}
                  </span>
                )}
                <span className="sr-only">Notifikasi</span>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-80">
              <DropdownMenuLabel className="flex items-center justify-between">
                <span>Notifikasi</span>
                {unreadCount > 0 && (
                  <span className="text-muted-foreground text-xs font-normal">
                    {unreadCount} belum dibaca
                  </span>
                )}
              </DropdownMenuLabel>
              <DropdownMenuSeparator />

              {/* Notifications List */}
              <div className="max-h-96 overflow-y-auto">
                {isLoadingNotifications ? (
                  <div className="flex items-center justify-center py-8">
                    <IconLoader className="size-5 animate-spin text-muted-foreground" />
                  </div>
                ) : notifications.length === 0 ? (
                  <div className="flex flex-col items-center justify-center py-8 text-center">
                    <IconBell className="text-muted-foreground mb-2 size-8" />
                    <p className="text-muted-foreground text-sm">
                      Tidak ada notifikasi
                    </p>
                  </div>
                ) : (
                  notifications.map((notification) => {
                    const NotifIcon = getNotificationIcon(
                      notification.notification_type
                    )
                    return (
                      <DropdownMenuItem
                        key={notification.id}
                        className={cn(
                          "flex cursor-pointer flex-col items-start gap-1 px-3 py-3",
                          !notification.is_read &&
                            "bg-blue-50/50 dark:bg-blue-950/20"
                        )}
                        onClick={() => handleNotificationClick(notification)}
                      >
                        <div className="flex w-full items-start gap-2">
                          <NotifIcon
                            className={cn(
                              "mt-0.5 size-4 shrink-0",
                              notification.notification_type === "SUCCESS" &&
                                "text-green-600",
                              notification.notification_type === "WARNING" &&
                                "text-yellow-600",
                              notification.notification_type === "ERROR" &&
                                "text-red-600",
                              notification.notification_type === "INFO" &&
                                "text-blue-600",
                              notification.notification_type === "BROADCAST" &&
                                "text-purple-600"
                            )}
                          />
                          <div className="flex-1 space-y-1">
                            <p
                              className={cn(
                                "text-sm leading-tight",
                                !notification.is_read && "font-semibold"
                              )}
                            >
                              {notification.title}
                            </p>
                            <p className="text-muted-foreground line-clamp-2 text-xs">
                              {notification.message}
                            </p>
                            <p className="text-muted-foreground text-xs">
                              {formatRelativeTime(notification.created_at)}
                            </p>
                          </div>
                          {!notification.is_read && (
                            <span className="mt-1 size-2 shrink-0 rounded-full bg-blue-600" />
                          )}
                        </div>
                      </DropdownMenuItem>
                    )
                  })
                )}
              </div>

              {/* Show More Button */}
              {notifications.length > 0 && (
                <>
                  <DropdownMenuSeparator />
                  <div className="p-2">
                    <Button
                      variant="ghost"
                      size="sm"
                      className="w-full justify-between"
                      onClick={() => navigate(getNotificationPath())}
                    >
                      <span>Lihat semua notifikasi</span>
                      <IconChevronRight className="size-4" />
                    </Button>
                  </div>
                </>
              )}
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>
    </header>
  )
}
