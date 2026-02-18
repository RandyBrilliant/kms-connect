/**
 * Regions API - Indonesian administrative divisions.
 * Backend: /api/provinces/, /api/regencies/, /api/districts/, /api/villages/
 * Hierarchy: Province → Regency (Kab/Kota) → District (Kec) → Village (Kel/Desa)
 */

import { api } from "@/lib/api"

export interface Province {
  id: number
  code: string
  name: string
}

export interface Regency {
  id: number
  code: string
  name: string
  province: number
}

export interface District {
  id: number
  code: string
  name: string
  regency: number
}

export interface Village {
  id: number
  code: string
  name: string
  district: number
}

/** GET /api/provinces/ */
export async function getProvinces(search?: string): Promise<Province[]> {
  const params = search ? `?search=${encodeURIComponent(search)}` : ""
  const { data } = await api.get<Province[] | { results: Province[] }>(
    `/api/provinces/${params}`
  )
  return Array.isArray(data) ? data : data.results ?? []
}

/** GET /api/regencies/?province_id=X */
export async function getRegencies(
  provinceId: number | null,
  search?: string
): Promise<Regency[]> {
  if (!provinceId) return []
  const params = new URLSearchParams({ province_id: String(provinceId) })
  if (search) params.set("search", search)
  const { data } = await api.get<Regency[] | { results: Regency[] }>(
    `/api/regencies/?${params}`
  )
  return Array.isArray(data) ? data : data.results ?? []
}

/** GET /api/districts/?regency_id=X */
export async function getDistricts(
  regencyId: number | null,
  search?: string
): Promise<District[]> {
  if (!regencyId) return []
  const params = new URLSearchParams({ regency_id: String(regencyId) })
  if (search) params.set("search", search)
  const { data } = await api.get<District[] | { results: District[] }>(
    `/api/districts/?${params}`
  )
  return Array.isArray(data) ? data : data.results ?? []
}

/** GET /api/villages/?district_id=X */
export async function getVillages(
  districtId: number | null,
  search?: string
): Promise<Village[]> {
  if (!districtId) return []
  const params = new URLSearchParams({ district_id: String(districtId) })
  if (search) params.set("search", search)
  const { data } = await api.get<Village[] | { results: Village[] }>(
    `/api/villages/?${params}`
  )
  return Array.isArray(data) ? data : data.results ?? []
}

/** GET /api/villages/:id/ - for fetching village's district when editing */
export async function getVillage(id: number): Promise<Village> {
  const { data } = await api.get<Village>(`/api/villages/${id}/`)
  return data
}
