# Regions (Wilayah Indonesia)

Indonesian administrative divisions: **Provinsi → Kabupaten/Kota → Kecamatan → Kelurahan/Desa**.

Used for applicant address dropdowns so pelamar can search/select by provinsi, kabupaten, kecamatan, kelurahan.

## Data source

[ibnux/data-indonesia](https://github.com/ibnux/data-indonesia) – JSON format, ~91k records (provinsi, kabupaten, kota, kecamatan, kelurahan).

## Import data

1. Clone the data repo:
   ```bash
   git clone https://github.com/ibnux/data-indonesia.git
   ```

2. Run the management command (with venv active):
   ```bash
   cd backend
   python manage.py load_indonesia_regions --path /path/to/data-indonesia
   ```
   Or set `DATA_INDONESIA_PATH` in `.env` and run:
   ```bash
   python manage.py load_indonesia_regions
   ```

3. Optional: clear existing data and re-import:
   ```bash
   python manage.py load_indonesia_regions --path /path/to/data-indonesia --clear
   ```

## API (public, no auth)

- `GET /api/provinces/` – list provinces (optional `?search=...`)
- `GET /api/regencies/?province_id=<id>` – list kabupaten/kota (optional `?search=...`)
- `GET /api/districts/?regency_id=<id>` – list kecamatan (optional `?search=...`)
- `GET /api/villages/?district_id=<id>` – list kelurahan/desa (optional `?search=...`)

Use these for cascading dropdowns: Province → Regency → District → Village.

## Applicant profile

- `ApplicantProfile.village` – FK to Village (alamat KTP). When set, `village_display` in API returns `{ province, regency, district, village }`.
- `ApplicantProfile.family_village` – FK to Village (alamat keluarga). Same for `family_village_display`.
- `address` / `family_address` remain for free text (jalan, dusun, RT/RW).
- CharField `district`, `province`, `family_district`, `family_province` are kept for backward compatibility and forms that only select province/regency.
