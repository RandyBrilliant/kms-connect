import { IconEye, IconEyeOff } from "@tabler/icons-react"

import { Input } from "@/components/ui/input"
import { FieldError } from "@/components/ui/field"
import { cn } from "@/lib/utils"

export interface PasswordInputProps {
  id: string
  value: string
  onChange: (value: string) => void
  placeholder?: string
  showPassword: boolean
  onToggleVisibility: () => void
  error?: string
  disabled?: boolean
  autoComplete?: string
}

export function PasswordInput({
  id,
  value,
  onChange,
  placeholder,
  showPassword,
  onToggleVisibility,
  error,
  disabled,
  autoComplete = "new-password",
}: PasswordInputProps) {
  return (
    <>
      <div className="relative">
        <Input
          id={id}
          type={showPassword ? "text" : "password"}
          placeholder={placeholder}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          disabled={disabled}
          autoComplete={autoComplete}
          className={cn("pr-10", error && "border-destructive")}
        />
        <button
          type="button"
          onClick={onToggleVisibility}
          className="text-muted-foreground hover:text-foreground absolute right-3 top-1/2 -translate-y-1/2 cursor-pointer"
          tabIndex={-1}
          aria-label={showPassword ? "Sembunyikan password" : "Tampilkan password"}
        >
          {showPassword ? (
            <IconEyeOff className="size-4" />
          ) : (
            <IconEye className="size-4" />
          )}
        </button>
      </div>
      {error && <FieldError errors={[{ message: error }]} />}
    </>
  )
}

