"""
Seed tipe dokumen TKI sesuai spesifikasi klien.
Kode harus sama dengan account.document_specs.DOCUMENT_SPECS.
"""
from django.core.management.base import BaseCommand

from account.document_specs import DOCUMENT_SPECS
from account.models import DocumentType

INITIAL = DocumentType.PHASE_INITIAL
POST = DocumentType.PHASE_POST_INTERVIEW

# code -> (name, is_required, sort_order, description, phase)
DOCUMENT_NAMES = {
    # ── INITIAL ──────────────────────────────────────────────────────────────
    "ktp":                            ("KTP",                               True,  1,  "JPG/PNG, maks. 500 KB.", INITIAL),
    "ijasah":                         ("Ijazah",                            True,  2,  "JPG/PNG, maks. 500 KB.", INITIAL),
    "kartu-keluarga":                 ("Kartu Keluarga",                    True,  3,  "JPG/PNG, maks. 500 KB.", INITIAL),
    "kartu-bpjs":                     ("Kartu BPJS Kesehatan",              True,  4,  "JPG/PNG, maks. 500 KB.", INITIAL),
    "paspor":                         ("Paspor",                            True,  5,  "JPG/PNG, maks. 500 KB.", INITIAL),
    "pas-foto":                      ("Pas Foto",                         True,  6,  "JPG/PNG, maks. 500 KB.", INITIAL),
    "sertifikat-keterampilan":        ("Sertifikat Keterampilan",           False, 7,  "Jika ada. PDF, maks. 2 MB.", INITIAL),
    # ── POST_INTERVIEW ───────────────────────────────────────────────────────
    "ijin-keluarga":                  ("Surat Izin Keluarga (Form Biru)",   True,  8,  "PDF, maks. 2 MB.", POST),
    "surat-keterangan-pemberi-ijin":  ("Surat Keterangan Pemberi Izin",     True,  9,  "PDF, maks. 2 MB.", POST),
    "ktp-orangtua-wali":              ("KTP Orangtua / Wali",               True,  10, "JPG/PNG, maks. 500 KB.", POST),
    "surat-kesehatan":                ("Surat Kesehatan",                   True,  11, "PDF, maks. 2 MB.", POST),
    "surat-keterangan-status-perkawinan": ("Surat Keterangan Status Perkawinan", True, 12, "PDF, maks. 2 MB.", POST),
    "buku-nikah":                     ("Buku Nikah",                        False, 13, "Bagi yang sudah menikah. JPG/PNG, maks. 500 KB.", POST),
    "perjanjian-penempatan":          ("Perjanjian Penempatan",             True,  14, "PDF, maks. 2 MB.", POST),
}


class Command(BaseCommand):
    help = "Buat/update tipe dokumen TKI (7 INITIAL + 7 POST_INTERVIEW)."

    def handle(self, *args, **options):
        for code in DOCUMENT_SPECS:
            name, is_required, sort_order, description, phase = DOCUMENT_NAMES.get(
                code, (code.replace("-", " ").title(), True, 99, "", INITIAL)
            )
            obj, created = DocumentType.objects.update_or_create(
                code=code,
                defaults={
                    "name": name,
                    "is_required": is_required,
                    "sort_order": sort_order,
                    "description": description,
                    "phase": phase,
                },
            )
            action = "Created" if created else "Updated"
            self.stdout.write(f"  {action}: [{obj.phase}] {obj.code} – {obj.name}")

        from django.core.cache import cache
        cache.delete('document_types_all')
        cache.delete('document_types_required')
        cache.delete('document_types_public_list')
        self.stdout.write(self.style.SUCCESS("Done. 14 document types ready. Caches cleared."))

