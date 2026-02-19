/**
 * Searchable combobox for large option lists.
 * Uses Popover + Input for type-to-search UX with client-side filtering.
 * Keyboard: ArrowUp/Down, Enter to select, Escape to close.
 */

import * as React from "react"
import { ChevronDownIcon } from "lucide-react"

import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover"

export interface SearchableSelectItem {
  id: number
  name: string
}

const CLEAR_ID = -1

interface SearchableSelectProps {
  items: SearchableSelectItem[]
  value: number | null
  onChange: (id: number | null) => void
  placeholder?: string
  /** Label for the clear/none option (when clearable). Defaults to placeholder. */
  clearLabel?: string
  disabled?: boolean
  loading?: boolean
  emptyMessage?: string
  /** Show "Clear" option to reset selection */
  clearable?: boolean
  className?: string
  filterFn?: (item: SearchableSelectItem, query: string) => boolean
}

const defaultFilter = (item: SearchableSelectItem, query: string) => {
  const q = query.trim().toLowerCase()
  return q === "" || item.name.toLowerCase().includes(q)
}

export function SearchableSelect({
  items,
  value,
  onChange,
  placeholder = "Cari atau pilih...",
  clearLabel,
  disabled = false,
  loading = false,
  emptyMessage = "Tidak ada hasil",
  clearable = true,
  className,
  filterFn = defaultFilter,
}: SearchableSelectProps) {
  const clearOptionLabel = clearLabel ?? placeholder
  const [open, setOpen] = React.useState(false)
  const [query, setQuery] = React.useState("")
  const [highlightedIndex, setHighlightedIndex] = React.useState(0)
  const listRef = React.useRef<HTMLUListElement>(null)
  const inputRef = React.useRef<HTMLInputElement>(null)

  const selected = items.find((i) => i.id === value)

  const filtered = React.useMemo(() => {
    return items.filter((item) => filterFn(item, query))
  }, [items, query, filterFn])

  const selectableOptions = clearable
    ? [{ id: CLEAR_ID, name: clearOptionLabel } as SearchableSelectItem, ...filtered]
    : filtered

  const highlightedId =
    selectableOptions[highlightedIndex]?.id ?? selectableOptions[0]?.id

  const handleSelect = (id: number | null) => {
    onChange(id === CLEAR_ID ? null : id)
    setQuery("")
    setHighlightedIndex(0)
    setOpen(false)
    inputRef.current?.blur()
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (!open) {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault()
        setOpen(true)
        setQuery("")
        setHighlightedIndex(0)
      }
      return
    }

    switch (e.key) {
      case "Escape":
        e.preventDefault()
        setOpen(false)
        setQuery("")
        break
      case "ArrowDown":
        e.preventDefault()
        setHighlightedIndex((i) =>
          i < selectableOptions.length - 1 ? i + 1 : 0
        )
        break
      case "ArrowUp":
        e.preventDefault()
        setHighlightedIndex((i) =>
          i > 0 ? i - 1 : selectableOptions.length - 1
        )
        break
      case "Enter":
        e.preventDefault()
        handleSelect(
          selectableOptions[highlightedIndex]?.id ?? null
        )
        break
    }
  }

  React.useEffect(() => {
    if (open) {
      setHighlightedIndex(0)
    } else {
      setQuery("")
    }
  }, [open])

  const handleOpenAutoFocus = (e: Event) => {
    e.preventDefault()
    requestAnimationFrame(() => inputRef.current?.focus())
  }

  React.useEffect(() => {
    if (!open) return
    const el = listRef.current?.querySelector(
      `[data-value="${highlightedId}"]`
    ) as HTMLElement | null
    el?.scrollIntoView({ block: "nearest" })
  }, [highlightedIndex, highlightedId, open])

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="outline"
          role="combobox"
          aria-expanded={open}
          aria-haspopup="listbox"
          disabled={disabled}
          className={cn(
            "h-9 w-full justify-between font-normal",
            !selected && "text-muted-foreground",
            className
          )}
          onKeyDown={handleKeyDown}
        >
          <span className="truncate">
            {loading ? "Memuat..." : selected?.name ?? placeholder}
          </span>
          <ChevronDownIcon
            className={cn(
              "ml-2 h-4 w-4 shrink-0 opacity-50 transition-transform",
              open && "rotate-180"
            )}
          />
        </Button>
      </PopoverTrigger>
      <PopoverContent
        className="min-w-[var(--radix-popover-trigger-width)] p-0"
        align="start"
        onOpenAutoFocus={handleOpenAutoFocus}
        onCloseAutoFocus={(e) => e.preventDefault()}
      >
        <div className="flex flex-col gap-1 p-1">
          <Input
            ref={inputRef}
            placeholder={placeholder}
            value={query}
            onChange={(e) => {
              setQuery(e.target.value)
              setHighlightedIndex(0)
            }}
            onKeyDown={handleKeyDown}
            className="h-8 shrink-0"
            autoComplete="off"
          />
          <ul
            ref={listRef}
            role="listbox"
            className="max-h-60 overflow-auto py-1"
          >
            {selectableOptions.length === 0 ? (
              <li className="text-muted-foreground py-6 text-center text-sm">
                {emptyMessage}
              </li>
            ) : (
              selectableOptions.map((item, idx) => (
                <li
                  key={item.id}
                  role="option"
                  aria-selected={value === (item.id === CLEAR_ID ? null : item.id)}
                  data-value={item.id}
                  className={cn(
                    "relative flex cursor-pointer select-none items-center rounded-sm px-2 py-1.5 text-sm outline-none",
                    highlightedIndex === idx &&
                      "bg-accent text-accent-foreground",
                    "hover:bg-accent hover:text-accent-foreground"
                  )}
                  onClick={() =>
                    handleSelect(item.id === CLEAR_ID ? null : item.id)
                  }
                  onMouseEnter={() => setHighlightedIndex(idx)}
                >
                  {item.name}
                </li>
              ))
            )}
          </ul>
        </div>
      </PopoverContent>
    </Popover>
  )
}
