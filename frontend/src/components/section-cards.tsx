import { IconTrendingDown, IconTrendingUp } from "@tabler/icons-react"

import { Badge } from "@/components/ui/badge"
import {
  Card,
  CardAction,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"

interface SectionCardsProps {
  totalApplicants: number
  totalActiveWorkers: number
  totalInactiveWorkers: number
  growthRate30d: number
}

export function SectionCards({
  totalApplicants,
  totalActiveWorkers,
  totalInactiveWorkers,
  growthRate30d,
}: SectionCardsProps) {
  const growthIsPositive = growthRate30d >= 0
  const growthLabel = `${growthRate30d.toFixed(1)}%`

  return (
    <div className="*:data-[slot=card]:from-primary/5 *:data-[slot=card]:to-card dark:*:data-[slot=card]:bg-card grid grid-cols-1 gap-4 *:data-[slot=card]:bg-gradient-to-t *:data-[slot=card]:shadow-xs @xl/main:grid-cols-2 @5xl/main:grid-cols-4">
      <Card className="@container/card">
        <CardHeader>
          <CardDescription>Total Pelamar</CardDescription>
          <CardTitle className="text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">
            {totalApplicants.toLocaleString("id-ID")}
          </CardTitle>
        </CardHeader>
        <CardFooter className="flex-col items-start gap-1.5 text-sm">
          <div className="line-clamp-1 flex gap-2 font-medium">
            Pelamar terdaftar di sistem
          </div>
          <div className="text-muted-foreground">
            Termasuk semua status verifikasi
          </div>
        </CardFooter>
      </Card>

      <Card className="@container/card">
        <CardHeader>
          <CardDescription>Total Pekerja Aktif</CardDescription>
          <CardTitle className="text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">
            {totalActiveWorkers.toLocaleString("id-ID")}
          </CardTitle>
        </CardHeader>
        <CardFooter className="flex-col items-start gap-1.5 text-sm">
          <div className="line-clamp-1 flex gap-2 font-medium">
            Pelamar dengan status verifikasi diterima
          </div>
          <div className="text-muted-foreground">
            Siap atau sudah ditempatkan
          </div>
        </CardFooter>
      </Card>

      <Card className="@container/card">
        <CardHeader>
          <CardDescription>Total Pekerja Tidak Aktif</CardDescription>
          <CardTitle className="text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">
            {totalInactiveWorkers.toLocaleString("id-ID")}
          </CardTitle>
        </CardHeader>
        <CardFooter className="flex-col items-start gap-1.5 text-sm">
          <div className="line-clamp-1 flex gap-2 font-medium">
            Pelamar yang belum diterima / tidak aktif
          </div>
          <div className="text-muted-foreground">
            Termasuk draf, dikirim, dan ditolak
          </div>
        </CardFooter>
      </Card>

      <Card className="@container/card">
        <CardHeader>
          <CardDescription>Pertumbuhan Pelamar 30 Hari</CardDescription>
          <CardTitle className="text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">
            {growthLabel}
          </CardTitle>
          <CardAction>
            <Badge variant="outline">
              {growthIsPositive ? <IconTrendingUp /> : <IconTrendingDown />}
              {growthLabel}
            </Badge>
          </CardAction>
        </CardHeader>
        <CardFooter className="flex-col items-start gap-1.5 text-sm">
          <div className="line-clamp-1 flex gap-2 font-medium">
            {growthIsPositive ? "Naik" : "Turun"} dibanding 30 hari sebelumnya
          </div>
          <div className="text-muted-foreground">
            Berdasarkan jumlah pelamar baru per periode
          </div>
        </CardFooter>
      </Card>
    </div>
  )
}
