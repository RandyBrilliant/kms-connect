# Drop the actor FK so deleting a user does not UPDATE/DELETE append-only rows.

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("audit", "0002_postgres_immutable_trigger"),
    ]

    operations = [
        migrations.AlterField(
            model_name="auditevent",
            name="actor",
            field=models.ForeignKey(
                blank=True,
                db_constraint=False,
                null=True,
                on_delete=django.db.models.deletion.DO_NOTHING,
                related_name="audit_events",
                to=settings.AUTH_USER_MODEL,
                verbose_name="aktor",
            ),
        ),
    ]
