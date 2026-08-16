# PostgreSQL append-only enforcement for audit_event.
# No-op on SQLite / other backends used in local development.

from django.db import migrations


POSTGRES_FORWARD = """
CREATE OR REPLACE FUNCTION audit_event_immutable()
RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'audit_event is append-only';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS audit_event_no_update ON audit_auditevent;
DROP TRIGGER IF EXISTS audit_event_no_delete ON audit_auditevent;

CREATE TRIGGER audit_event_no_update
  BEFORE UPDATE ON audit_auditevent
  FOR EACH ROW
  EXECUTE PROCEDURE audit_event_immutable();

CREATE TRIGGER audit_event_no_delete
  BEFORE DELETE ON audit_auditevent
  FOR EACH ROW
  EXECUTE PROCEDURE audit_event_immutable();
"""

POSTGRES_REVERSE = """
DROP TRIGGER IF EXISTS audit_event_no_update ON audit_auditevent;
DROP TRIGGER IF EXISTS audit_event_no_delete ON audit_auditevent;
DROP FUNCTION IF EXISTS audit_event_immutable();
"""


def apply_postgres_triggers(apps, schema_editor):
    if schema_editor.connection.vendor != "postgresql":
        return
    with schema_editor.connection.cursor() as cursor:
        cursor.execute(POSTGRES_FORWARD)


def reverse_postgres_triggers(apps, schema_editor):
    if schema_editor.connection.vendor != "postgresql":
        return
    with schema_editor.connection.cursor() as cursor:
        cursor.execute(POSTGRES_REVERSE)


class Migration(migrations.Migration):

    dependencies = [
        ("audit", "0001_initial_audit_event"),
    ]

    operations = [
        migrations.RunPython(apply_postgres_triggers, reverse_postgres_triggers),
    ]
