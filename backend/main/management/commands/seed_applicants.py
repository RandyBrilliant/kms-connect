"""
Seed random pelamar (CustomUser + ApplicantProfile) tanpa lamaran lowongan kerja.

Distribusi status profil pelamar (verification_status):
  - DRAFT
  - SUBMITTED
  - ACCEPTED
  - REJECTED

Idempoten: cek email sebelum membuat user.

Usage:
    python manage.py seed_applicants
    python manage.py seed_applicants --count=50
    python manage.py seed_applicants --clear
"""
import random
from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.utils import timezone

from account.models import ApplicantProfile, ApplicantVerificationStatus, UserRole

User = get_user_model()

# ---------------------------------------------------------------------------
# Random name pools
# ---------------------------------------------------------------------------
FIRST_NAMES = [
    "Budi", "Siti", "Agus", "Dewi", "Rizki", "Nurul", "Eko", "Fitria",
    "Hendra", "Yuni", "Dian", "Rahmat", "Sri", "Wahyu", "Ayu", "Fajar",
    "Indra", "Lina", "Rudi", "Novi", "Andi", "Maya", "Joko", "Rina",
    "Tono", "Wati", "Hadi", "Nita", "Hasan", "Putri", "Irwan", "Dwi",
    "Agung", "Tari", "Bambang", "Sari", "Yusuf", "Ani", "Dedi", "Rini",
    "Supri", "Lastri", "Fauzi", "Mega", "Teguh", "Wulan", "Arif", "Desi",
    "Sugeng", "Tika",
]
LAST_NAMES = [
    "Santoso", "Rahayu", "Kurniawan", "Lestari", "Wijaya", "Susanto",
    "Pratama", "Wulandari", "Hidayat", "Permata", "Nugroho", "Setia",
    "Purnomo", "Handayani", "Saputra", "Maulana", "Fitriani", "Setiawan",
    "Utama", "Cahyani", "Firmansyah", "Anggraini", "Hartono", "Ningsih",
    "Gunawan", "Safitri", "Wahyudi", "Larasati", "Kusuma", "Astuti",
]

# Weighted verification_status distribution for ApplicantProfile
PROFILE_STATUS_WEIGHTS = [
    (ApplicantVerificationStatus.DRAFT, 20),
    (ApplicantVerificationStatus.SUBMITTED, 40),
    (ApplicantVerificationStatus.ACCEPTED, 25),
    (ApplicantVerificationStatus.REJECTED, 15),
]

# Expand into a weighted pool
_PROFILE_STATUS_POOL = [s for s, w in PROFILE_STATUS_WEIGHTS for _ in range(w)]


def _random_name():
    return f"{random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}"


def _random_phone():
    return f"08{random.randint(10_000_000, 99_999_999)}"


def _random_dob():
    # Age 21–45
    today = date.today()
    days_back = random.randint(21 * 365, 45 * 365)
    return today - timedelta(days=days_back)


class Command(BaseCommand):
    help = "Seed pelamar random (CustomUser + ApplicantProfile) tanpa lamaran lowongan kerja."

    def add_arguments(self, parser):
        parser.add_argument(
            "--count",
            type=int,
            default=100,
            help="Jumlah pelamar yang akan di-seed (default: 100).",
        )
        parser.add_argument(
            "--clear",
            action="store_true",
            help="Hapus semua pelamar seed (email *@seed.kms) sebelum membuat ulang.",
        )
        parser.add_argument(
            "--password",
            default="applicant@123!",
            help="Password untuk semua akun pelamar seed.",
        )

    def handle(self, *args, **options):
        count = options["count"]
        password = options["password"]

        # ── Clear ─────────────────────────────────────────────────────────
        if options["clear"]:
            deleted, _ = User.objects.filter(email__endswith="@seed.kms").delete()
            self.stdout.write(f"  Deleted {deleted} seed applicant users.\n")

        self.stdout.write(f"Seeding {count} pelamar (tanpa lamaran)…\n")
        now = timezone.now()
        created_count = 0
        skipped_count = 0

        for i in range(1, count + 1):
            email = f"applicant{i:03d}@seed.kms"

            # Skip if already exists
            if User.objects.filter(email=email).exists():
                skipped_count += 1
                continue

            full_name = _random_name()

            # ── User ──────────────────────────────────────────────────────
            user = User.objects.create(
                email=email,
                full_name=full_name,
                role=UserRole.APPLICANT,
                is_active=True,
                email_verified=True,
            )
            user.set_password(password)
            user.save(update_fields=["password"])

            # ── ApplicantProfile ──────────────────────────────────────────
            # NIK: unique=True, blank=False — generate a deterministic fake 16-digit value.
            fake_nik = f"3{i:015d}"

            # Randomise verification status and related timestamps
            verification_status = random.choice(_PROFILE_STATUS_POOL)
            submitted_at = None
            verified_at = None
            verification_notes = ""

            if verification_status in (
                ApplicantVerificationStatus.SUBMITTED,
                ApplicantVerificationStatus.ACCEPTED,
                ApplicantVerificationStatus.REJECTED,
            ):
                # Submitted sometime in the last 90 days
                submitted_at = now - timedelta(days=random.randint(1, 90))

            if verification_status in (
                ApplicantVerificationStatus.ACCEPTED,
                ApplicantVerificationStatus.REJECTED,
            ):
                # Verified 0–14 days after submission
                verified_at = submitted_at + timedelta(
                    days=random.randint(0, 14)
                ) if submitted_at else now

            if verification_status == ApplicantVerificationStatus.REJECTED:
                verification_notes = "Ditolak (data belum lengkap untuk verifikasi)."

            ApplicantProfile.objects.create(
                user=user,
                nik=fake_nik,
                registration_date=date.today(),
                birth_date=_random_dob(),
                contact_phone=_random_phone(),
                address=f"Jl. Contoh No. {i}, Jakarta",
                verification_status=verification_status,
                submitted_at=submitted_at,
                verified_at=verified_at,
                verification_notes=verification_notes,
            )

            created_count += 1
            self.stdout.write(
                f"  [{i:03d}] {full_name} → status profil: {verification_status}"
            )

        self.stdout.write(
            self.style.SUCCESS(
                f"\nDone. {created_count} pelamar dibuat, {skipped_count} dilewati."
            )
        )
