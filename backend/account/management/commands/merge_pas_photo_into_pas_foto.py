"""
Merge DocumentType `pas-photo` into canonical `pas-foto` without deleting files.

Usage:
  python manage.py merge_pas_photo_into_pas_foto
  python manage.py merge_pas_photo_into_pas_foto --apply
"""

from django.core.management.base import BaseCommand

from account.services.merge_pas_photo import merge_pas_photo_into_pas_foto


class Command(BaseCommand):
    help = (
        "Retarget pas-photo uploads onto pas-foto, then delete the extra type. "
        "Does not delete files in storage. Default is dry-run."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--apply",
            action="store_true",
            help="Write the merge. Without this flag, only print what would happen.",
        )

    def handle(self, *args, **options):
        result = merge_pas_photo_into_pas_foto(dry_run=not options["apply"])
        for line in result.summary_lines():
            self.stdout.write(line)
        if result.dry_run:
            self.stdout.write(self.style.WARNING("No changes written (dry-run)."))
        else:
            self.stdout.write(self.style.SUCCESS("Merge complete. Storage files were kept."))
