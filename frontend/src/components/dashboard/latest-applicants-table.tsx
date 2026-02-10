import { Link } from "react-router-dom"
import { IconPencil } from "@tabler/icons-react"
import { format } from "date-fns"
import { id } from "date-fns/locale"

import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import type { LatestApplicantRow } from "@/types/dashboard"

interface LatestApplicantsTableProps {
  data: LatestApplicantRow[]
  isLoading?: boolean
}

function formatDate(value: string) {
  return format(new Date(value), "dd MMM yyyy HH:mm", { locale: id })
}

function statusBadge(status: string) {
  switch (status) {
    case "ACCEPTED":
      return <Badge variant="default">Diterima</Badge>
    case "REJECTED":
      return <Badge variant="destructive">Ditolak</Badge>
    case "SUBMITTED":
      return <Badge variant="outline">Dikirim</Badge>
    case "DRAFT":
    default:
      return (
        <Badge variant="outline" className="text-muted-foreground">
          Draf
        </Badge>
      )
  }
}

export function LatestApplicantsTable({
  data,
  isLoading = false,
}: LatestApplicantsTableProps) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between gap-2">
        <div className="space-y-1">
          <CardTitle>Pelamar Terbaru</CardTitle>
          <CardDescription>
            10 pelamar terbaru berdasarkan tanggal pendaftaran.
          </CardDescription>
        </div>
        <Button asChild variant="outline" size="sm" className="cursor-pointer">
          <Link to="/pelamar">
            Lihat semua
          </Link>
        </Button>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <div className="flex items-center justify-center py-8">
            <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          </div>
        ) : data.length === 0 ? (
          <p className="text-muted-foreground py-4 text-center text-sm">
            Belum ada pelamar.
          </p>
        ) : (
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Nama</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Terdaftar Pada</TableHead>
                  <TableHead className="w-[80px] text-right">Aksi</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.map((item) => (
                  <TableRow key={item.id}>
                    <TableCell>{item.full_name}</TableCell>
                    <TableCell>{item.email}</TableCell>
                    <TableCell>{statusBadge(item.verification_status)}</TableCell>
                    <TableCell>{formatDate(item.created_at)}</TableCell>
                    <TableCell className="text-right">
                      <Button
                        asChild
                        variant="ghost"
                        size="icon"
                        className="size-8 cursor-pointer"
                        title="Edit pelamar"
                      >
                        <Link to={`/pelamar/${item.id}`}>
                          <IconPencil className="size-4" />
                          <span className="sr-only">Edit</span>
                        </Link>
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

