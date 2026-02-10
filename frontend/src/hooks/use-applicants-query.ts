/**
 * TanStack Query hooks for applicants (Pelamar) CRUD.
 */

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import {
  getApplicants,
  getApplicant,
  createApplicant,
  patchApplicant,
  deactivateApplicant,
  activateApplicant,
  getWorkExperiences,
  createWorkExperience,
  updateWorkExperience,
  deleteWorkExperience,
  getApplicantDocuments,
  createApplicantDocument,
  deleteApplicantDocument,
  getDocumentTypes,
} from "@/api/applicants"
import type {
  ApplicantsListParams,
  ApplicantUserCreateInput,
  ApplicantUserUpdateInput,
  WorkExperienceCreateInput,
} from "@/types/applicant"

export const applicantsKeys = {
  all: ["applicants"] as const,
  lists: () => [...applicantsKeys.all, "list"] as const,
  list: (params: ApplicantsListParams) =>
    [...applicantsKeys.lists(), params] as const,
  details: () => [...applicantsKeys.all, "detail"] as const,
  detail: (id: number) => [...applicantsKeys.details(), id] as const,
  workExperiences: (applicantId: number) =>
    [...applicantsKeys.detail(applicantId), "work_experiences"] as const,
  documents: (applicantId: number) =>
    [...applicantsKeys.detail(applicantId), "documents"] as const,
}

export const documentTypesKeys = {
  all: ["document-types"] as const,
}

export function useApplicantsQuery(params: ApplicantsListParams = {}) {
  return useQuery({
    queryKey: applicantsKeys.list(params),
    queryFn: () => getApplicants(params),
  })
}

export function useApplicantQuery(id: number | null, enabled = true) {
  return useQuery({
    queryKey: applicantsKeys.detail(id ?? 0),
    queryFn: () => getApplicant(id!),
    enabled: enabled && id != null && id > 0,
  })
}

export function useCreateApplicantMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: ApplicantUserCreateInput) => createApplicant(input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: applicantsKeys.lists() })
    },
  })
}

export function useUpdateApplicantMutation(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: Partial<ApplicantUserUpdateInput>) =>
      patchApplicant(id, input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: applicantsKeys.lists() })
      queryClient.invalidateQueries({ queryKey: applicantsKeys.detail(id) })
    },
  })
}

export function useDeactivateApplicantMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deactivateApplicant(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: applicantsKeys.lists() })
      queryClient.invalidateQueries({ queryKey: applicantsKeys.detail(id) })
    },
  })
}

export function useActivateApplicantMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => activateApplicant(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: applicantsKeys.lists() })
      queryClient.invalidateQueries({ queryKey: applicantsKeys.detail(id) })
    },
  })
}

// --- Work Experiences ---
export function useWorkExperiencesQuery(applicantId: number | null, enabled = true) {
  return useQuery({
    queryKey: applicantsKeys.workExperiences(applicantId ?? 0),
    queryFn: () => getWorkExperiences(applicantId!),
    enabled: enabled && applicantId != null && applicantId > 0,
  })
}

export function useCreateWorkExperienceMutation(applicantId: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: WorkExperienceCreateInput) =>
      createWorkExperience(applicantId, input),
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: applicantsKeys.workExperiences(applicantId),
      })
      queryClient.invalidateQueries({ queryKey: applicantsKeys.detail(applicantId) })
    },
  })
}

export function useUpdateWorkExperienceMutation(applicantId: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({
      id,
      input,
    }: {
      id: number
      input: Partial<WorkExperienceCreateInput>
    }) => updateWorkExperience(applicantId, id, input),
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: applicantsKeys.workExperiences(applicantId),
      })
      queryClient.invalidateQueries({ queryKey: applicantsKeys.detail(applicantId) })
    },
  })
}

export function useDeleteWorkExperienceMutation(applicantId: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deleteWorkExperience(applicantId, id),
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: applicantsKeys.workExperiences(applicantId),
      })
      queryClient.invalidateQueries({ queryKey: applicantsKeys.detail(applicantId) })
    },
  })
}

// --- Documents ---
export function useApplicantDocumentsQuery(
  applicantId: number | null,
  enabled = true
) {
  return useQuery({
    queryKey: applicantsKeys.documents(applicantId ?? 0),
    queryFn: () => getApplicantDocuments(applicantId!),
    enabled: enabled && applicantId != null && applicantId > 0,
  })
}

export function useCreateApplicantDocumentMutation(applicantId: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (formData: FormData) =>
      createApplicantDocument(applicantId, formData),
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: applicantsKeys.documents(applicantId),
      })
      queryClient.invalidateQueries({ queryKey: applicantsKeys.detail(applicantId) })
    },
  })
}

export function useDeleteApplicantDocumentMutation(applicantId: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deleteApplicantDocument(applicantId, id),
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: applicantsKeys.documents(applicantId),
      })
      queryClient.invalidateQueries({ queryKey: applicantsKeys.detail(applicantId) })
    },
  })
}

// --- Document Types ---
export function useDocumentTypesQuery() {
  return useQuery({
    queryKey: documentTypesKeys.all,
    queryFn: () => getDocumentTypes(),
  })
}
