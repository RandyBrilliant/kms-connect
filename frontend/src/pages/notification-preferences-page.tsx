/**
 * Notification Preferences Page
 *
 * Allows users to manage their notification delivery preferences:
 * in-app, email (per category), and push channels.
 *
 * Route: /notifikasi/preferensi  (or integrated inside profile settings)
 */

import { useState, useEffect, useCallback } from "react"
import { usePageTitle } from "@/hooks/use-page-title"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card"
import { Switch } from "@/components/ui/switch"
import { Separator } from "@/components/ui/separator"
import { Skeleton } from "@/components/ui/skeleton"
import { Badge } from "@/components/ui/badge"
import { getNotificationPreferences, updateNotificationPreferences } from "@/api/notifications"
import type { NotificationPreference, NotificationPreferenceUpdate } from "@/types/notification"
import { toast } from "@/lib/toast"
import {
  IconBell,
  IconMail,
  IconDeviceMobile,
  IconInfoCircle,
} from "@tabler/icons-react"

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface PreferenceField {
  key: keyof NotificationPreferenceUpdate
  label: string
  description: string
  isOptIn?: boolean // opt-in fields default to false
}

type ChannelSection = {
  id: "inapp" | "email" | "push"
  icon: React.ReactNode
  title: string
  subtitle: string
  masterKey?: keyof NotificationPreferenceUpdate
  fields: PreferenceField[]
}

// ---------------------------------------------------------------------------
// Section definitions (single source of truth for the UI)
// ---------------------------------------------------------------------------

const SECTIONS: ChannelSection[] = [
  {
    id: "inapp",
    icon: <IconBell size={20} className="text-blue-500" />,
    title: "Notifikasi In-App",
    subtitle: "Notifikasi yang tampil di dalam aplikasi.",
    fields: [
      {
        key: "inapp_enabled",
        label: "Aktifkan notifikasi in-app",
        description: "Tampilkan semua notifikasi di panel notifikasi aplikasi.",
      },
    ],
  },
  {
    id: "email",
    icon: <IconMail size={20} className="text-green-500" />,
    title: "Email",
    subtitle: "Pilih jenis email yang ingin Anda terima.",
    fields: [
      {
        key: "email_account_updates",
        label: "Keamanan & perubahan akun",
        description: "Email saat kata sandi diubah atau ada aktivitas keamanan.",
      },
      {
        key: "email_profile_updates",
        label: "Status verifikasi profil",
        description: "Email saat profil atau dokumen Anda diterima / ditolak.",
      },
      {
        key: "email_application_updates",
        label: "Status lamaran kerja",
        description: "Email saat status lamaran berubah (Interview, Diterima, Ditolak, dll.).",
      },
      {
        key: "email_batch_departure_reminder",
        label: "Pengingat keberangkatan",
        description: "Email pengingat 7 hari dan 1 hari sebelum keberangkatan.",
      },
      {
        key: "email_job_deadline_reminder",
        label: "Pengingat deadline lowongan",
        description: "Email pengingat 3 hari sebelum lowongan yang relevan ditutup.",
      },
      {
        key: "email_job_alerts",
        label: "Lowongan baru",
        description: "Email saat ada lowongan baru dipublikasikan.",
        isOptIn: true,
      },
    ],
  },
  {
    id: "push",
    icon: <IconDeviceMobile size={20} className="text-purple-500" />,
    title: "Push Notification",
    subtitle: "Notifikasi langsung ke perangkat Anda.",
    masterKey: "push_enabled",
    fields: [
      {
        key: "push_enabled",
        label: "Aktifkan push notification",
        description: "Master switch untuk semua push notification.",
      },
      {
        key: "push_application_updates",
        label: "Update status lamaran",
        description: "Push saat status lamaran Anda berubah.",
      },
      {
        key: "push_chat_messages",
        label: "Pesan chat baru",
        description: "Push saat ada pesan baru di dalam chat.",
      },
    ],
  },
]

// ---------------------------------------------------------------------------
// Preference row component
// ---------------------------------------------------------------------------

interface PreferenceRowProps {
  field: PreferenceField
  value: boolean
  disabled?: boolean
  onChange: (key: keyof NotificationPreferenceUpdate, value: boolean) => void
}

