import { IconBell } from "@tabler/icons-react"

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

const NOTIFICATIONS = [
  {
    id: 1,
    title: "Lowongan baru ditambahkan",
    time: "5 menit yang lalu",
  },
  {
    id: 2,
    title: "3 pelamar baru mendaftar",
    time: "1 jam yang lalu",
  },
]

export function SiteHeader() {

  return (
    <header className="flex h-(--header-height) shrink-0 items-center gap-2 border-b transition-[width,height] ease-linear group-has-data-[collapsible=icon]/sidebar-wrapper:h-(--header-height)">
      <div className="flex w-full items-center gap-1 px-6 py-4 lg:gap-2 lg:px-8">
        <SidebarTrigger className="-ml-1" />
        <Separator
          orientation="vertical"
          className="mx-2 data-[orientation=vertical]:h-4"
        />
        <h1 className="text-base font-medium">Documents</h1>
        <div className="ml-auto flex items-center gap-2">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" className="relative">
                <IconBell className="size-5" />
                {NOTIFICATIONS.length > 0 && (
                  <span className="bg-primary absolute -right-0.5 -top-0.5 flex size-4 items-center justify-center rounded-full text-[10px] font-medium text-primary-foreground">
                    {NOTIFICATIONS.length}
                  </span>
                )}
                <span className="sr-only">Notifikasi</span>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-80">
              <DropdownMenuLabel>Notifikasi</DropdownMenuLabel>
              <DropdownMenuSeparator />
              {NOTIFICATIONS.length === 0 ? (
                <p className="text-muted-foreground px-2 py-6 text-center text-sm">
                  Tidak ada notifikasi
                </p>
              ) : (
                <div className="max-h-64 overflow-y-auto">
                  {NOTIFICATIONS.map((n) => (
                    <DropdownMenuItem
                      key={n.id}
                      onSelect={(e) => e.preventDefault()}
                      className="flex cursor-default flex-col items-start gap-0.5 py-3"
                    >
                      <span className="text-sm">{n.title}</span>
                      <span className="text-muted-foreground text-xs">
                        {n.time}
                      </span>
                    </DropdownMenuItem>
                  ))}
                </div>
              )}
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>
    </header>
  )
}
