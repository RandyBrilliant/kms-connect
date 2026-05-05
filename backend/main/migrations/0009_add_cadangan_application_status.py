# Generated manually — adds CADANGAN to ApplicationStatus choices.
# No schema change: the VARCHAR column already has max_length=15, which
# accommodates 'CADANGAN' (8 chars). Existing rows are unaffected.

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("main", "0008_backfill_interview_cohort"),
    ]

    operations = [
        migrations.AlterField(
            model_name="jobapplication",
            name="status",
            field=models.CharField(
                choices=[
                    ("PRA_SELEKSI", "Tahap Pra-Seleksi"),
                    ("INTERVIEW", "Tahap Interview"),
                    ("CADANGAN", "Tahap Cadangan"),
                    ("DITERIMA", "Tahap Diterima"),
                    ("DITOLAK", "Tahap Ditolak"),
                    ("BERANGKAT", "Tahap Berangkat"),
                    ("SELESAI", "Tahap Selesai"),
                ],
                db_index=True,
                default="PRA_SELEKSI",
                help_text="Status tahap lamaran saat ini.",
                max_length=15,
                verbose_name="status",
            ),
        ),
        migrations.AlterField(
            model_name="applicationstatushistory",
            name="to_status",
            field=models.CharField(
                choices=[
                    ("PRA_SELEKSI", "Tahap Pra-Seleksi"),
                    ("INTERVIEW", "Tahap Interview"),
                    ("CADANGAN", "Tahap Cadangan"),
                    ("DITERIMA", "Tahap Diterima"),
                    ("DITOLAK", "Tahap Ditolak"),
                    ("BERANGKAT", "Tahap Berangkat"),
                    ("SELESAI", "Tahap Selesai"),
                ],
                help_text="Status setelah perubahan.",
                max_length=15,
                verbose_name="ke status",
            ),
        ),
    ]