function PreferenceRow({ field, value, disabled = false, onChange }: PreferenceRowProps) {
  return (
    <div className="flex items-start justify-between gap-4 py-3">
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium">{field.label}</span>
          {field.isOptIn && (
            <Badge variant="outline" className="text-[10px] px-1.5 py-0">
              opt-in
            </Badge>
          )}
        </div>
        <p className="text-xs text-muted-foreground mt-0.5">{field.description}</p>
      </div>
      <Switch
        checked={value}
        disabled={disabled}
        onCheckedChange={(checked) => onChange(field.key, checked)}
        aria-label={field.label}
      />
    </div>
  )
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

function PreferencesSkeleton() {
  return (
    <div className="space-y-6">
      {[1, 2, 3].map((i) => (
        <Card key={i}>
          <CardHeader>
            <Skeleton className="h-5 w-40" />
            <Skeleton className="h-3 w-64 mt-1" />
          </CardHeader>
          <CardContent className="space-y-4">
            {[1, 2, 3].map((j) => (
              <div key={j} className="flex items-center justify-between">
                <div className="space-y-1">
                  <Skeleton className="h-4 w-48" />
                  <Skeleton className="h-3 w-72" />
                </div>
                <Skeleton className="h-6 w-11 rounded-full" />
              </div>
            ))}
          </CardContent>
        </Card>
      ))}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Main page component
// ---------------------------------------------------------------------------

export function NotificationPreferencesPage() {
  usePageTitle("Preferensi Notifikasi")

  const [prefs, setPrefs] = useState<NotificationPreference | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  // Track in-flight PATCH requests to avoid race conditions
  const [savingKeys, setSavingKeys] = useState<Set<string>>(new Set())

  // Load preferences on mount
  useEffect(() => {
    let cancelled = false
    setIsLoading(true)
    getNotificationPreferences()
      .then((data) => {
        if (!cancelled) setPrefs(data)
      })
      .catch(() => {
        if (!cancelled) toast.error("Gagal memuat preferensi notifikasi.")
      })
      .finally(() => {
        if (!cancelled) setIsLoading(false)
      })
    return () => { cancelled = true }
  }, [])

  /**
   * Optimistically update UI then PATCH a single field to the backend.
   * On failure, rolls back the local state.
   */
  const handleChange = useCallback(
    async (key: keyof NotificationPreferenceUpdate, value: boolean) => {
      if (!prefs) return

      // Optimistic update
      const previous = prefs[key as keyof NotificationPreference]
      setPrefs((prev) => prev ? { ...prev, [key]: value } : prev)

      // Track saving state
      setSavingKeys((prev) => new Set(prev).add(key))

      try {
        const updated = await updateNotificationPreferences({ [key]: value } as NotificationPreferenceUpdate)
        setPrefs(updated)
      } catch {
        // Rollback
        setPrefs((prev) => prev ? { ...prev, [key]: previous } : prev)
        toast.error("Gagal menyimpan preferensi. Silakan coba lagi.")
      } finally {
        setSavingKeys((prev) => {
          const next = new Set(prev)
          next.delete(key)
          return next
        })
      }
    },
    [prefs]
  )

  const breadcrumbs = [
    { label: "Notifikasi", href: "/notifikasi" },
    { label: "Preferensi" },
  ]

  return (
    <div className="space-y-6 pb-12">
      <BreadcrumbNav items={breadcrumbs} />

      <div>
        <h1 className="text-2xl font-bold tracking-tight">Preferensi Notifikasi</h1>
        <p className="text-muted-foreground text-sm mt-1">
          Atur saluran dan kategori notifikasi yang ingin Anda terima.
        </p>
      </div>

      {/* Info banner */}
      <div className="flex items-start gap-3 rounded-lg border border-blue-200 bg-blue-50 p-3 text-sm text-blue-700 dark:border-blue-800 dark:bg-blue-950 dark:text-blue-300">
        <IconInfoCircle size={16} className="mt-0.5 shrink-0" />
        <span>
          Notifikasi penting seperti verifikasi email dan reset kata sandi selalu dikirim
          terlepas dari preferensi Anda.
        </span>
      </div>

      {isLoading ? (
        <PreferencesSkeleton />
      ) : prefs ? (
        <div className="space-y-6">
          {SECTIONS.map((section) => {
            // For push, disable sub-options when master (push_enabled) is off
            const masterDisabled =
              section.id === "push" && !prefs.push_enabled

            return (
              <Card key={section.id}>
                <CardHeader className="pb-2">
                  <div className="flex items-center gap-2">
                    {section.icon}
                    <CardTitle className="text-base">{section.title}</CardTitle>
                  </div>
                  <CardDescription className="text-xs">{section.subtitle}</CardDescription>
                </CardHeader>
                <CardContent>
                  {section.fields.map((field, idx) => {
                    // The master key row is always enabled; sub-rows are disabled when master is off
                    const isMasterRow = field.key === section.masterKey
                    const isDisabled =
                      !isMasterRow && section.id === "push" && masterDisabled
                    const isSaving = savingKeys.has(field.key)

                    return (
                      <div key={field.key}>
                        {idx > 0 && section.id !== "inapp" && (
                          <Separator className="my-0" />
                        )}
                        <PreferenceRow
                          field={field}
                          value={prefs[field.key as keyof NotificationPreference] as boolean}
                          disabled={isDisabled || isSaving}
                          onChange={handleChange}
                        />
                      </div>
                    )
                  })}
                </CardContent>
              </Card>
            )
          })}
        </div>
      ) : (
        <p className="text-muted-foreground text-sm">Tidak dapat memuat preferensi.</p>
      )}
    </div>
  )
}
