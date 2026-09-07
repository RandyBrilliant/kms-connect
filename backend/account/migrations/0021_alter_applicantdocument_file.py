"""
Bind ApplicantDocument.file to private storage.

No-op at the database level: `storage` is a Python-level concern, so
sqlmigrate against PostgreSQL reports "(no-op)" and no DDL runs. The migration
exists only because `storage` is part of the field's deconstructed state, and
without it makemigrations would report the model as out of sync forever.
"""

import account.document_storage
import account.models
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("account", "0020_remove_masuk_berkas_inbound_transport_stage"),
    ]

    operations = [
        migrations.AlterField(
            model_name="applicantdocument",
            name="file",
            field=models.FileField(
                help_text="Berkas dokumen yang diunggah.",
                storage=account.document_storage.private_document_storage,
                upload_to=account.models.applicant_document_upload_to,
                verbose_name="berkas",
            ),
        ),
    ]
