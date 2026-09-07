"""Widen ApplicantDocument.file so keys are not truncated at 100 chars."""

import account.document_storage
import account.models
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("account", "0021_alter_applicantdocument_file"),
    ]

    operations = [
        migrations.AlterField(
            model_name="applicantdocument",
            name="file",
            field=models.FileField(
                help_text="Berkas dokumen yang diunggah.",
                max_length=255,
                storage=account.document_storage.private_document_storage,
                upload_to=account.models.applicant_document_upload_to,
                verbose_name="berkas",
            ),
        ),
    ]
