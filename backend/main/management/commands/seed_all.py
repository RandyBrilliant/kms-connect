"""
Menjalankan semua seed command sekaligus dalam urutan yang benar.

Usage:
    python manage.py seed_all
    python manage.py seed_all --clear   # Hapus semua data seed sebelum membuat ulang
    python manage.py seed_all --password=custom123  # Override password perusahaan
"""
from django.core.management.base import BaseCommand
from django.core.management import call_command


class Command(BaseCommand):
    help = "Jalankan semua seed: seed_document_types → seed_companies → seed_news → seed_jobs → seed_applicants."

    def add_arguments(self, parser):
        parser.add_argument(
            "--password",
            default="company@123!",
            help="Password untuk akun perusahaan (diteruskan ke seed_companies).",
        )
        parser.add_argument(
            "--applicant-password",
            default="applicant@123!",
            help="Password untuk akun pelamar (diteruskan ke seed_applicants).",
        )
        parser.add_argument(
            "--clear",
            action="store_true",
            help="Hapus semua data seed sebelum membuat ulang (diteruskan ke seed_news & seed_jobs).",
        )

    def handle(self, *args, **options):
        self.stdout.write(self.style.MIGRATE_HEADING("=" * 55))
        self.stdout.write(self.style.MIGRATE_HEADING("  KMS Connect — Seed All"))
        self.stdout.write(self.style.MIGRATE_HEADING("=" * 55))

        # 1. Document types — independent, needed before applicant documents.
        self.stdout.write(self.style.MIGRATE_LABEL("\n[1/5] Seeding tipe dokumen…"))
        call_command("seed_document_types")

        # 2. Companies must come before jobs.
        self.stdout.write(self.style.MIGRATE_LABEL("\n[2/5] Seeding companies…"))
        call_command("seed_companies", password=options["password"])

        # 3. News (independent)
        self.stdout.write(self.style.MIGRATE_LABEL("\n[3/5] Seeding berita…"))
        kwargs_clear = {"clear": options["clear"]}
        call_command("seed_news", **kwargs_clear)

        # 4. Jobs (depend on companies)
        self.stdout.write(self.style.MIGRATE_LABEL("\n[4/5] Seeding lowongan kerja…"))
        call_command("seed_jobs", **kwargs_clear)

        # 5. Applicants + job applications (depend on jobs)
        self.stdout.write(self.style.MIGRATE_LABEL("\n[5/5] Seeding pelamar…"))
        call_command("seed_applicants", password=options["applicant_password"], **kwargs_clear)

        self.stdout.write("\n" + self.style.SUCCESS("=" * 55))
        self.stdout.write(self.style.SUCCESS("  Selesai! Semua seed berhasil dijalankan."))
        self.stdout.write(self.style.SUCCESS("=" * 55))
