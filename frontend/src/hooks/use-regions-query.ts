/**
 * TanStack Query hooks for regions API (provinces, regencies, districts, villages).
 */

import { useQuery } from "@tanstack/react-query"
import {
  getProvinces,
  getRegencies,
  getDistricts,
  getVillages,
} from "@/api/regions"

export const regionsKeys = {
  provinces: (search?: string) => ["regions", "provinces", search] as const,
  regencies: (provinceId: number | null, search?: string) =>
    ["regions", "regencies", provinceId, search] as const,
  districts: (regencyId: number | null, search?: string) =>
    ["regions", "districts", regencyId, search] as const,
  villages: (districtId: number | null, search?: string) =>
    ["regions", "villages", districtId, search] as const,
}

export function useProvincesQuery(search?: string) {
  return useQuery({
    queryKey: regionsKeys.provinces(search),
    queryFn: () => getProvinces(search),
  })
}

export function useRegenciesQuery(provinceId: number | null, search?: string) {
  return useQuery({
    queryKey: regionsKeys.regencies(provinceId, search),
    queryFn: () => getRegencies(provinceId, search),
    // Allow querying all regencies when provinceId is null (for birth_place)
    enabled: true,
  })
}

export function useDistrictsQuery(regencyId: number | null, search?: string) {
  return useQuery({
    queryKey: regionsKeys.districts(regencyId, search),
    queryFn: () => getDistricts(regencyId, search),
    enabled: regencyId != null && regencyId > 0,
  })
}

export function useVillagesQuery(districtId: number | null, search?: string) {
  return useQuery({
    queryKey: regionsKeys.villages(districtId, search),
    queryFn: () => getVillages(districtId, search),
    enabled: districtId != null && districtId > 0,
  })
}
