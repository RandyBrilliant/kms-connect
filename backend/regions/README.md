# Regions (Wilayah Indonesia)

Indonesian administrative divisions: **Provinsi → Kabupaten/Kota → Kecamatan → Kelurahan/Desa**.

Used for applicant address dropdowns so pelamar can search/select by provinsi, kabupaten, kecamatan, kelurahan.

## Data source

Optimized CSV files in `backend/data/` folder:
- `provinsi.csv` – 38 provinces
- `kota.csv` – 514 regencies (kabupaten/kota)
- `kecamatan.csv` – 7,277 districts
- `kelurahan.csv` – 83,762 villages

This CSV format is more storage-efficient than the original JSON from [ibnux/data-indonesia](https://github.com/ibnux/data-indonesia).

## Import data

The CSV files are already included in the repository. Simply run the management command:

```bash
cd backend
python manage.py load_indonesia_regions
```

**Options:**
- `--clear` – Clear existing data before import (useful for fresh start)
- `--path <path>` – Custom path to data folder (default: `backend/data/`)

**Examples:**
```bash
# Standard import (incremental, skips existing records)
python manage.py load_indonesia_regions

# Fresh import (clear all and re-import)
python manage.py load_indonesia_regions --clear

# Custom data path
python manage.py load_indonesia_regions --path /custom/path/to/data
```

**Performance:** Imports ~84k villages in seconds using optimized bulk operations.

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
