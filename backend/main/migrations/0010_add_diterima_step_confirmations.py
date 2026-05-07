"""
Migration: add diterima_step_confirmations JSON field to JobApplication.

Stores per-step confirmation timestamps for the 9 document-collection steps
within the DITERIMA stage. Each step code maps to an ISO-8601 timestamp when
the applicant confirmed that step, or is absent when not yet confirmed.

Format: {"MEDICAL": "2026-05-01T10:00:00+07:00", "BUAT_ID_PEKERJA": "..."}

This is an additive-only migration: existing rows receive {} (empty dict) via
the DEFAULT clause — zero data loss, zero disruption to live applicants.
"""

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("main", "0009_add_cadangan_application_status"),
    ]

    operations = [
        migrations.AddField(
            model_name="jobapplication",
            name="diterima_step_confirmations",
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text=(
                    'Peta waktu konfirmasi pelamar per langkah pengumpulan dokumen di tahap Diterima. '
                    'Format: {"MEDICAL":"2026-05-01T10:00:00+07:00","BUAT_ID_PEKERJA":"..."}. '
                    'Langkah yang belum dikonfirmasi tidak muncul di sini.'
                ),
                verbose_name="konfirmasi per langkah tahap diterima",
            ),
        ),
    ]
