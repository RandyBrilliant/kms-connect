import { useMutation } from "@tanstack/react-query"
import { useAuth } from "@/contexts/auth-context"

export function useLoginMutation() {
  const { login } = useAuth()
  return useMutation({
    mutationFn: async (values: { email: string; password: string }) => {
      await login(values.email, values.password)
    },
  })
}
