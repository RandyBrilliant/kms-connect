import * as React from "react"
import { CalendarIcon } from "lucide-react"
import { format } from "date-fns"

import { Button } from "@/components/ui/button"
import { Calendar } from "@/components/ui/calendar"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { cn } from "@/lib/utils"

export interface DatePickerProps {
  date: Date | null | undefined
  onDateChange: (date: Date | null) => void
  placeholder?: string
  disabled?: boolean
  fromYear?: number
  toYear?: number
}

export function DatePicker({
  date,
  onDateChange,
  placeholder = "Pilih tanggal",
  disabled,
  fromYear = 1950,
  toYear = new Date().getFullYear(),
}: DatePickerProps) {
  const [open, setOpen] = React.useState(false)
  const fromMonth = React.useMemo(() => new Date(fromYear, 0, 1), [fromYear])
  const toMonth = React.useMemo(() => new Date(toYear, 11, 31), [toYear])

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          type="button"
          variant="outline"
          disabled={disabled}
          className={cn(
            "w-full justify-start text-left font-normal cursor-pointer",
            !date && "text-muted-foreground"
          )}
        >
          {date ? format(date, "dd MMM yyyy") : placeholder}
          <CalendarIcon className="ml-auto size-4 opacity-50" />
        </Button>
      </PopoverTrigger>
      <PopoverContent className="p-0" align="start">
        <Calendar
          mode="single"
          selected={date ?? undefined}
          defaultMonth={date ?? undefined}
          captionLayout="dropdown"
          onSelect={(d) => {
            onDateChange(d ?? null)
            if (d) setOpen(false)
          }}
          fromMonth={fromMonth}
          toMonth={toMonth}
        />
      </PopoverContent>
    </Popover>
  )
}

