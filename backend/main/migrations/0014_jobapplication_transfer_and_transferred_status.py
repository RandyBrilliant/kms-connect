# Cross-job transfer: TRANSFERRED status + link fields

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("main", "0013_jobapplication_pra_seleksi_passed"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name="jobapplication",
            name="transfer_note",
            field=models.TextField(
                blank=True,
                help_text="Alasan atau keterangan admin saat memindahkan ke lowongan lain.",
                verbose_name="catatan transfer",
            ),
        ),
        migrations.AddField(
            model_name="jobapplication",
            name="transferred_at",
            field=models.DateTimeField(blank=True, null=True, verbose_name="dipindah pada"),
        ),
        migrations.AddField(
            model_name="jobapplication",
            name="transferred_by",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="application_transfers_made",
                to=settings.AUTH_USER_MODEL,
                verbose_name="dipindah oleh",
            ),
        ),
        migrations.AddField(
            model_name="jobapplication",
            name="transferred_from",
            field=models.ForeignKey(
                blank=True,
                help_text="Lamaran sumber jika record ini dibuat dari transfer lintas lowongan.",
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="transferred_successors",
                to="main.jobapplication",
                verbose_name="dipindah dari lamaran",
            ),
        ),
        migrations.AddField(
            model_name="jobapplication",
            name="transferred_to",
            field=models.ForeignKey(
                blank=True,
                help_text="Lamaran pengganti jika pelamar dipindah ke lowongan lain.",
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="transferred_predecessors",
                to="main.jobapplication",
                verbose_name="dipindah ke lamaran",
            ),
        ),
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
                    ("TRANSFERRED", "Tahap Dipindah"),
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
                    ("TRANSFERRED", "Tahap Dipindah"),
                    ("BERANGKAT", "Tahap Berangkat"),
                    ("SELESAI", "Tahap Selesai"),
                ],
                help_text="Status setelah perubahan.",
                max_length=15,
                verbose_name="ke status",
            ),
        ),
        migrations.AlterField(
            model_name="applicationstatushistory",
            name="from_status",
            field=models.CharField(
                blank=True,
                choices=[
                    ("PRA_SELEKSI", "Tahap Pra-Seleksi"),
                    ("INTERVIEW", "Tahap Interview"),
                    ("CADANGAN", "Tahap Cadangan"),
                    ("DITERIMA", "Tahap Diterima"),
                    ("DITOLAK", "Tahap Ditolak"),
                    ("TRANSFERRED", "Tahap Dipindah"),
                    ("BERANGKAT", "Tahap Berangkat"),
                    ("SELESAI", "Tahap Selesai"),
                ],
                help_text="Status sebelum perubahan. Kosong jika ini entri awal pembuatan.",
                max_length=15,
                verbose_name="dari status",
            ),
        ),
    ]
