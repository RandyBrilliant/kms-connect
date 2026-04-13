# Generated manually for BatchAnnouncement.recipient_config

from django.db import migrations, models

import main.models


class Migration(migrations.Migration):

    dependencies = [
        ("main", "0004_alter_lowongankerja_company_optional"),
    ]

    operations = [
        migrations.AddField(
            model_name="batchannouncement",
            name="recipient_config",
            field=models.JSONField(
                default=main.models.default_batch_announcement_recipient_config,
                help_text=(
                    'Siapa yang menerima notifikasi & melihat pengumuman, mis. '
                    '{"selection_type": "all_active"} atau '
                    '{"selection_type": "statuses", "statuses": ["PRA_SELEKSI"]}.'
                ),
                verbose_name="konfigurasi penerima",
            ),
        ),
    ]
