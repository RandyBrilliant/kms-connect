import * as React from "react"

import { cn } from "@/lib/utils"

export interface SwitchProps
  extends Omit<React.InputHTMLAttributes<HTMLInputElement>, "type"> {
  checked?: boolean
  onCheckedChange?: (checked: boolean) => void
}

export const Switch = React.forwardRef<HTMLInputElement, SwitchProps>(
  ({ className, checked, onCheckedChange, ...props }, ref) => {
    return (
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        onClick={() => onCheckedChange?.(!checked)}
        className={cn(
          "inline-flex h-5 w-9 items-center rounded-full border border-input bg-muted transition-colors",
          checked && "bg-primary",
          className
        )}
      >
        <span
          className={cn(
            "block h-4 w-4 translate-x-0 rounded-full bg-background shadow transition-transform",
            checked && "translate-x-4"
          )}
        />
        <input
          ref={ref}
          type="checkbox"
          className="sr-only"
          checked={checked}
          onChange={(e) => onCheckedChange?.(e.target.checked)}
          {...props}
        />
      </button>
    )
  }
)

Switch.displayName = "Switch"

