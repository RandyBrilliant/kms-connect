# Manual migration: free-text tempat lahir + backfill from legacy Regency FK.

from django.db import migrations, models


def forwards_backfill_and_clear_fk(apps, schema_editor):
    ApplicantProfile = apps.get_model("account", "ApplicantProfile")
    Regency = apps.get_model("regions", "Regency")

    for p in ApplicantProfile.objects.select_related("birth_place").iterator(chunk_size=500):
        updates = []
        if p.birth_place_id and not (p.birth_place_text or "").strip():
            try:
                r = Regency.objects.get(pk=p.birth_place_id)
                p.birth_place_text = (r.name or "").strip()
                updates.append("birth_place_text")
            except Regency.DoesNotExist:
                pass
        if p.birth_place_id:
            p.birth_place = None
            updates.append("birth_place")
        if updates:
            p.save(update_fields=updates)


def backwards_noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("account", "0015_alter_applicantprofile_gender_choices"),
    ]

    operations = [
        migrations.AddField(
            model_name="applicantprofile",
            name="birth_place_text",
            field=models.CharField(
                blank=True,
                help_text="Tempat lahir (teks bebas, biasanya huruf kapital seperti di KTP).",
                max_length=200,
                verbose_name="tempat lahir",
            ),
        ),
        migrations.AlterField(
            model_name="applicantprofile",
            name="birth_place",
            field=models.ForeignKey(
                blank=True,
                help_text="Legacy FK — diganti oleh birth_place_text. Dikosongkan setelah migrasi.",
                null=True,
                on_delete=models.SET_NULL,
                related_name="applicant_profiles_birth_place",
                to="regions.regency",
                verbose_name="tempat lahir (legacy)",
            ),
        ),
        migrations.RunPython(forwards_backfill_and_clear_fk, backwards_noop),
    ]
