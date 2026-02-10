"""
Seed 12 tipe dokumen TKI sesuai spesifikasi: PDF ≤2MB (7) dan JPG ≤500KB (5).
Kode harus sama dengan account.document_specs.DOCUMENT_SPECS.
"""
from django.core.management.base import BaseCommand

from account.document_specs import DOCUMENT_SPECS
from account.models import DocumentType


# code -> (name, is_required, sort_order, description)
DOCUMENT_NAMES = {
    "ijasah": ("Ijasah", True, 1, "PDF, maks. 2 MB."),
    "sertifikat-keterampilan": ("Sertifikat Keterampilan", False, 2, "Jika ada. PDF, maks. 2 MB."),
    "ijin-keluarga": ("Ijin Keluarga", True, 3, "PDF, maks. 2 MB."),
    "surat-keterangan-pemberi-ijin": ("Surat Keterangan Pemberi Ijin", True, 4, "PDF, maks. 2 MB."),
    "surat-kesehatan": ("Surat Kesehatan", True, 5, "PDF, maks. 2 MB."),
    "surat-keterangan-status-perkawinan": ("Surat Keterangan Status Perkawinan", True, 6, "PDF, maks. 2 MB."),
    "perjanjian-penempatan": ("Perjanjian Penempatan", True, 7, "PDF, maks. 2 MB."),
    "photo-tki": ("Photo TKI", True, 8, "JPG/PNG, maks. 500 KB."),
    "ktp": ("KTP", True, 9, "JPG/PNG, maks. 500 KB."),
    "kartu-keluarga": ("Kartu Keluarga", True, 10, "JPG/PNG, maks. 500 KB."),
    "kartu-bpjs": ("Kartu BPJS", True, 11, "JPG/PNG, maks. 500 KB."),
    "paspor": ("Paspor", True, 12, "JPG/PNG, maks. 500 KB."),
}


class Command(BaseCommand):
    help = "Buat/update 12 tipe dokumen TKI (PDF ≤2MB dan JPG ≤500KB)."

    def handle(self, *args, **options):
        for code in DOCUMENT_SPECS:
            name, is_required, sort_order, description = DOCUMENT_NAMES.get(
                code, (code.replace("-", " ").title(), True, 99, "")
            )
            obj, created = DocumentType.objects.update_or_create(
                code=code,
                defaults={
                    "name": name,
                    "is_required": is_required,
                    "sort_order": sort_order,
                    "description": description,
                },
            )
            action = "Created" if created else "Updated"
            self.stdout.write(f"  {action}: {obj.code} – {obj.name}")

        self.stdout.write(self.style.SUCCESS("Done. 12 document types ready."))
