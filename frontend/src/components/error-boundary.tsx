import { Component, type ReactNode } from "react"
import { IconAlertTriangle, IconHome, IconRefresh } from "@tabler/icons-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"

interface ErrorBoundaryProps {
    children: ReactNode
    fallback?: ReactNode
    onError?: (error: Error, errorInfo: React.ErrorInfo) => void
}

interface ErrorBoundaryState {
    hasError: boolean
    error: Error | null
    errorInfo: React.ErrorInfo | null
}

export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
    constructor(props: ErrorBoundaryProps) {
        super(props)
        this.state = {
            hasError: false,
            error: null,
            errorInfo: null,
        }
    }

    static getDerivedStateFromError(error: Error): Partial<ErrorBoundaryState> {
        return {
            hasError: true,
            error,
        }
    }

    componentDidCatch(error: Error, errorInfo: React.ErrorInfo): void {
        // Log error to console in development
        if (import.meta.env.DEV) {
            console.error("Error Boundary caught an error:", error, errorInfo)
        }

        // Call optional error handler
        this.props.onError?.(error, errorInfo)

        this.setState({
            errorInfo,
        })

        // TODO: Log to error reporting service (e.g., Sentry, LogRocket)
        // logErrorToService(error, errorInfo)
    }

    handleReset = (): void => {
        this.setState({
            hasError: false,
            error: null,
            errorInfo: null,
        })
    }

    handleGoHome = (): void => {
        this.setState({
            hasError: false,
            error: null,
            errorInfo: null,
        })
        window.location.href = "/"
    }

    render(): ReactNode {
        if (this.state.hasError) {
            // Use custom fallback if provided
            if (this.props.fallback) {
                return this.props.fallback
            }

            // Default error UI
            return (
                <div className="flex min-h-screen items-center justify-center bg-muted/30 p-4">
                    <Card className="w-full max-w-lg">
                        <CardHeader>
                            <div className="mb-4 flex justify-center">
                                <div className="rounded-full bg-destructive/10 p-3">
                                    <IconAlertTriangle className="size-8 text-destructive" />
                                </div>
                            </div>
                            <CardTitle className="text-center text-2xl">
                                Terjadi Kesalahan
                            </CardTitle>
                            <CardDescription className="text-center">
                                Maaf, aplikasi mengalami masalah yang tidak terduga.
                            </CardDescription>
                        </CardHeader>
                        <CardContent>
                            {import.meta.env.DEV && this.state.error && (
                                <div className="rounded-lg border bg-muted p-4">
                                    <p className="mb-2 font-mono text-sm font-semibold text-destructive">
                                        {this.state.error.name}: {this.state.error.message}
                                    </p>
                                    {this.state.error.stack && (
                                        <pre className="max-h-48 overflow-auto text-xs text-muted-foreground">
                                            {this.state.error.stack}
                                        </pre>
                                    )}
                                </div>
                            )}
                            {!import.meta.env.DEV && (
                                <p className="text-center text-sm text-muted-foreground">
                                    Tim kami telah diberitahu tentang masalah ini dan sedang bekerja untuk memperbaikinya.
                                </p>
                            )}
                        </CardContent>
                        <CardFooter className="flex flex-col gap-2 sm:flex-row">
                            <Button
                                onClick={this.handleReset}
                                variant="default"
                                className="w-full gap-2"
                            >
                                <IconRefresh className="size-4" />
                                Coba Lagi
                            </Button>
                            <Button
                                onClick={this.handleGoHome}
                                variant="outline"
                                className="w-full gap-2"
                            >
                                <IconHome className="size-4" />
                                Ke Halaman Utama
                            </Button>
                        </CardFooter>
                    </Card>
                </div>
            )
        }

        return this.props.children
    }
}

// Lightweight error boundary for route-level errors
export class RouteErrorBoundary extends Component<
    ErrorBoundaryProps,
    ErrorBoundaryState
> {
    constructor(props: ErrorBoundaryProps) {
        super(props)
        this.state = {
            hasError: false,
            error: null,
            errorInfo: null,
        }
    }

    static getDerivedStateFromError(error: Error): Partial<ErrorBoundaryState> {
        return {
            hasError: true,
            error,
        }
    }

    componentDidCatch(error: Error, errorInfo: React.ErrorInfo): void {
        if (import.meta.env.DEV) {
            console.error("Route Error Boundary caught an error:", error, errorInfo)
        }
        this.props.onError?.(error, errorInfo)
        this.setState({ errorInfo })
    }

    handleReload = (): void => {
        window.location.reload()
    }

    render(): ReactNode {
        if (this.state.hasError) {
            if (this.props.fallback) {
                return this.props.fallback
            }

            return (
                <div className="flex flex-col items-center justify-center gap-4 p-8">
                    <IconAlertTriangle className="size-12 text-destructive" />
                    <h2 className="text-xl font-semibold">Gagal Memuat Halaman</h2>
                    <p className="text-center text-sm text-muted-foreground">
                        Terjadi kesalahan saat memuat halaman ini.
                    </p>
                    <Button onClick={this.handleReload} className="gap-2">
                        <IconRefresh className="size-4" />
                        Muat Ulang
                    </Button>
                </div>
            )
        }

        return this.props.children
    }
}
