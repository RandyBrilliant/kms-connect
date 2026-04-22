from django.db import migrations, models
from django.conf import settings


class Migration(migrations.Migration):

    dependencies = [
        ("account", "0011_remove_applicantprofile_zero_cost_understood"),
    ]

    operations = [
        migrations.AlterField(
            model_name="applicantprofile",
            name="referrer",
            field=models.ForeignKey(
                blank=True,
                help_text="Staf yang merujuk pelamar ini.",
                limit_choices_to={"role": "STAFF"},
                null=True,
                on_delete=models.deletion.SET_NULL,
                related_name="referred_applicants",
                to=settings.AUTH_USER_MODEL,
                verbose_name="perujuk",
            ),
        ),
    ]
