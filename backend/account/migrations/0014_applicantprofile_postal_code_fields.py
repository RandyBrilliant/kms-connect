from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("account", "0013_alter_applicantprofile_destination_country"),
    ]

    operations = [
        migrations.AddField(
            model_name="applicantprofile",
            name="postal_code",
            field=models.CharField(
                blank=True,
                help_text="Kode pos alamat sesuai KTP.",
                max_length=20,
                verbose_name="kode pos",
            ),
        ),
        migrations.AddField(
            model_name="applicantprofile",
            name="family_postal_code",
            field=models.CharField(
                blank=True,
                help_text="Kode pos alamat orangtua/keluarga.",
                max_length=20,
                verbose_name="kode pos keluarga",
            ),
        ),
    ]
