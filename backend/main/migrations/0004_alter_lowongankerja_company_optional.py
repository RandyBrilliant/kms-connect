from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("main", "0003_ensure_batchannouncement_table"),
    ]

    operations = [
        migrations.AlterField(
            model_name="lowongankerja",
            name="company",
            field=models.ForeignKey(
                blank=True,
                help_text="Perusahaan yang membuka lowongan (opsional).",
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name="job_listings",
                to="account.companyprofile",
                verbose_name="perusahaan",
            ),
        ),
    ]
