/**
 * Admin: Permintaan Penghapusan Akun
 * List, approve, reject deletion requests submitted by applicants.
 */

import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { IconCheck, IconX, IconSearch, IconTrash } from "@tabler/icons-react"

import { BreadcrumbNav } from "@/components/breadcrumb-nav"
import { usePageTitle } from "@/hooks/use-page-title"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog"
import { Textarea } from "@/components/ui/textarea"
import { Label } from "@/components/ui/label"
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from "@/components/ui/select"
import { toast } from "@/lib/toast"
import { joinAdminPath, useAdminDashboard } from "@/contexts/admin-dashboard-context"
import {
    getDeletionRequests,
    approveDeletionRequest,
    rejectDeletionRequest,
} from "@/api/account-deletion"
import type { AccountDeletionRequest, DeletionRequestStatus } from "@/types/account-deletion"

const STATUS_LABELS: Record<DeletionRequestStatus, string> = {
    PENDING: "Menunggu",
    APPROVED: "Disetujui",
    REJECTED: "Ditolak",
    CANCELLED: "Dibatalkan",
}

const STATUS_VARIANTS: Record<
    DeletionRequestStatus,
    "default" | "secondary" | "destructive" | "outline"
> = {
    PENDING: "default",
    APPROVED: "destructive",
    REJECTED: "secondary",
    CANCELLED: "outline",
}

