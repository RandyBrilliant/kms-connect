import os

from django.core.files.base import ContentFile
from django.db import migrations


def copy_profile_photos_to_pas_foto(apps, schema_editor):
    """Keep leftover admin-uploaded profile photos as Pas Foto documents."""
    ApplicantProfile = apps.get_model("account", "ApplicantProfile")
    ApplicantDocument = apps.get_model("account", "ApplicantDocument")
    DocumentType = apps.get_model("account", "DocumentType")

    pas_foto_type, _ = DocumentType.objects.get_or_create(
        code="pas-foto",
        defaults={
            "name": "Pas Foto",
            "is_required": True,
            "sort_order": 6,
        },
    )
    existing_ids = set(
        ApplicantDocument.objects.filter(document_type=pas_foto_type).values_list(
            "applicant_profile_id",
            flat=True,
        )
    )
    qs = ApplicantProfile.objects.exclude(photo="").exclude(photo__isnull=True)
    for profile in qs.iterator():
        if profile.pk in existing_ids:
            continue
        field = profile.photo
        if not field or not getattr(field, "name", None):
            continue
        try:
            field.open("rb")
            data = field.read()
            field.close()
        except Exception:
            continue
        if not data:
            continue
        filename = os.path.basename(field.name) or "pasfoto.jpg"
        doc = ApplicantDocument(
            applicant_profile=profile,
            document_type=pas_foto_type,
        )
        doc.file.save(filename, ContentFile(data), save=True)


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("account", "0023_applicantprofile_education_school"),
    ]

    operations = [
        migrations.RunPython(copy_profile_photos_to_pas_foto, noop),
        migrations.RemoveField(
            model_name="applicantprofile",
            name="photo",
        ),
    ]
