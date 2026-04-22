from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("main", "0005_batchannouncement_recipient_config"),
    ]

    operations = [
        migrations.AddField(
            model_name="jobapplication",
            name="attendance_by_stage",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text='Peta waktu kehadiran per tahap. Format: {"PRA_SELEKSI":"2026-01-01T10:00:00+07:00","INTERVIEW":"..."}',
                verbose_name="kehadiran per tahap",
            ),
        ),
    ]
