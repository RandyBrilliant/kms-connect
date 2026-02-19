/**
 * Staff form page - shared for create and edit.
 * /staff/new (create) and /staff/:id/edit (edit)
 */

import { Link, useNavigate, useParams } from "react-router-dom"
import { IconArrowLeft, IconMail, IconKey, IconPhone, IconUser, IconCopy, IconBrandGoogle } from "@tabler/icons-react"

import { StaffForm } from "@/components/staffs/staff-form"
import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import {
    useStaffQuery,
    useCreateStaffMutation,
    useUpdateStaffMutation,
    useDeactivateStaffMutation,
    useActivateStaffMutation,
    useSendVerificationEmailMutation,
    useSendPasswordResetMutation,
} from "@/hooks/use-staffs-query"
import { toast } from "@/lib/toast"
import type { StaffUser } from "@/types/staff"
import { usePageTitle } from "@/hooks/use-page-title"

const BASE_PATH = "/staff"

function formatDate(value: string | null) {
    if (!value) return "-"
    return new Date(value).toLocaleString("id-ID", {
        dateStyle: "medium",
        timeStyle: "short",
    })
}

function StaffEditSidebar({ staff }: { staff: StaffUser }) {
    const deactivateMutation = useDeactivateStaffMutation()
    const activateMutation = useActivateStaffMutation()
    const sendVerificationMutation = useSendVerificationEmailMutation()
    const sendPasswordResetMutation = useSendPasswordResetMutation()

    const handleToggleActive = async () => {
        try {
            if (staff.is_active) {
                await deactivateMutation.mutateAsync(staff.id)
                toast.success("Staff dinonaktifkan", "Akun tidak dapat login")
            } else {
                await activateMutation.mutateAsync(staff.id)
                toast.success("Staff diaktifkan", "Akun dapat login kembali")
            }
        } catch (err: unknown) {
            const res = err as { response?: { data?: { detail?: string } } }
            toast.error("Gagal", res?.response?.data?.detail ?? "Coba lagi nanti")
        }
    }

    const handleSendVerification = async () => {
        try {
            await sendVerificationMutation.mutateAsync(staff.id)
            toast.success("Email terkirim", "Email verifikasi telah dikirim ke " + staff.email)
        } catch (err: unknown) {
            const res = err as { response?: { data?: { detail?: string } } }
            toast.error("Gagal mengirim", res?.response?.data?.detail ?? "Coba lagi nanti")
        }
    }

    const handleSendPasswordReset = async () => {
        try {
            await sendPasswordResetMutation.mutateAsync(staff.id)
            toast.success("Email terkirim", "Email reset password telah dikirim ke " + staff.email)
        } catch (err: unknown) {
            const res = err as { response?: { data?: { detail?: string } } }
            toast.error("Gagal mengirim", res?.response?.data?.detail ?? "Coba lagi nanti")
        }
    }

    const handleCopyReferralCode = async () => {
        if (staff.referral_code) {
            try {
                await navigator.clipboard.writeText(staff.referral_code)
                toast.success("Disalin", "Kode rujukan telah disalin ke clipboard")
            } catch (err) {
                toast.error("Gagal", "Tidak dapat menyalin kode rujukan")
            }
        }
    }

    return (
        <div className="flex flex-col gap-6">
            {/* Staff Profile Info */}
            <Card>
                <CardHeader>
                    <CardTitle>Informasi Staff</CardTitle>
                    <CardDescription>Data lengkap staff</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                    <div className="flex items-center gap-4">
                        <Avatar className="h-20 w-20">
                            <AvatarImage
                                src={staff.staff_profile.photo || undefined}
                                alt={staff.staff_profile.full_name}
                            />
                            <AvatarFallback className="text-lg">
                                {staff.staff_profile.full_name
                                    .split(" ")
                                    .map((n) => n[0])
                                    .join("")
                                    .toUpperCase()
                                    .slice(0, 2)}
                            </AvatarFallback>
                        </Avatar>
                        <div className="flex-1">
                            <h3 className="font-semibold text-lg">{staff.staff_profile.full_name}</h3>
                            <p className="text-sm text-muted-foreground">{staff.email}</p>
                            <div className="flex gap-2 mt-2">
                                <Badge variant={staff.is_active ? "default" : "secondary"}>
                                    {staff.is_active ? "Aktif" : "Nonaktif"}
                                </Badge>
                                <Badge variant={staff.email_verified ? "default" : "outline"}>
                                    {staff.email_verified ? "Email Terverifikasi" : "Email Belum Terverifikasi"}
                                </Badge>
                            </div>
                        </div>
                    </div>
                    <dl className="space-y-3 text-sm border-t pt-4">
                        {staff.staff_profile.contact_phone && (
                            <div className="flex items-center gap-2">
                                <IconPhone className="size-4 text-muted-foreground" />
                                <div className="flex-1">
                                    <dt className="text-muted-foreground">Telepon</dt>
                                    <dd className="font-medium">{staff.staff_profile.contact_phone}</dd>
                                </div>
                            </div>
                        )}
                        <div className="flex items-center gap-2">
                            <IconUser className="size-4 text-muted-foreground" />
                            <div className="flex-1">
                                <dt className="text-muted-foreground">Role</dt>
                                <dd className="font-medium">{staff.role}</dd>
                            </div>
                        </div>
                        {staff.referral_code && (
                            <div className="flex items-center gap-2">
                                <IconCopy className="size-4 text-muted-foreground" />
                                <div className="flex-1">
                                    <dt className="text-muted-foreground">Kode Rujukan</dt>
                                    <dd className="flex items-center gap-2">
                                        <span className="font-medium font-mono">{staff.referral_code}</span>
                                        <Button
                                            type="button"
                                            variant="ghost"
                                            size="sm"
                                            className="h-6 w-6 p-0 cursor-pointer"
                                            onClick={handleCopyReferralCode}
                                            title="Salin kode rujukan"
                                        >
                                            <IconCopy className="size-3" />
                                        </Button>
                                    </dd>
                                </div>
                            </div>
                        )}
                        {staff.google_id && (
                            <div className="flex items-center gap-2">
                                <IconBrandGoogle className="size-4 text-muted-foreground" />
                                <div className="flex-1">
                                    <dt className="text-muted-foreground">Login via Google</dt>
                                    <dd className="font-medium text-xs text-muted-foreground">Terhubung dengan Google</dd>
                                </div>
                            </div>
                        )}
                    </dl>
                </CardContent>
            </Card>

            {/* Status: Aktif / Nonaktif */}
            <Card>
                <CardHeader>
                    <CardTitle>Status Akun</CardTitle>
                    <CardDescription>
                        {staff.is_active
                            ? "Akun aktif dan dapat login"
                            : "Akun nonaktif dan tidak dapat login"}
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    <Button
                        type="button"
                        variant={staff.is_active ? "destructive" : "default"}
                        className={
                            staff.is_active
                                ? "cursor-pointer"
                                : "cursor-pointer border-green-600 bg-green-600 hover:bg-green-700 hover:text-white"
                        }
                        onClick={handleToggleActive}
                        disabled={
                            deactivateMutation.isPending || activateMutation.isPending
                        }
                    >
                        {staff.is_active ? "Nonaktifkan" : "Aktifkan"}
                    </Button>
                </CardContent>
            </Card>

            {/* Send email verification */}
            <Card>
                <CardHeader>
                    <CardTitle>Email Verifikasi</CardTitle>
                    <CardDescription>
                        Kirim email verifikasi ke {staff.email}. Hanya untuk akun yang belum terverifikasi.
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        className="cursor-pointer"
                        onClick={handleSendVerification}
                        disabled={
                            staff.email_verified || sendVerificationMutation.isPending
                        }
                    >
                        <IconMail className="mr-2 size-4" />
                        Kirim Email Verifikasi
                    </Button>
                </CardContent>
            </Card>

            {/* Send password reset */}
            <Card>
                <CardHeader>
                    <CardTitle>Reset Password</CardTitle>
                    <CardDescription>
                        Kirim email reset password ke {staff.email}. Pengguna akan menerima tautan untuk mengganti password.
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        className="cursor-pointer"
                        onClick={handleSendPasswordReset}
                        disabled={sendPasswordResetMutation.isPending}
                    >
                        <IconKey className="mr-2 size-4" />
                        Kirim Email Reset Password
                    </Button>
                </CardContent>
            </Card>

            {/* Metadata */}
            <Card>
                <CardHeader>
                    <CardTitle>Metadata</CardTitle>
                    <CardDescription>Informasi sistem terkait staff ini</CardDescription>
                </CardHeader>
                <CardContent>
                    <dl className="space-y-4 text-sm">
                        <div>
                            <dt className="text-muted-foreground">ID</dt>
                            <dd className="font-medium">{staff.id}</dd>
                        </div>
                        <div>
                            <dt className="text-muted-foreground">Email</dt>
                            <dd className="font-medium">{staff.email}</dd>
                        </div>
                        <div>
                            <dt className="text-muted-foreground">Tanggal Bergabung</dt>
                            <dd className="font-medium">{formatDate(staff.date_joined)}</dd>
                        </div>
                        <div>
                            <dt className="text-muted-foreground">Login Terakhir</dt>
                            <dd className="font-medium">{formatDate(staff.last_login)}</dd>
                        </div>
                        <div>
                            <dt className="text-muted-foreground">Email Diverifikasi pada</dt>
                            <dd className="font-medium">{formatDate(staff.email_verified_at)}</dd>
                        </div>
                        <div>
                            <dt className="text-muted-foreground">Profil Dibuat pada</dt>
                            <dd className="font-medium">{formatDate(staff.staff_profile.created_at)}</dd>
                        </div>
                        <div>
                            <dt className="text-muted-foreground">Profil Diperbarui pada</dt>
                            <dd className="font-medium">{formatDate(staff.staff_profile.updated_at)}</dd>
                        </div>
                        <div>
                            <dt className="text-muted-foreground">Akun Diperbarui pada</dt>
                            <dd className="font-medium">{formatDate(staff.updated_at)}</dd>
                        </div>
                        {staff.google_id && (
                            <div>
                                <dt className="text-muted-foreground">Google ID</dt>
                                <dd className="font-medium text-xs break-all">{staff.google_id}</dd>
                            </div>
                        )}
                    </dl>
                </CardContent>
            </Card>
        </div>
    )
}

