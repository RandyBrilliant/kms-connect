"""
Import Indonesian administrative data from optimized CSV files.

Data source: CSV files in backend/data/ folder
Structure:
  - provinsi.csv   -> Province (kode, nama)
  - kota.csv       -> Regency (kode, kode_kartu, provinsi, nama)
  - kecamatan.csv  -> District (kode, provinsi, kota, nama)
  - kelurahan.csv  -> Village (kode, provinsi, kota, kecamatan, nama)

Usage:
  python manage.py load_indonesia_regions [--clear]

The command automatically finds CSV files in the backend/data/ folder.
Uses optimized bulk operations for fast import (~84k villages in seconds).
"""

import csv
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand
from django.db import transaction

from regions.models import Province, Regency, District, Village


class Command(BaseCommand):
    help = "Import Provinsi, Kabupaten/Kota, Kecamatan, Kelurahan from optimized CSV files."

    def _detect_encoding(self, file_path):
        """Detect file encoding by trying common encodings for Indonesian data."""
        encodings = ['utf-8', 'utf-8-sig', 'cp1252', 'windows-1252', 'iso-8859-1', 'latin-1']
        
        for encoding in encodings:
            try:
                with open(file_path, 'r', encoding=encoding) as f:
                    f.read()
                return encoding
            except (UnicodeDecodeError, UnicodeError):
                continue
        
        # Fallback to utf-8 with error handling
        self.stdout.write(
            self.style.WARNING(f"  ⚠ Could not detect encoding for {file_path.name}, using utf-8 with error replacement")
        )
        return 'utf-8'

    def add_arguments(self, parser):
        parser.add_argument(
            "--clear",
            action="store_true",
            help="Clear existing region data before import.",
        )
        parser.add_argument(
            "--path",
            type=str,
            default=None,
            help="Path to data folder (default: backend/data/).",
        )

    def handle(self, *args, **options):
        # Determine data folder path
        if options.get("path"):
            data_dir = Path(options["path"])
        else:
            # Default to backend/data/ folder
            data_dir = Path(settings.BASE_DIR) / "data"

        if not data_dir.is_dir():
            self.stderr.write(self.style.ERROR(f"Data directory not found: {data_dir}"))
            return

        # Verify all required CSV files exist
        required_files = {
            "provinsi": data_dir / "provinsi.csv",
            "kota": data_dir / "kota.csv",
            "kecamatan": data_dir / "kecamatan.csv",
            "kelurahan": data_dir / "kelurahan.csv",
        }

        for name, path in required_files.items():
            if not path.exists():
                self.stderr.write(self.style.ERROR(f"Missing {name}.csv in {data_dir}"))
                return

        self.stdout.write(self.style.NOTICE(f"Reading CSV files from: {data_dir}"))

        # Optional: Clear existing data
        if options.get("clear"):
            self.stdout.write("Clearing existing region data...")
            with transaction.atomic():
                counts = {
                    "Village": Village.objects.count(),
                    "District": District.objects.count(),
                    "Regency": Regency.objects.count(),
                    "Province": Province.objects.count(),
                }
                Village.objects.all().delete()
                District.objects.all().delete()
                Regency.objects.all().delete()
                Province.objects.all().delete()
            self.stdout.write(
                self.style.WARNING(
                    f"Deleted: {counts['Province']} provinces, {counts['Regency']} regencies, "
                    f"{counts['District']} districts, {counts['Village']} villages"
                )
            )

        # Import with transaction for data integrity
        with transaction.atomic():
            self._import_provinces(required_files["provinsi"])
            self._import_regencies(required_files["kota"])
            self._import_districts(required_files["kecamatan"])
            self._import_villages(required_files["kelurahan"])

        self.stdout.write(self.style.SUCCESS("\n✓ Import completed successfully!"))
        self.stdout.write(
            self.style.SUCCESS(
                f"  Total: {Province.objects.count()} provinces, "
                f"{Regency.objects.count()} regencies, "
                f"{District.objects.count()} districts, "
                f"{Village.objects.count()} villages"
            )
        )

    def _import_provinces(self, csv_file):
        """Import provinces with bulk_create for optimal performance."""
        self.stdout.write(f"\n[1/4] Importing provinces from {csv_file.name}...")

        provinces_to_create = []
        existing_codes = set(Province.objects.values_list("code", flat=True))
        
        encoding = self._detect_encoding(csv_file)

        with open(csv_file, "r", encoding=encoding, errors='replace') as f:
            reader = csv.DictReader(f)
            for row in reader:
                code = row["kode"].strip()
                name = row["nama"].strip().upper()

                if code not in existing_codes:
                    provinces_to_create.append(
                        Province(code=code, name=name)
                    )
                    existing_codes.add(code)

        if provinces_to_create:
            Province.objects.bulk_create(provinces_to_create, batch_size=100)

        count = Province.objects.count()
        self.stdout.write(self.style.SUCCESS(f"  ✓ {count} provinces ({len(provinces_to_create)} new)"))

    def _import_regencies(self, csv_file):
        """Import regencies with bulk_create and optimized lookups."""
        self.stdout.write(f"\n[2/4] Importing regencies from {csv_file.name}...")

        # Build province lookup cache
        province_cache = {p.code: p for p in Province.objects.all()}
        existing_codes = set(Regency.objects.values_list("code", flat=True))
        regencies_to_create = []
        
        encoding = self._detect_encoding(csv_file)

        with open(csv_file, "r", encoding=encoding, errors='replace') as f:
            reader = csv.DictReader(f)
            for row in reader:
                code = row["kode"].strip()
                prov_code = row["provinsi"].strip()
                name = row["nama"].strip().upper()

                province = province_cache.get(prov_code)
                if not province:
                    self.stderr.write(
                        self.style.WARNING(f"  ⚠ Province {prov_code} not found for regency {code}")
                    )
                    continue

                if code not in existing_codes:
                    regencies_to_create.append(
                        Regency(code=code, name=name, province=province)
                    )
                    existing_codes.add(code)

        if regencies_to_create:
            Regency.objects.bulk_create(regencies_to_create, batch_size=500)

        count = Regency.objects.count()
        self.stdout.write(self.style.SUCCESS(f"  ✓ {count} regencies ({len(regencies_to_create)} new)"))

    def _import_districts(self, csv_file):
        """Import districts with bulk_create and optimized lookups."""
        self.stdout.write(f"\n[3/4] Importing districts from {csv_file.name}...")

        # Build regency lookup cache
        regency_cache = {r.code: r for r in Regency.objects.all()}
        existing_codes = set(District.objects.values_list("code", flat=True))
        districts_to_create = []
        
        encoding = self._detect_encoding(csv_file)

        with open(csv_file, "r", encoding=encoding, errors='replace') as f:
            reader = csv.DictReader(f)
            for row in reader:
                code = row["kode"].strip()
                kota_code = row["kota"].strip()
                name = row["nama"].strip().upper()

                regency = regency_cache.get(kota_code)
                if not regency:
                    self.stderr.write(
                        self.style.WARNING(f"  ⚠ Regency {kota_code} not found for district {code}")
                    )
                    continue

                if code not in existing_codes:
                    districts_to_create.append(
                        District(code=code, name=name, regency=regency)
                    )
                    existing_codes.add(code)

        if districts_to_create:
            # Larger batch size for better performance
            District.objects.bulk_create(districts_to_create, batch_size=1000)

        count = District.objects.count()
        self.stdout.write(self.style.SUCCESS(f"  ✓ {count} districts ({len(districts_to_create)} new)"))

    def _import_villages(self, csv_file):
        """Import villages with bulk_create and optimized lookups."""
        self.stdout.write(f"\n[4/4] Importing villages from {csv_file.name}...")

        # Build district lookup cache
        district_cache = {d.code: d for d in District.objects.all()}
        existing_codes = set(Village.objects.values_list("code", flat=True))
        villages_to_create = []
        
        encoding = self._detect_encoding(csv_file)
        self.stdout.write(f"  → Using encoding: {encoding}")

        with open(csv_file, "r", encoding=encoding, errors='replace') as f:
            reader = csv.DictReader(f)
            row_count = 0
            for row in reader:
                row_count += 1
                code = row["kode"].strip()
                kecamatan_code = row["kecamatan"].strip()
                name = row["nama"].strip().upper()

                district = district_cache.get(kecamatan_code)
                if not district:
                    # Only warn for first few missing districts to avoid spam
                    if row_count <= 10:
                        self.stderr.write(
                            self.style.WARNING(f"  ⚠ District {kecamatan_code} not found for village {code}")
                        )
                    continue

                if code not in existing_codes:
                    villages_to_create.append(
                        Village(code=code, name=name, district=district)
                    )
                    existing_codes.add(code)

                # Progress indicator for large dataset
                if row_count % 10000 == 0:
                    self.stdout.write(f"  → Processed {row_count:,} rows...")

        if villages_to_create:
            # Largest batch size for ~84k villages
            self.stdout.write(f"  → Bulk creating {len(villages_to_create):,} villages...")
            Village.objects.bulk_create(villages_to_create, batch_size=2000)

        count = Village.objects.count()
        self.stdout.write(self.style.SUCCESS(f"  ✓ {count:,} villages ({len(villages_to_create):,} new)"))
