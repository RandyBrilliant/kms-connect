# Generated manually — pra-seleksi sub-status (diterima pra-seleksi)

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("main", "0012_alter_jobapplication_diterima_current_step"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name="jobapplication",
            name="pra_seleksi_passed",
            field=models.BooleanField(
                blank=True,
                db_index=True,
                help_text=(
                    "Sub-status pra-seleksi: null = belum dinilai admin, True = diterima "
                    "(siap dipindahkan ke interview). Jika ditolak, status lamaran "
                    "berubah ke DITOLAK — field ini tidak dipakai."
                ),
                null=True,
                verbose_name="lulus pra-seleksi",
            ),
        ),
        migrations.AddField(
            model_name="jobapplication",
            name="pra_seleksi_passed_at",
            field=models.DateTimeField(
                blank=True,
                help_text="Waktu admin menandai pelamar diterima pada tahap pra-seleksi.",
                null=True,
                verbose_name="diterima pra-seleksi pada",
            ),
        ),
        migrations.AddField(
            model_name="jobapplication",
            name="pra_seleksi_passed_by",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="pra_seleksi_passed_applications",
                to=settings.AUTH_USER_MODEL,
                verbose_name="diterima pra-seleksi oleh",
            ),
        ),
    ]