export function StaffStaffFormPage() {
    const navigate = useNavigate()
    const { id } = useParams<{ id: string }>()
    const isEdit = id !== "new" && id != null
    const staffId = isEdit ? parseInt(id, 10) : null

    usePageTitle(isEdit ? "Edit Staff" : "Tambah Staff")

    const { data: staff, isLoading: loadingStaff } = useStaffQuery(
        staffId ?? null,
        isEdit
    )
    const createMutation = useCreateStaffMutation()
    const updateMutation = useUpdateStaffMutation(staffId ?? 0)

    const handleSubmit = async (values: {
        email: string
        full_name?: string
        contact_phone?: string
        password?: string
        is_active?: boolean
        email_verified?: boolean
    }) => {
        try {
            if (isEdit && staffId) {
                await updateMutation.mutateAsync({
                    email: values.email,
                    staff_profile: {
                        full_name: values.full_name,
                        contact_phone: values.contact_phone || undefined,
                    },
                })
                toast.success("Staff diperbarui", "Perubahan berhasil disimpan")
                navigate(BASE_PATH)
            } else {
                await createMutation.mutateAsync({
                    email: values.email,
                    password: values.password!,
                    staff_profile: {
                        full_name: values.full_name!,
                        contact_phone: values.contact_phone || undefined,
                    },
                    is_active: true,
                    email_verified: false,
                })
                toast.success("Staff ditambahkan", "Staff baru berhasil dibuat")
                navigate(BASE_PATH)
            }
        } catch (err: unknown) {
            const res = err as {
                response?: { data?: { errors?: Record<string, string[] | Record<string, string[]>>; detail?: string } }
            }
            const errors = res?.response?.data?.errors
            const detail = res?.response?.data?.detail
            
            // Handle nested errors (e.g., staff_profile.full_name)
            let errorMessages: string[] = []
            if (errors) {
                for (const [, value] of Object.entries(errors)) {
                    if (Array.isArray(value)) {
                        errorMessages.push(...value)
                    } else if (typeof value === "object") {
                        // Nested errors like { staff_profile: { full_name: [...] } }
                        for (const [, nestedValue] of Object.entries(value)) {
                            if (Array.isArray(nestedValue)) {
                                errorMessages.push(...nestedValue)
                            }
                        }
                    }
                }
            }
            
            if (errorMessages.length > 0) {
                toast.error("Validasi gagal", errorMessages.join(". "))
            } else {
                toast.error("Gagal menyimpan", detail ?? "Coba lagi nanti")
            }
            throw err
        }
    }

    if (isEdit && loadingStaff) {
        return (
            <div className="flex min-h-[200px] items-center justify-center px-6 py-8">
                <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
        )
    }

    if (isEdit && !staff && !loadingStaff) {
        return (
            <div className="px-6 py-8">
                <p className="text-destructive">Staff tidak ditemukan.</p>
                <Button variant="link" asChild>
                    <Link to={BASE_PATH}>Kembali ke daftar</Link>
                </Button>
            </div>
        )
    }

    const isSubmitting =
        createMutation.isPending || updateMutation.isPending
    const pageTitle = isEdit ? "Edit Staff" : "Tambah Staff"
    const breadcrumbItems = isEdit
        ? [
            { label: "Dashboard", href: "/" },
            { label: "Daftar Staff", href: BASE_PATH },
            { label: "Edit" },
        ]
        : [
            { label: "Dashboard", href: "/" },
            { label: "Daftar Staff", href: BASE_PATH },
            { label: "Tambah Baru" },
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
                                ? "Perbarui data staff"
                                : "Tambah pengguna baru dengan peran Staff"}
                        </p>
                    </div>
                    <Button variant="ghost" size="sm" className="w-fit cursor-pointer" asChild>
                        <Link to={BASE_PATH}>
                            <IconArrowLeft className="mr-2 size-4" />
                            Kembali
                        </Link>
                    </Button>
                </div>

                <div
                    className={
                        isEdit
                            ? "grid gap-8 lg:grid-cols-[1fr_400px] xl:grid-cols-[1fr_420px]"
                            : "max-w-2xl"
                    }
                >
                    <div className="min-w-0">
                        <StaffForm
                            staff={staff ?? null}
                            onSubmit={handleSubmit}
                            isSubmitting={isSubmitting}
                        />
                    </div>
                    {isEdit && staff && (
                        <div className="flex flex-col gap-6 lg:min-w-0">
                            <StaffEditSidebar staff={staff} />
                        </div>
                    )}
                </div>
            </div>
        </div>
    )
}
