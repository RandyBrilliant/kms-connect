# Generated manually for add full_name to CustomUser

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("account", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="customuser",
            name="full_name",
            field=models.CharField(
                blank=True,
                help_text="Nama lengkap pengguna (untuk Admin; peran lain dapat memakai profil).",
                max_length=255,
                verbose_name="nama lengkap",
            ),
        ),
    ]
