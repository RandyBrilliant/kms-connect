"""
Import Indonesian administrative data from ibnux/data-indonesia JSON.

Data source: https://github.com/ibnux/data-indonesia
Structure:
  - provinsi.json          -> Province
  - kabupaten/{id}.json   -> Regency (Kabupaten + Kota in one file per province)
  - kecamatan/{id}.json    -> District (id = regency code)
  - kelurahan/{id}.json   -> Village (id = district code)

Usage:
  1. Clone the repo: git clone https://github.com/ibnux/data-indonesia.git
  2. Run: python manage.py load_indonesia_regions --path /path/to/data-indonesia

Or set DATA_INDONESIA_PATH in .env and run: python manage.py load_indonesia_regions
"""

import json
from pathlib import Path

from django.core.management.base import BaseCommand

from regions.models import Province, Regency, District, Village


class Command(BaseCommand):
    help = "Import Provinsi, Kabupaten/Kota, Kecamatan, Kelurahan from ibnux/data-indonesia JSON."

    def add_arguments(self, parser):
        parser.add_argument(
            "--path",
            type=str,
            default=None,
            help="Path to cloned data-indonesia repo (or set DATA_INDONESIA_PATH in .env).",
        )
        parser.add_argument(
            "--clear",
            action="store_true",
            help="Clear existing region data before import.",
        )

    def handle(self, *args, **options):
        path = options.get("path")
        if not path:
            import os
            path = os.environ.get("DATA_INDONESIA_PATH")
        if not path:
            self.stderr.write(
                "Provide --path /path/to/data-indonesia or set DATA_INDONESIA_PATH."
            )
            return

        base = Path(path)
        if not base.is_dir():
            self.stderr.write(f"Path is not a directory: {base}")
            return

        # Optional: provinsi.json or provinsi.json (ibnux uses provinsi.json)
        provinsi_file = base / "provinsi.json"
        if not provinsi_file.exists():
            provinsi_file = base / "propinsi.json"
        if not provinsi_file.exists():
            self.stderr.write(f"Not found: provinsi.json or propinsi.json in {base}")
            return

        kabupaten_dir = base / "kabupaten"
        kecamatan_dir = base / "kecamatan"
        kelurahan_dir = base / "kelurahan"
        # ibnux has kabupaten/12.json (both kab and kota in one file for Sumatera Utara)
        if not kabupaten_dir.is_dir():
            self.stderr.write(f"Not found: kabupaten/ in {base}")
            return

        if options.get("clear"):
            self.stdout.write("Clearing existing region data...")
            Village.objects.all().delete()
            District.objects.all().delete()
            Regency.objects.all().delete()
            Province.objects.all().delete()

        # 1. Load provinces
        with open(provinsi_file, "r", encoding="utf-8") as f:
            provinces_data = json.load(f)
        if not isinstance(provinces_data, list):
            provinces_data = [provinces_data]

        created_provinces = 0
        for item in provinces_data:
            code = str(item.get("id", "")).strip()
            name = (item.get("nama") or item.get("name") or "").strip()
            if not code or not name:
                continue
            _, created = Province.objects.update_or_create(
                code=code,
                defaults={"name": name.upper()},
            )
            if created:
                created_provinces += 1

        self.stdout.write(f"Provinces: {Province.objects.count()} ({created_provinces} new)")

        # 2. Load regencies (kabupaten + kota: ibnux uses kabupaten/{id}.json per province)
        created_regencies = 0
        for prov in Province.objects.all():
            kab_file = kabupaten_dir / f"{prov.code}.json"
            if not kab_file.exists():
                continue
            with open(kab_file, "r", encoding="utf-8") as f:
                regs_data = json.load(f)
            if not isinstance(regs_data, list):
                regs_data = [regs_data]
            for item in regs_data:
                code = str(item.get("id", "")).strip()
                name = (item.get("nama") or item.get("name") or "").strip()
                if not code or not name:
                    continue
                _, created = Regency.objects.update_or_create(
                    code=code,
                    defaults={"province": prov, "name": name.upper()},
                )
                if created:
                    created_regencies += 1

        self.stdout.write(f"Regencies: {Regency.objects.count()} ({created_regencies} new)")

        # 3. Load districts (kecamatan)
        created_districts = 0
        for reg in Regency.objects.all():
            kec_file = kecamatan_dir / f"{reg.code}.json"
            if not kec_file.exists():
                continue
            with open(kec_file, "r", encoding="utf-8") as f:
                dist_data = json.load(f)
            if not isinstance(dist_data, list):
                dist_data = [dist_data]
            for item in dist_data:
                code = str(item.get("id", "")).strip()
                name = (item.get("nama") or item.get("name") or "").strip()
                if not code or not name:
                    continue
                _, created = District.objects.update_or_create(
                    code=code,
                    defaults={"regency": reg, "name": name.upper()},
                )
                if created:
                    created_districts += 1

        self.stdout.write(f"Districts: {District.objects.count()} ({created_districts} new)")

        # 4. Load villages (kelurahan)
        created_villages = 0
        for dist in District.objects.all():
            kel_file = kelurahan_dir / f"{dist.code}.json"
            if not kel_file.exists():
                continue
            with open(kel_file, "r", encoding="utf-8") as f:
                vill_data = json.load(f)
            if not isinstance(vill_data, list):
                vill_data = [vill_data]
            for item in vill_data:
                code = str(item.get("id", "")).strip()
                name = (item.get("nama") or item.get("name") or "").strip()
                if not code or not name:
                    continue
                _, created = Village.objects.update_or_create(
                    code=code,
                    defaults={"district": dist, "name": name.upper()},
                )
                if created:
                    created_villages += 1

        self.stdout.write(f"Villages: {Village.objects.count()} ({created_villages} new)")
        self.stdout.write(self.style.SUCCESS("Import finished."))
