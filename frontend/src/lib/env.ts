import { z } from "zod"

const envSchema = z.object({
  /**
   * API base URL. Set in .env, e.g. http://localhost:8000
   * Production: https://api.yourdomain.com
   */
  VITE_API_URL: z.string().url().optional().default("http://localhost:8000"),
})

const parsed = envSchema.safeParse({
  VITE_API_URL: import.meta.env.VITE_API_URL,
})

if (!parsed.success) {
  console.error("Invalid environment variables:", parsed.error.flatten())
  throw new Error("Invalid environment variables")
}

export const env = parsed.data
