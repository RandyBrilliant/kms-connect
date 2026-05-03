# Generated manually: restrict jenis kelamin to Laki-laki / Perempuan only.

from django.db import migrations, models


def clear_legacy_other_gender(apps, schema_editor):
    ApplicantProfile = apps.get_model("account", "ApplicantProfile")
    ApplicantProfile.objects.filter(gender="O").update(gender="")


class Migration(migrations.Migration):

    dependencies = [
        ("account", "0014_applicantprofile_postal_code_fields"),
    ]

    operations = [
        migrations.RunPython(clear_legacy_other_gender, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="applicantprofile",
            name="gender",
            field=models.CharField(
                blank=True,
                choices=[("M", "Laki-laki"), ("F", "Perempuan")],
                max_length=1,
                verbose_name="jenis kelamin",
            ),
        ),
    ]
