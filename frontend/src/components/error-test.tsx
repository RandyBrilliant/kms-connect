/**
 * Component for testing error boundaries in development
 * Add this component to any route to test error handling
 * 
 * Usage:
 * import { ErrorTest } from "@/components/error-test"
 * 
 * // In your route/page
 * {import.meta.env.DEV && <ErrorTest />}
 */

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { IconBug } from "@tabler/icons-react"

export function ErrorTest() {
  const [shouldThrow, setShouldThrow] = useState(false)

  if (shouldThrow) {
    throw new Error("Test Error: Error boundary is working correctly!")
  }

  const handleAsyncError = async () => {
    // Simulate async error
    await new Promise((resolve) => setTimeout(resolve, 500))
    throw new Error("Test Async Error: This is an async error!")
  }

  const handlePromiseRejection = () => {
    // Unhandled promise rejection
    Promise.reject(new Error("Test Promise Rejection: Unhandled rejection!"))
  }

  return (
    <Card className="border-dashed border-destructive/50">
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-destructive">
          <IconBug className="size-5" />
          Error Boundary Testing (Dev Only)
        </CardTitle>
        <CardDescription>
          Test error boundaries by triggering different types of errors
        </CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        <Button
          variant="destructive"
          size="sm"
          onClick={() => setShouldThrow(true)}
        >
          Throw Render Error
        </Button>
        <Button
          variant="destructive"
          size="sm"
          onClick={() => handleAsyncError()}
        >
          Throw Async Error
        </Button>
        <Button
          variant="destructive"
          size="sm"
          onClick={handlePromiseRejection}
        >
          Unhandled Promise Rejection
        </Button>
        <Button
          variant="destructive"
          size="sm"
          onClick={() => {
            // @ts-expect-error - Testing undefined reference
            console.log(undefinedVariable.property)
          }}
        >
          Reference Error
        </Button>
      </CardContent>
    </Card>
  )
}
