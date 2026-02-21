/**
 * Admin broadcast form page - create/edit broadcast.
 */

import { useState } from "react"
import { Link, useNavigate, useParams } from "react-router-dom"
import { useForm } from "@tanstack/react-form"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { usePageTitle } from "@/hooks/use-page-title"
import {
  useBroadcastQuery,
  useCreateBroadcastMutation,
  useUpdateBroadcastMutation,
  usePreviewRecipientsMutation,
} from "@/hooks/use-broadcasts-query"
import type {
  NotificationType,
  NotificationPriority,
  RecipientSelectionType,
} from "@/types/notification"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Checkbox } from "@/components/ui/checkbox"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"
import { IconLoader, IconUsers, IconDeviceFloppy, IconArrowLeft } from "@tabler/icons-react"
import { toast } from "@/lib/toast"

const BASE_PATH = "/broadcasts"

export function AdminBroadcastFormPage() {
  const { id } = useParams<{ id: string }>()
  const isEdit = Boolean(id)
  usePageTitle(isEdit ? "Edit Broadcast" : "Buat Broadcast Baru")
  
  const navigate = useNavigate()
  const [recipientCount, setRecipientCount] = useState<number | null>(null)

  // Fetch existing broadcast if editing
  const { data: broadcast, isLoading: isLoadingBroadcast } = useBroadcastQuery(
    id ? Number(id) : null,
    isEdit
  )

  // Mutations
  const createMutation = useCreateBroadcastMutation()
  const updateMutation = useUpdateBroadcastMutation(id ? Number(id) : 0)
  const previewMutation = usePreviewRecipientsMutation()

  const form = useForm({
    defaultValues: {
      title: broadcast?.title ?? "",
      message: broadcast?.message ?? "",
      notification_type: broadcast?.notification_type ?? "INFO",
      priority: broadcast?.priority ?? "NORMAL",
      recipient_config: broadcast?.recipient_config ?? {
        selection_type: "all",
      },
      send_email: broadcast?.send_email ?? false,
      send_in_app: broadcast?.send_in_app ?? true,
      send_push: broadcast?.send_push ?? true,
      scheduled_at: broadcast?.scheduled_at ?? null,
    },
    onSubmit: async ({ value }) => {
      try {
        if (isEdit) {
          await updateMutation.mutateAsync(value)
          toast.success("Broadcast Diperbarui", "Broadcast berhasil diperbarui")
        } else {
          await createMutation.mutateAsync(value)
          toast.success("Broadcast Dibuat", "Broadcast berhasil dibuat")
        }
        navigate(BASE_PATH)
      } catch (error: any) {
        const message = error?.response?.data?.message || "Gagal menyimpan broadcast"
        toast.error("Gagal Menyimpan", message)
      }
    },
  })

  const handlePreviewRecipients = async () => {
    const recipientConfig = form.getFieldValue("recipient_config")
    try {
      const result = await previewMutation.mutateAsync(recipientConfig)
      setRecipientCount(result.recipient_count)
    } catch (error) {
      toast.error("Gagal Preview", "Gagal menghitung jumlah penerima")
    }
  }

  if (isEdit && isLoadingBroadcast) {
    return (
      <div className="flex min-h-50 items-center justify-center px-6 py-8">
        <div className="size-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
      </div>
    )
  }

  const isSubmitting = createMutation.isPending || updateMutation.isPending
  const pageTitle = isEdit ? "Edit Broadcast" : "Buat Broadcast Baru"
  const breadcrumbItems = isEdit
    ? [
        { label: "Dashboard", href: "/" },
        { label: "Broadcasts", href: BASE_PATH },
        { label: "Edit" },
      ]
    : [
        { label: "Dashboard", href: "/" },
        { label: "Broadcasts", href: BASE_PATH },
        { label: "Buat Baru" },
      ]

  return (
    <div className="w-full px-6 py-6 md:px-8 md:py-8">
      <div className="w-full">
        <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div className="flex flex-col gap-2">
            <BreadcrumbNav items={breadcrumbItems} />
            <h1 className="text-2xl font-bold">{pageTitle}</h1>
            <p className="text-muted-foreground">
              {isEdit
                ? "Perbarui broadcast yang telah dibuat"
                : "Kirim notifikasi massal ke pengguna terpilih"}
            </p>
          </div>
          <Button variant="ghost" size="sm" className="w-fit cursor-pointer" asChild>
            <Link to={BASE_PATH}>
              <IconArrowLeft className="mr-2 size-4" />
              Kembali
            </Link>
          </Button>
        </div>

        <div className="max-w-3xl">
          <form
            onSubmit={(e) => {
              e.preventDefault()
              e.stopPropagation()
              form.handleSubmit()
            }}
            className="space-y-6"
          >
        {/* Basic Information */}
        <Card>
          <CardHeader>
            <CardTitle>Informasi Dasar</CardTitle>
            <CardDescription>
              Judul dan pesan notifikasi yang akan dikirim
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <form.Field name="title">
              {(field) => (
                <div className="space-y-2">
                  <Label htmlFor="title">Judul *</Label>
                  <Input
                    id="title"
                    value={field.state.value}
                    onBlur={field.handleBlur}
                    onChange={(e) => field.handleChange(e.target.value)}
                    placeholder="Masukkan judul notifikasi"
                  />
                </div>
              )}
            </form.Field>

            <form.Field name="message">
              {(field) => (
                <div className="space-y-2">
                  <Label htmlFor="message">Pesan *</Label>
                  <Textarea
                    id="message"
                    value={field.state.value}
                    onBlur={field.handleBlur}
                    onChange={(e) => field.handleChange(e.target.value)}
                    placeholder="Masukkan isi pesan notifikasi"
                    rows={4}
                  />
                </div>
              )}
            </form.Field>

            <div className="grid gap-4 sm:grid-cols-2">
              <form.Field name="notification_type">
                {(field) => (
                  <div className="space-y-2">
                    <Label htmlFor="notification_type">Tipe Notifikasi</Label>
                    <Select
                      value={field.state.value}
                      onValueChange={(value: NotificationType) =>
                        field.handleChange(value)
                      }
                    >
                      <SelectTrigger id="notification_type">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="INFO">Info</SelectItem>
                        <SelectItem value="SUCCESS">Success</SelectItem>
                        <SelectItem value="WARNING">Warning</SelectItem>
                        <SelectItem value="ERROR">Error</SelectItem>
                        <SelectItem value="BROADCAST">Broadcast</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                )}
              </form.Field>

              <form.Field name="priority">
                {(field) => (
                  <div className="space-y-2">
                    <Label htmlFor="priority">Prioritas</Label>
                    <Select
                      value={field.state.value}
                      onValueChange={(value: NotificationPriority) =>
                        field.handleChange(value)
                      }
                    >
                      <SelectTrigger id="priority">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="LOW">Low</SelectItem>
                        <SelectItem value="NORMAL">Normal</SelectItem>
                        <SelectItem value="HIGH">High</SelectItem>
                        <SelectItem value="URGENT">Urgent</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                )}
              </form.Field>
            </div>
          </CardContent>
        </Card>

        {/* Recipient Selection */}
        <Card>
          <CardHeader>
            <CardTitle>Penerima</CardTitle>
            <CardDescription>Pilih siapa yang akan menerima broadcast ini</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <form.Field name="recipient_config">
              {(field) => {
                const selectionType = field.state.value?.selection_type || "all"
                return (
                  <>
                    <RadioGroup
                      value={selectionType}
                      onValueChange={(value: RecipientSelectionType) =>
                        field.handleChange({ selection_type: value })
                      }
                    >
                      <div className="flex items-center space-x-2">
                        <RadioGroupItem value="all" id="all" />
                        <Label htmlFor="all">Semua Pengguna</Label>
                      </div>
                      <div className="flex items-center space-x-2">
                        <RadioGroupItem value="roles" id="roles" />
                        <Label htmlFor="roles">Berdasarkan Role</Label>
                      </div>
                    </RadioGroup>

                    {selectionType === "roles" && (
                      <div className="ml-6 space-y-2">
                        <Label>Pilih Role</Label>
                        <div className="space-y-2">
                          {["ADMIN", "STAFF", "COMPANY", "APPLICANT"].map((role) => (
                            <div key={role} className="flex items-center space-x-2">
                              <Checkbox
                                id={`role-${role}`}
                                checked={field.state.value?.roles?.includes(role)}
                                onCheckedChange={(checked) => {
                                  const currentRoles = field.state.value?.roles || []
                                  const newRoles = checked
                                    ? [...currentRoles, role]
                                    : currentRoles.filter((r) => r !== role)
                                  field.handleChange({
                                    ...field.state.value,
                                    selection_type: "roles",
                                    roles: newRoles,
                                  })
                                }}
                              />
                              <Label htmlFor={`role-${role}`}>{role}</Label>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                  </>
                )
              }}
            </form.Field>

            <div className="flex items-center gap-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={handlePreviewRecipients}
                disabled={previewMutation.isPending}
              >
                {previewMutation.isPending ? (
                  <IconLoader className="mr-2 size-4 animate-spin" />
                ) : (
                  <IconUsers className="mr-2 size-4" />
                )}
                Preview Jumlah Penerima
              </Button>
              {recipientCount !== null && (
                <span className="text-muted-foreground text-sm">
                  {recipientCount} pengguna akan menerima broadcast
                </span>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Delivery Options */}
        <Card>
          <CardHeader>
            <CardTitle>Metode Pengiriman</CardTitle>
            <CardDescription>
              Pilih metode pengiriman (minimal 1 harus dipilih)
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <form.Field name="send_in_app">
              {(field) => (
                <div className="flex items-center space-x-2">
                  <Checkbox
                    id="send_in_app"
                    checked={field.state.value}
                    onCheckedChange={(checked) => field.handleChange(Boolean(checked))}
                  />
                  <Label htmlFor="send_in_app">
                    In-App Notification (tampil di aplikasi)
                  </Label>
                </div>
              )}
            </form.Field>

            <form.Field name="send_push">
              {(field) => (
                <div className="flex items-center space-x-2">
                  <Checkbox
                    id="send_push"
                    checked={field.state.value}
                    onCheckedChange={(checked) => field.handleChange(Boolean(checked))}
                  />
                  <Label htmlFor="send_push">
                    Push Notification (web & mobile)
                  </Label>
                </div>
              )}
            </form.Field>

            <form.Field name="send_email">
              {(field) => (
                <div className="flex items-center space-x-2">
                  <Checkbox
                    id="send_email"
                    checked={field.state.value}
                    onCheckedChange={(checked) => field.handleChange(Boolean(checked))}
                  />
                  <Label htmlFor="send_email">Email Notification</Label>
                </div>
              )}
            </form.Field>
          </CardContent>
        </Card>

        {/* Actions */}
        <div className="flex justify-end gap-2">
          <Button
            type="button"
            variant="outline"
            onClick={() => navigate(BASE_PATH)}
            disabled={isSubmitting}
          >
            Batal
          </Button>
          <Button type="submit" disabled={isSubmitting}>
            {isSubmitting ? (
              <IconLoader className="mr-2 size-4 animate-spin" />
            ) : (
              <IconDeviceFloppy className="mr-2 size-4" />
            )}
            {isEdit ? "Simpan Perubahan" : "Buat Broadcast"}
          </Button>
        </div>
      </form>
        </div>
      </div>
    </div>
  )
}
