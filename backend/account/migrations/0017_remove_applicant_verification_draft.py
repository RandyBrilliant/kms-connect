# Data: promote DRAFT → SUBMITTED, ensure submitted_at set for new CHECK constraint.

from django.db import migrations, models
from django.db.models import F, Q


def forwards_migrate_applicant_verification(apps, schema_editor):
    ApplicantProfile = apps.get_model("account", "ApplicantProfile")
    from django.utils import timezone

    now = timezone.now()
    ApplicantProfile.objects.filter(submitted_at__isnull=True).update(
        submitted_at=F("created_at")
    )
    ApplicantProfile.objects.filter(submitted_at__isnull=True).update(submitted_at=now)
    ApplicantProfile.objects.filter(verification_status="DRAFT").update(
        verification_status="SUBMITTED",
    )


def noop_reverse(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("account", "0016_applicantprofile_birth_place_text"),
    ]

    operations = [
        migrations.RunPython(forwards_migrate_applicant_verification, noop_reverse),
        migrations.RemoveConstraint(
            model_name="applicantprofile",
            name="submitted_at_required_after_draft",
        ),
        migrations.AddConstraint(
            model_name="applicantprofile",
            constraint=models.CheckConstraint(
                condition=Q(submitted_at__isnull=False),
                name="applicant_profile_submitted_at_required",
            ),
        ),
        migrations.AlterField(
            model_name="applicantprofile",
            name="verification_status",
            field=models.CharField(
                choices=[
                    ("SUBMITTED", "Dikirim"),
                    ("ACCEPTED", "Diterima"),
                    ("REJECTED", "Ditolak"),
                ],
                db_index=True,
                default="SUBMITTED",
                help_text="Dikirim: menunggu admin. Diterima/Ditolak: setelah verifikasi.",
                max_length=9,
                verbose_name="status verifikasi",
            ),
        ),
    ]
