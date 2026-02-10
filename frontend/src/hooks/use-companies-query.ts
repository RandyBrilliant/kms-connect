/**
 * TanStack Query hooks for company users CRUD.
 */

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import {
  getCompanies,
  getCompany,
  createCompany,
  patchCompany,
  deactivateCompany,
  activateCompany,
  sendVerificationEmail,
  sendPasswordResetEmail,
} from "@/api/companies"
import type {
  CompaniesListParams,
  CompanyUserCreateInput,
  CompanyUserUpdateInput,
} from "@/types/company"

export const companiesKeys = {
  all: ["companies"] as const,
  lists: () => [...companiesKeys.all, "list"] as const,
  list: (params: CompaniesListParams) => [...companiesKeys.lists(), params] as const,
  details: () => [...companiesKeys.all, "detail"] as const,
  detail: (id: number) => [...companiesKeys.details(), id] as const,
}

export function useCompaniesQuery(params: CompaniesListParams = {}) {
  return useQuery({
    queryKey: companiesKeys.list(params),
    queryFn: () => getCompanies(params),
  })
}

export function useCompanyQuery(id: number | null, enabled = true) {
  return useQuery({
    queryKey: companiesKeys.detail(id ?? 0),
    queryFn: () => getCompany(id!),
    enabled: enabled && id != null && id > 0,
  })
}

export function useCreateCompanyMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: CompanyUserCreateInput) => createCompany(input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: companiesKeys.lists() })
    },
  })
}

export function useUpdateCompanyMutation(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: Partial<CompanyUserUpdateInput>) => patchCompany(id, input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: companiesKeys.lists() })
      queryClient.invalidateQueries({ queryKey: companiesKeys.detail(id) })
    },
  })
}

export function useDeactivateCompanyMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deactivateCompany(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: companiesKeys.lists() })
      queryClient.invalidateQueries({ queryKey: companiesKeys.detail(id) })
    },
  })
}

export function useActivateCompanyMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => activateCompany(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: companiesKeys.lists() })
      queryClient.invalidateQueries({ queryKey: companiesKeys.detail(id) })
    },
  })
}

export function useSendVerificationEmailMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (userId: number) => sendVerificationEmail(userId),
    onSuccess: (_, userId) => {
      queryClient.invalidateQueries({ queryKey: companiesKeys.detail(userId) })
    },
  })
}

export function useSendPasswordResetMutation() {
  return useMutation({
    mutationFn: (userId: number) => sendPasswordResetEmail(userId),
  })
}