export function AdminDeletionRequestsPage() {
    usePageTitle("Permintaan Penghapusan Akun")
    const { basePath } = useAdminDashboard()

    const queryClient = useQueryClient()
    const [statusFilter, setStatusFilter] = useState<DeletionRequestStatus | "ALL">("ALL")
    const [search, setSearch] = useState("")
    const [selectedRequest, setSelectedRequest] = useState<AccountDeletionRequest | null>(null)
    const [action, setAction] = useState<"approve" | "reject" | null>(null)
    const [adminNotes, setAdminNotes] = useState("")

    const { data: requests = [], isLoading } = useQuery({
        queryKey: ["deletion-requests", statusFilter, search],
        queryFn: () =>
            getDeletionRequests({
                status: statusFilter === "ALL" ? undefined : statusFilter,
                search: search || undefined,
            }),
    })

    const approveMutation = useMutation({
        mutationFn: (id: number) => approveDeletionRequest(id, { admin_notes: adminNotes }),
        onSuccess: () => {
            toast.success(
                "Permintaan disetujui",
                "Akun telah dihapus dan email konfirmasi dikirim ke alamat pengguna (jika email aktif).",
            )
            queryClient.invalidateQueries({ queryKey: ["deletion-requests"] })
            closeDialog()
        },
    })

    const rejectMutation = useMutation({
        mutationFn: (id: number) => rejectDeletionRequest(id, { admin_notes: adminNotes }),
        onSuccess: () => {
            toast.success(
                "Permintaan ditolak",
                "Pengguna akan menerima email dan notifikasi di aplikasi.",
            )
            queryClient.invalidateQueries({ queryKey: ["deletion-requests"] })
            closeDialog()
        },
    })

    function openDialog(req: AccountDeletionRequest, act: "approve" | "reject") {
        setSelectedRequest(req)
        setAction(act)
        setAdminNotes("")
    }

    function closeDialog() {
        setSelectedRequest(null)
        setAction(null)
        setAdminNotes("")
    }

    function handleConfirm() {
        if (!selectedRequest) return
        if (action === "approve") approveMutation.mutate(selectedRequest.id)
        else if (action === "reject") rejectMutation.mutate(selectedRequest.id)
    }

    const isPending = approveMutation.isPending || rejectMutation.isPending

    return (
        <div className="flex flex-col gap-6 px-4 py-4 sm:px-6 sm:py-6 md:px-8 md:py-8">
            <div>
                <BreadcrumbNav
                    items={[
                        { label: "Dashboard", href: basePath || "/" },
                        { label: "Permintaan Hapus Akun", href: joinAdminPath(basePath, "/hapus-akun") },
                    ]}
                />
                <h1 className="mt-2 text-xl font-bold sm:text-2xl">Permintaan Penghapusan Akun</h1>
                <p className="text-muted-foreground text-sm sm:text-base">
                    Tinjau dan proses permintaan penghapusan akun dari pengguna.
                </p>
            </div>

            {/* Filters */}
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
                <div className="relative flex-1 max-w-sm">
                    <IconSearch className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-muted-foreground" />
                    <Input
                        placeholder="Cari email atau nama..."
                        className="pl-9"
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                    />
                </div>
                <Select
                    value={statusFilter}
                    onValueChange={(v) => setStatusFilter(v as DeletionRequestStatus | "ALL")}
                >
                    <SelectTrigger className="w-44">
                        <SelectValue placeholder="Semua status" />
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="ALL">Semua status</SelectItem>
                        <SelectItem value="PENDING">Menunggu</SelectItem>
                        <SelectItem value="APPROVED">Disetujui</SelectItem>
                        <SelectItem value="REJECTED">Ditolak</SelectItem>
                        <SelectItem value="CANCELLED">Dibatalkan</SelectItem>
                    </SelectContent>
                </Select>
            </div>

            {/* Table */}
            <div className="rounded-lg border bg-card overflow-x-auto">
                {isLoading ? (
                    <div className="p-8 text-center text-muted-foreground text-sm">
                        Memuat data...
                    </div>
                ) : requests.length === 0 ? (
                    <div className="p-8 text-center text-muted-foreground text-sm flex flex-col items-center gap-2">
                        <IconTrash className="size-8 opacity-30" />
                        <span>Tidak ada permintaan penghapusan akun.</span>
                    </div>
                ) : (
                    <table className="w-full text-sm">
                        <thead>
                            <tr className="border-b bg-muted/40">
                                <th className="px-4 py-3 text-left font-medium text-muted-foreground">Pengguna</th>
                                <th className="px-4 py-3 text-left font-medium text-muted-foreground">Peran</th>
                                <th className="px-4 py-3 text-left font-medium text-muted-foreground">Alasan</th>
                                <th className="px-4 py-3 text-left font-medium text-muted-foreground">Status</th>
                                <th className="px-4 py-3 text-left font-medium text-muted-foreground">Tanggal</th>
                                <th className="px-4 py-3 text-left font-medium text-muted-foreground">Catatan Admin</th>
                                <th className="px-4 py-3" />
                            </tr>
                        </thead>
                        <tbody>
                            {requests.map((req) => (
                                <tr key={req.id} className="border-b last:border-0 hover:bg-muted/20">
                                    <td className="px-4 py-3">
                                        <div className="font-medium">{req.user_full_name || "—"}</div>
                                        <div className="text-muted-foreground text-xs">{req.user_email}</div>
                                    </td>
                                    <td className="px-4 py-3 text-muted-foreground capitalize">
                                        {req.user_role.toLowerCase()}
                                    </td>
                                    <td className="px-4 py-3 max-w-50">
                                        <span className="text-muted-foreground line-clamp-2">
                                            {req.reason || <em className="text-xs">Tidak ada alasan</em>}
                                        </span>
                                    </td>
                                    <td className="px-4 py-3">
                                        <Badge variant={STATUS_VARIANTS[req.status]}>
                                            {STATUS_LABELS[req.status]}
                                        </Badge>
                                    </td>
                                    <td className="px-4 py-3 text-muted-foreground whitespace-nowrap">
                                        {new Date(req.requested_at).toLocaleDateString("id-ID", {
                                            day: "2-digit",
                                            month: "short",
                                            year: "numeric",
                                        })}
                                    </td>
                                    <td className="px-4 py-3 max-w-40">
                                        <span className="text-muted-foreground text-xs line-clamp-2">
                                            {req.admin_notes || "—"}
                                        </span>
                                    </td>
                                    <td className="px-4 py-3">
                                        {req.status === "PENDING" && (
                                            <div className="flex gap-2">
                                                <Button
                                                    size="sm"
                                                    variant="destructive"
                                                    className="gap-1"
                                                    onClick={() => openDialog(req, "approve")}
                                                >
                                                    <IconCheck className="size-3.5" />
                                                    Setujui
                                                </Button>
                                                <Button
                                                    size="sm"
                                                    variant="outline"
                                                    className="gap-1"
                                                    onClick={() => openDialog(req, "reject")}
                                                >
                                                    <IconX className="size-3.5" />
                                                    Tolak
                                                </Button>
                                            </div>
                                        )}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
            </div>

            {/* Confirm Dialog */}
            <Dialog open={!!selectedRequest} onOpenChange={(open) => !open && closeDialog()}>
                <DialogContent>
                    <DialogHeader>
                        <DialogTitle>
                            {action === "approve"
                                ? "Setujui Penghapusan Akun"
                                : "Tolak Permintaan Penghapusan"}
                        </DialogTitle>
                        <DialogDescription>
                            {action === "approve" ? (
                                <>
                                    Akun <strong>{selectedRequest?.user_email}</strong> akan{" "}
                                    <strong>dihapus secara permanen</strong>. Email pemberitahuan dikirim ke
                                    pengguna sebelum penghapusan. Tindakan ini tidak dapat dibatalkan.
                                </>
                            ) : (
                                <>
                                    Permintaan penghapusan akun dari{" "}
                                    <strong>{selectedRequest?.user_email}</strong> akan ditolak. Akun
                                    tetap aktif.
                                </>
                            )}
                        </DialogDescription>
                    </DialogHeader>

                    <div className="space-y-2">
                        <Label htmlFor="admin-notes">
                            Catatan Admin{action === "reject" && " (opsional)"}
                        </Label>
                        <Textarea
                            id="admin-notes"
                            placeholder={
                                action === "approve"
                                    ? "Catatan internal (opsional)..."
                                    : "Alasan penolakan (opsional)..."
                            }
                            value={adminNotes}
                            onChange={(e) => setAdminNotes(e.target.value)}
                            rows={3}
                        />
                    </div>

                    <DialogFooter>
                        <Button variant="outline" onClick={closeDialog} disabled={isPending}>
                            Batal
                        </Button>
                        <Button
                            variant={action === "approve" ? "destructive" : "default"}
                            onClick={handleConfirm}
                            disabled={isPending}
                        >
                            {isPending
                                ? "Memproses..."
                                : action === "approve"
                                    ? "Ya, Setujui & Hapus Akun"
                                    : "Tolak Permintaan"}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </div>
    )
}
