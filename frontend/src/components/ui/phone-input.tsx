import * as React from "react"

import { cn } from "@/lib/utils"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Input } from "@/components/ui/input"

type CountryOption = {
  code: string
  name: string
  dialCode: string // e.g. "+62"
}

const COUNTRIES: CountryOption[] = [
  { code: "ID", name: "Indonesia", dialCode: "+62" },
  { code: "MY", name: "Malaysia", dialCode: "+60" },
  { code: "SG", name: "Singapore", dialCode: "+65" },
  { code: "TH", name: "Thailand", dialCode: "+66" },
  { code: "PH", name: "Philippines", dialCode: "+63" },
  { code: "VN", name: "Vietnam", dialCode: "+84" },
  { code: "BN", name: "Brunei", dialCode: "+673" },
  { code: "KH", name: "Cambodia", dialCode: "+855" },
  { code: "LA", name: "Laos", dialCode: "+856" },
  { code: "MM", name: "Myanmar", dialCode: "+95" },
  { code: "IN", name: "India", dialCode: "+91" },
  { code: "CN", name: "China", dialCode: "+86" },
  { code: "JP", name: "Japan", dialCode: "+81" },
  { code: "KR", name: "South Korea", dialCode: "+82" },
]

interface PhoneInputProps
  extends Omit<React.ComponentProps<"input">, "type" | "value" | "onChange"> {
  value: string
  onChange: (value: string) => void
  disabled?: boolean
}

/**
 * Phone input with country code dropdown.
 * - Renders select for country dial code and local number field.
 * - Normalizes value as: +<code><localWithoutLeadingZero>
 */
export function PhoneInput({
  value,
  onChange,
  disabled,
  className,
  ...props
}: PhoneInputProps) {
  // Derive selected country & local part from full value
  const selectedCountry =
    COUNTRIES.find((c) => value?.startsWith(c.dialCode)) ?? COUNTRIES[0]

  const localPart = React.useMemo(() => {
    if (!value) return ""
    if (value.startsWith(selectedCountry.dialCode)) {
      return value.slice(selectedCountry.dialCode.length)
    }
    // Fallback: treat whole value as local number
    return value
  }, [value, selectedCountry.dialCode])

  const updateValue = (country: CountryOption, nextLocalRaw: string) => {
    // Remove all spaces
    const trimmed = nextLocalRaw.replace(/\s+/g, "")
    // Omit leading zero(s) from local number (e.g. 0812 → 812)
    const withoutLeadingZero = trimmed.replace(/^0+/, "")
    if (!withoutLeadingZero) {
      onChange("")
      return
    }
    onChange(`${country.dialCode}${withoutLeadingZero}`)
  }

  return (
    <div className="flex gap-2 items-center">
      <Select
        value={selectedCountry.dialCode}
        onValueChange={(dialCode) => {
          const country =
            COUNTRIES.find((c) => c.dialCode === dialCode) ?? selectedCountry
          updateValue(country, localPart)
        }}
        disabled={disabled}
      >
        <SelectTrigger size="sm" className="min-w-[100px]">
          <SelectValue
            placeholder="Kode"
            aria-label={selectedCountry.name}
          >
            <span className="font-medium">{selectedCountry.dialCode}</span>
            <span className="text-muted-foreground text-xs">
              {selectedCountry.code}
            </span>
          </SelectValue>
        </SelectTrigger>
        <SelectContent>
          {COUNTRIES.map((country) => (
            <SelectItem key={country.code} value={country.dialCode}>
              <span className="font-medium">{country.dialCode}</span>
              <span className="text-muted-foreground text-xs">
                {country.name}
              </span>
            </SelectItem>
          ))}
        </SelectContent>
      </Select>

      <Input
        {...props}
        type="tel"
        disabled={disabled}
        className={cn("flex-1", className)}
        value={localPart}
        onChange={(e) => updateValue(selectedCountry, e.target.value)}
      />
    </div>
  )
}

