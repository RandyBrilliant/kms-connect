"""
Seed perusahaan (CompanyProfile + CustomUser).
Idempoten: update_or_create by email, so safe to run multiple times.

Usage:
    python manage.py seed_companies
    python manage.py seed_companies --password=custom123
"""
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand

from account.models import CompanyProfile, UserRole

User = get_user_model()

# ---------------------------------------------------------------------------
# Data: (email, full_name, company_name, contact_phone, address)
# ---------------------------------------------------------------------------
COMPANIES = [
    {
        "email": "pt.manpower.sejahtera@example.com",
        "full_name": "Admin PT Manpower Sejahtera",
        "company_name": "PT Manpower Sejahtera Indonesia",
        "contact_phone": "+62218654321",
        "address": "Jl. Sudirman No. 45, Jakarta Pusat, DKI Jakarta 10220",
    },
    {
        "email": "global.wira.recruitment@example.com",
        "full_name": "Admin Global Wira Recruitment",
        "company_name": "Global Wira Recruitment Sdn. Bhd.",
        "contact_phone": "+60321234567",
        "address": "Level 8, Menara Wira, Jalan Ampang, 50450 Kuala Lumpur, Malaysia",
    },
    {
        "email": "asia.pacific.staffing@example.com",
        "full_name": "Admin Asia Pacific Staffing",
        "company_name": "Asia Pacific Staffing Co., Ltd.",
        "contact_phone": "+886227654321",
        "address": "10F, No. 88, Zhongxiao East Rd, Sec. 4, Xinyi District, Taipei 106, Taiwan",
    },
    {
        "email": "hongkong.helpers.agency@example.com",
        "full_name": "Admin HK Domestic Agency",
        "company_name": "Hong Kong Domestic Workers Agency Ltd.",
        "contact_phone": "+85225678901",
        "address": "Suite 12A, Far East Finance Centre, 16 Harcourt Road, Admiralty, Hong Kong",
    },
    {
        "email": "middle.east.placement@example.com",
        "full_name": "Admin Middle East Placement",
        "company_name": "Al-Jawad Middle East Placement Services",
        "contact_phone": "+966114567890",
        "address": "King Fahad Road, Al-Olaya District, Riyadh 12371, Saudi Arabia",
    },
    {
        "email": "korindo.labor.corp@example.com",
        "full_name": "Admin Korindo Labor Corp",
        "company_name": "Korindo Labor Corporation",
        "contact_phone": "+8225123456",
        "address": "14F, 23 Teheran-ro 4-gil, Gangnam-gu, Seoul 06232, South Korea",
    },
]


class Command(BaseCommand):
    help = "Seed company users + profiles (idempoten via update_or_create)."

    def add_arguments(self, parser):
        parser.add_argument(
            "--password",
            default="company@123!",
            help="Password default untuk semua akun perusahaan (default: company@123!).",
        )

    def handle(self, *args, **options):
        password = options["password"]
        self.stdout.write("Seeding companies…\n")

        for data in COMPANIES:
            email = data["email"]

            # ── Create / update CustomUser ────────────────────────────────
            user, user_created = User.objects.update_or_create(
                email=email,
                defaults={
                    "full_name": data["full_name"],
                    "role": UserRole.COMPANY,
                    "is_active": True,
                    "email_verified": True,
                },
            )
            if user_created or not user.has_usable_password():
                user.set_password(password)
                user.save(update_fields=["password"])

            action = "Created" if user_created else "Updated"
            self.stdout.write(f"  {action} user: {email}")

            # ── Create / update CompanyProfile ────────────────────────────
            profile, prof_created = CompanyProfile.objects.update_or_create(
                user=user,
                defaults={
                    "company_name": data["company_name"],
                    "contact_phone": data["contact_phone"],
                    "address": data["address"],
                },
            )
            p_action = "Created" if prof_created else "Updated"
            self.stdout.write(f"    {p_action} profile: {profile.company_name}")

        count = len(COMPANIES)
        self.stdout.write(
            self.style.SUCCESS(f"\nDone. {count} companies seeded. Password: {password}")
        )
