from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("account", "0022_applicantdocument_file_max_length"),
    ]

    operations = [
        migrations.AddField(
            model_name="applicantprofile",
            name="education_school",
            field=models.CharField(
                blank=True,
                help_text="Nama sekolah atau institusi pendidikan terakhir.",
                max_length=255,
                verbose_name="nama sekolah",
            ),
        ),
    ]
