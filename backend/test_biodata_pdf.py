"""
Standalone test for biodata_pdf.py.
Generates a debug PDF (with crosshairs) without needing Django or a database.

Usage:
    cd backend
    python test_biodata_pdf.py

Output: biodata_test.pdf in the current directory.
"""

import os, sys, io
from datetime import date
from types import SimpleNamespace

# ── make sure Django apps are importable (just for the service module) ──────
sys.path.insert(0, os.path.dirname(__file__))

# Patch DEBUG_GRID on before importing the module
import account.services.biodata_pdf as svc
svc.DEBUG_GRID = True   # show crosshairs

# ── Build a fake ApplicantProfile with the sample data from the scan ─────────
user = SimpleNamespace(
    full_name="MIRA SETIAWAN",
    email="sakuchanisbrilliant@gmail.com",
)

birth_place = SimpleNamespace(name="KOTA MEDAN")

province  = SimpleNamespace(name="SUMATERA UTARA")
district  = SimpleNamespace(name="KOTA MEDAN")
village   = SimpleNamespace(name="HARJOSARI II")

family_province  = SimpleNamespace(name="SUMATERA UTARA")
family_district  = SimpleNamespace(name="KOTA MEDAN")
family_village   = SimpleNamespace(name="AMPLAS")

work_exp = SimpleNamespace(
    company_name="PT ABC",
    position="STAFF",
    start_date=date(2024, 6, 1),
    end_date=date(2025, 10, 1),
    still_employed=False,
    description="",
)

profile = SimpleNamespace(
    user=user,
    contact_phone="+6285159882048",
    address="JALAN MAHONI NO 16",
    birth_place=birth_place,
    birth_date=date(1986, 2, 18),
    province=province,
    district=district,
    village=village,
    sibling_count=2,
    birth_order=2,
    marital_status="BELUM MENIKAH",
    spouse_name="",
    spouse_age=None,
    spouse_occupation="",
    spouse_almarhum=False,
    father_almarhum=False,
    mother_almarhum=False,
    father_name="MUHAMMAD",
    father_age=40,
    father_occupation="WIRASWASTA",
    father_phone="+6281361712078",
    mother_name="MIRNA",
    mother_age=40,
    mother_occupation="IBU RUMAH TANGGA",
    mother_phone="+6281361712078",
    family_address="JALAN MAHONI NO 16",
    family_province=family_province,
    family_district=family_district,
    family_village=family_village,
    notes="",
    photo=None,
    work_experiences=SimpleNamespace(
        order_by=lambda *a: [work_exp]
    ),
)

pdf_bytes = svc.generate_biodata_pdf(profile)

out_path = os.path.join(os.path.dirname(__file__), "biodata_test.pdf")
with open(out_path, "wb") as f:
    f.write(pdf_bytes)

print(f"✓  PDF written to: {out_path}")
print("   Open it and compare crosshairs to the form boxes.")
print("   Adjust _F_* pixel coordinates in biodata_pdf.py then re-run.")
