/**
 * Notifications list page - shows user's notifications with filters and mark as read.
 */

import { useState, useEffect } from "react"
import { usePageTitle } from "@/hooks/use-page-title"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import {
  getNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  deleteNotification,
} from "@/api/notifications"
import type { Notification } from "@/types/notification"
import { Button } from "@/components/ui/button"
import {
  IconBell,
  IconBellOff,
  IconChevronLeft,
  IconChevronRight,
  IconCircleCheck,
  IconCircleDot,
  IconInfoCircle,
  IconAlertTriangle,
  IconCircleX,
  IconTrash,
} from "@tabler/icons-react"
import { formatDistanceToNow } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import { cn } from "@/lib/utils"
import { toast } from "@/lib/toast"

export function NotificationsPage() {
  usePageTitle("Notifikasi")
  
  const [notifications, setNotifications] = useState<Notification[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [filter, setFilter] = useState<"all" | "unread">("all")
  const [currentPage, setCurrentPage] = useState(1)
  const [totalPages, setTotalPages] = useState(1)
  const pageSize = 20

  const fetchNotifications = async () => {
    setIsLoading(true)
    try {
      const response = await getNotifications({
        page: currentPage,
        page_size: pageSize,
        is_read: filter === "unread" ? false : undefined,
        ordering: "-created_at",
      })
      setNotifications(response.results)
      setTotalPages(Math.ceil(response.count / pageSize))
    } catch (error) {
      console.error("Failed to fetch notifications:", error)
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    fetchNotifications()
  }, [currentPage, filter])

  const handleMarkAsRead = async (id: number) => {
    try {
      await markNotificationRead(id)
      // Update local state
      setNotifications((prev) =>
        prev.map((n) => (n.id === id ? { ...n, is_read: true } : n))
      )
    } catch (error) {
      console.error("Failed to mark as read:", error)
    }
  }

  const handleMarkAllAsRead = async () => {
    try {
      await markAllNotificationsRead()
      // Refresh list
      fetchNotifications()
    } catch (error) {
      console.error("Failed to mark all as read:", error)
    }
  }

  const handleDelete = async (id: number, event: React.MouseEvent) => {
    // Prevent notification click event
    event.stopPropagation()
    
    try {
      await deleteNotification(id)
      // Update local state
      setNotifications((prev) => prev.filter((n) => n.id !== id))
      toast.success("Notifikasi dihapus", "Notifikasi berhasil dihapus")
    } catch (error) {
      console.error("Failed to delete notification:", error)
      toast.error("Gagal menghapus", "Gagal menghapus notifikasi")
    }
  }

  const getNotificationIcon = (type: string) => {
    switch (type) {
      case "SUCCESS":
        return <IconCircleCheck className="size-5 text-green-600" />
      case "WARNING":
        return <IconAlertTriangle className="size-5 text-yellow-600" />
      case "ERROR":
        return <IconCircleX className="size-5 text-red-600" />
      default:
        return <IconInfoCircle className="size-5 text-blue-600" />
    }
  }

  const getTimeAgo = (date: string) => {
    try {
      return formatDistanceToNow(new Date(date), {
        addSuffix: true,
        locale: idLocale,
      })
    } catch {
      return date
    }
  }

  const unreadCount = notifications.filter((n) => !n.is_read).length

  return (
    <div className="flex flex-col gap-4 px-6 py-6 md:px-8 md:py-8">
      <BreadcrumbNav
        items={[
          { label: "Dashboard", href: "/" },
          { label: "Notifikasi" },
        ]}
      />

      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Notifikasi</h1>
          <p className="text-muted-foreground text-sm">
            Kelola notifikasi dan pengumuman Anda
          </p>
        </div>
        {unreadCount > 0 && (
          <Button onClick={handleMarkAllAsRead} variant="outline" size="sm">
            <IconBellOff className="mr-2 size-4" />
            Tandai Semua Dibaca
          </Button>
        )}
      </div>

      {/* Filters */}
      <div className="flex gap-2">
        <Button
          variant={filter === "all" ? "default" : "outline"}
          size="sm"
          onClick={() => {
            setFilter("all")
            setCurrentPage(1)
          }}
        >
          <IconBell className="mr-2 size-4" />
          Semua
        </Button>
        <Button
          variant={filter === "unread" ? "default" : "outline"}
          size="sm"
          onClick={() => {
            setFilter("unread")
            setCurrentPage(1)
          }}
        >
          <IconCircleDot className="mr-2 size-4" />
          Belum Dibaca
          {unreadCount > 0 && (
            <span className="ml-2 rounded-full bg-white/20 px-2 py-0.5 text-xs">
              {unreadCount}
            </span>
          )}
        </Button>
      </div>

      {/* Notifications List */}
      <div className="space-y-2">
        {isLoading ? (
          // Loading skeleton
          Array.from({ length: 5 }).map((_, i) => (
            <div
              key={i}
              className="h-24 animate-pulse rounded-lg border bg-muted/30"
            />
          ))
        ) : notifications.length === 0 ? (
          <div className="flex flex-col items-center justify-center rounded-lg border border-dashed py-16 text-center">
            <IconBellOff className="text-muted-foreground mb-4 size-12" />
            <p className="text-muted-foreground text-sm">
              {filter === "unread"
                ? "Tidak ada notifikasi yang belum dibaca"
                : "Tidak ada notifikasi"}
            </p>
          </div>
        ) : (
          notifications.map((notification) => (
            <div
              key={notification.id}
              className={cn(
                "group flex items-start gap-4 rounded-lg border p-4 transition-colors",
                !notification.is_read && "border-l-4 border-l-primary bg-muted/20"
              )}
            >
              <div
                className="flex min-w-0 flex-1 cursor-pointer items-start gap-4"
                onClick={() => {
                  if (!notification.is_read) {
                    handleMarkAsRead(notification.id)
                  }
                  if (notification.action_url) {
                    window.location.href = notification.action_url
                  }
                }}
              >
                <div className="shrink-0 pt-1">
                  {getNotificationIcon(notification.notification_type)}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-start justify-between gap-2">
                    <h3
                      className={cn(
                        "text-sm",
                        !notification.is_read && "font-semibold"
                      )}
                    >
                      {notification.title}
                    </h3>
                    {!notification.is_read && (
                      <div className="bg-primary h-2 w-2 shrink-0 rounded-full" />
                    )}
                  </div>
                  <p className="text-muted-foreground mt-1 text-sm">
                    {notification.message}
                  </p>
                  <div className="mt-2 flex items-center gap-4">
                    <span className="text-muted-foreground text-xs">
                      {getTimeAgo(notification.created_at)}
                    </span>
                    {notification.action_label && notification.action_url && (
                      <span className="text-primary text-xs font-medium">
                        {notification.action_label} →
                      </span>
                    )}
                  </div>
                </div>
              </div>
              {/* Delete button */}
              <Button
                variant="ghost"
                size="icon"
                className="size-8 shrink-0 opacity-0 transition-opacity group-hover:opacity-100 sm:opacity-100"
                onClick={(e) => handleDelete(notification.id, e)}
                title="Hapus notifikasi"
              >
                <IconTrash className="size-4 text-muted-foreground hover:text-destructive" />
              </Button>
            </div>
          ))
        )}
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
            disabled={currentPage === 1 || isLoading}
          >
            <IconChevronLeft className="size-4" />
          </Button>
          <span className="text-muted-foreground text-sm">
            Halaman {currentPage} dari {totalPages}
          </span>
          <Button
            variant="outline"
            size="sm"
            onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
            disabled={currentPage === totalPages || isLoading}
          >
            <IconChevronRight className="size-4" />
          </Button>
        </div>
      )}
    </div>
  )
}
