"""
Repair migration: create main_batchannouncement if it is missing.

Some databases recorded main.0001_initial as applied before BatchAnnouncement
was part of that migration, or the table was dropped manually. Django then
expects the table (e.g. when deleting CustomUser and SET_NULL on created_by)
and raises UndefinedTable.
"""

from django.db import migrations


def forwards(apps, schema_editor):
    connection = schema_editor.connection
    BatchAnnouncement = apps.get_model("main", "BatchAnnouncement")
    table_name = BatchAnnouncement._meta.db_table

    with connection.cursor() as cursor:
        tables = set(connection.introspection.table_names(cursor))

    if table_name in tables:
        return

    schema_editor.create_model(BatchAnnouncement)


class Migration(migrations.Migration):

    dependencies = [
        ("main", "0002_alter_batchannouncement_created_by_and_more"),
    ]

    operations = [
        migrations.RunPython(forwards, migrations.RunPython.noop),
    ]
