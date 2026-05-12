"""
Backfill ApplicantProfile.disnaker from kabupaten/kota alamat KTP (uppercase).

Usage:
  python manage.py backfill_disnaker_from_ktp_address --dry-run
  python manage.py backfill_disnaker_from_ktp_address
  python manage.py backfill_disnaker_from_ktp_address --force
"""

from django.core.management.base import BaseCommand

from account.models import ApplicantProfile
from account.services.disnaker_default import ktp_kabupaten_kota_upper


class Command(BaseCommand):
    help = (
        "Set empty disnaker to kabupaten/kota from KTP address (uppercase). "
        "Use --force to overwrite existing disnaker values."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Print actions without writing to the database.",
        )
        parser.add_argument(
            "--force",
            action="store_true",
            help="Also overwrite profiles that already have a non-empty disnaker.",
        )

    def handle(self, *args, **options):
        dry_run: bool = options["dry_run"]
        force: bool = options["force"]

        qs = (
            ApplicantProfile.objects.select_related(
                "village__district__regency",
                "district",
            )
            .only(
                "id",
                "disnaker",
                "village_id",
                "district_id",
            )
            .order_by("id")
        )

        to_update = 0
        skipped_has_value = 0
        skipped_no_regency = 0
        batch: list[ApplicantProfile] = []
        batch_size = 400

        for profile in qs.iterator(chunk_size=200):
            stored = (profile.disnaker or "").strip()
            if stored and not force:
                skipped_has_value += 1
                continue

            new_val = ktp_kabupaten_kota_upper(profile)
            if not new_val:
                skipped_no_regency += 1
                continue

            to_update += 1
            if dry_run:
                self.stdout.write(
                    f"[dry-run] profile_id={profile.pk} disnaker -> {new_val!r}"
                )
                continue

            profile.disnaker = new_val
            batch.append(profile)
            if len(batch) >= batch_size:
                ApplicantProfile.objects.bulk_update(batch, ["disnaker"])
                batch.clear()

        if batch and not dry_run:
            ApplicantProfile.objects.bulk_update(batch, ["disnaker"])

        self.stdout.write(
            self.style.SUCCESS(
                f"Done. candidates={to_update} "
                f"skipped_already_set={skipped_has_value} "
                f"skipped_no_kab_kota={skipped_no_regency} dry_run={dry_run}"
            )
        )
