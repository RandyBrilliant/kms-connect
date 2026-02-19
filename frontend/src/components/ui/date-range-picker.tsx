"use client"

import * as React from "react"
import { CalendarIcon, X } from "lucide-react"
import { format } from "date-fns"
import { id } from "date-fns/locale"
import { type DateRange } from "react-day-picker"

import { Button } from "@/components/ui/button"
import { Calendar } from "@/components/ui/calendar"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { cn } from "@/lib/utils"

export interface DateRangePickerProps {
  dateRange: DateRange | undefined
  onDateRangeChange: (range: DateRange | undefined) => void
  placeholder?: string
  disabled?: boolean
  fromYear?: number
  toYear?: number
  numberOfMonths?: number
}

export function DateRangePicker({
  dateRange,
  onDateRangeChange,
  placeholder = "Pilih rentang tanggal",
  disabled,
  fromYear = 2020,
  toYear = new Date().getFullYear(),
  numberOfMonths = 2,
}: DateRangePickerProps) {
  const [open, setOpen] = React.useState(false)
  const fromMonth = React.useMemo(() => new Date(fromYear, 0, 1), [fromYear])
  const toMonth = React.useMemo(() => new Date(toYear, 11, 31), [toYear])

  const handleClear = (e: React.MouseEvent) => {
    e.stopPropagation()
    e.preventDefault()
    onDateRangeChange(undefined)
    setOpen(false)
  }

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          type="button"
          variant="outline"
          disabled={disabled}
          className={cn(
            "w-full justify-start text-left font-normal cursor-pointer px-2.5",
            !dateRange?.from && !dateRange?.to && "text-muted-foreground"
          )}
        >
          <CalendarIcon className="mr-2 size-4 opacity-50" />
          {dateRange?.from ? (
            dateRange.to ? (
              <>
                {format(dateRange.from, "dd MMM yyyy", { locale: id })} -{" "}
                {format(dateRange.to, "dd MMM yyyy", { locale: id })}
              </>
            ) : (
              format(dateRange.from, "dd MMM yyyy", { locale: id })
            )
          ) : (
            <span>{placeholder}</span>
          )}
          {dateRange?.from || dateRange?.to ? (
            <button
              type="button"
              onClick={handleClear}
              className="ml-auto rounded-sm opacity-50 hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring"
              aria-label="Hapus filter tanggal"
            >
              <X className="size-4" />
              <span className="sr-only">Hapus filter tanggal</span>
            </button>
          ) : null}
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-auto p-0" align="start">
        <Calendar
          mode="range"
          defaultMonth={dateRange?.from}
          selected={dateRange}
          onSelect={onDateRangeChange}
          numberOfMonths={numberOfMonths}
          fromMonth={fromMonth}
          toMonth={toMonth}
          captionLayout="dropdown"
        />
      </PopoverContent>
    </Popover>
  )
}
