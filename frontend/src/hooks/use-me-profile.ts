import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getMyProfile, updateMyProfile, type MeProfile } from "@/api/me-profile"

const meProfileKey = ["me-profile"] as const

export function useMeProfileQuery() {
  return useQuery({
    queryKey: meProfileKey,
    queryFn: () => getMyProfile(),
  })
}

export function useUpdateMeProfileMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (payload: Partial<MeProfile>) => updateMyProfile(payload),
    onSuccess: (data) => {
      queryClient.setQueryData(meProfileKey, data)
    },
  })
}

