/**
 * Cascading region select: Province → Regency → District (Kec) → Village.
 * ApplicantProfile saves province, district (Regency id), village.
 * District (Kec) is internal for cascade only.
 * Uses searchable dropdowns for better UX with large option lists.
 */

import { useEffect, useState } from "react"
import { SearchableSelect } from "@/components/ui/searchable-select"
import { Field, FieldLabel } from "@/components/ui/field"
import {
  useProvincesQuery,
  useRegenciesQuery,
  useDistrictsQuery,
  useVillagesQuery,
} from "@/hooks/use-regions-query"
import { getVillage } from "@/api/regions"

export interface RegionAddressValue {
  province: number | null
  district: number | null // Regency id
  village: number | null
}

interface RegionAddressFieldsProps {
  value: RegionAddressValue
  onChange: (v: RegionAddressValue) => void
  disabled?: boolean
  /** When loading existing profile with village_id, we need district (Kec) to show cascade */
  initialDistrictId?: number | null
  labelPrefix?: string
}

export function RegionAddressFields({
  value,
  onChange,
  disabled = false,
  initialDistrictId = null,
  labelPrefix = "",
}: RegionAddressFieldsProps) {
  const [districtId, setDistrictId] = useState<number | null>(initialDistrictId ?? null)

  const { data: provinces = [], isPending: provincesLoading } = useProvincesQuery()
  const { data: regencies = [], isPending: regenciesLoading } =
    useRegenciesQuery(value.province)
  const { data: districts = [], isPending: districtsLoading } =
    useDistrictsQuery(value.district)
  const { data: villages = [], isPending: villagesLoading } =
    useVillagesQuery(districtId)

  // When we have village_id on load, fetch village to get district (Kec) for cascade
  useEffect(() => {
    if (value.village && !initialDistrictId && !districtId) {
      getVillage(value.village)
        .then((v) => setDistrictId(v.district))
        .catch(() => {})
    }
  }, [value.village, initialDistrictId, districtId])

  // When regency changes, clear district (Kec) selection
  useEffect(() => {
    setDistrictId(null)
  }, [value.district])

  const setProvince = (id: number | null) =>
    onChange({ province: id, district: null, village: null })
  const setDistrict = (id: number | null) => {
    onChange({ ...value, district: id, village: null })
    setDistrictId(null)
  }
  const setKecamatan = (id: number | null) => {
    setDistrictId(id)
    onChange({ ...value, village: null })
  }
  const setVillage = (id: number | null) => onChange({ ...value, village: id })

  const provinceLabel = labelPrefix ? `${labelPrefix} Provinsi` : "Provinsi"
  const regencyLabel = labelPrefix ? `${labelPrefix} Kab/Kota` : "Kabupaten/Kota"
  const kecLabel = labelPrefix ? `${labelPrefix} Kecamatan` : "Kecamatan"
  const villageLabel = labelPrefix ? `${labelPrefix} Kelurahan/Desa` : "Kelurahan/Desa"

  return (
    <div className="grid gap-4 sm:grid-cols-2">
      <Field>
        <FieldLabel>{provinceLabel}</FieldLabel>
        <SearchableSelect
          items={provinces}
          value={value.province}
          onChange={setProvince}
          placeholder="Pilih provinsi"
          clearLabel="Pilih provinsi"
          disabled={disabled}
          loading={provincesLoading}
          emptyMessage="Tidak ada provinsi"
        />
      </Field>

      <Field>
        <FieldLabel>{regencyLabel}</FieldLabel>
        <SearchableSelect
          items={regencies}
          value={value.district}
          onChange={setDistrict}
          placeholder="Pilih kabupaten/kota"
          clearLabel="Pilih kabupaten/kota"
          disabled={disabled || !value.province}
          loading={regenciesLoading}
          emptyMessage="Tidak ada kabupaten/kota"
        />
      </Field>

      <Field>
        <FieldLabel>{kecLabel}</FieldLabel>
        <SearchableSelect
          items={districts}
          value={districtId}
          onChange={setKecamatan}
          placeholder="Pilih kecamatan"
          clearLabel="Pilih kecamatan"
          disabled={disabled || !value.district}
          loading={districtsLoading}
          emptyMessage="Tidak ada kecamatan"
        />
      </Field>

      <Field>
        <FieldLabel>{villageLabel}</FieldLabel>
        <SearchableSelect
          items={villages}
          value={value.village}
          onChange={setVillage}
          placeholder="Pilih kelurahan/desa"
          clearLabel="Pilih kelurahan/desa"
          disabled={disabled || !districtId}
          loading={villagesLoading}
          emptyMessage="Tidak ada kelurahan/desa"
        />
      </Field>
    </div>
  )
}
