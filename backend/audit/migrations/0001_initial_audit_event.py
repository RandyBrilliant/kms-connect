# Generated manually for audit.AuditEvent

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="AuditEvent",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                (
                    "created_at",
                    models.DateTimeField(
                        auto_now_add=True, db_index=True, verbose_name="dibuat pada"
                    ),
                ),
                (
                    "actor_email",
                    models.CharField(
                        blank=True,
                        default="",
                        max_length=254,
                        verbose_name="email aktor",
                    ),
                ),
                (
                    "actor_role",
                    models.CharField(
                        blank=True,
                        default="",
                        max_length=32,
                        verbose_name="peran aktor",
                    ),
                ),
                (
                    "actor_name",
                    models.CharField(
                        blank=True,
                        default="",
                        max_length=255,
                        verbose_name="nama aktor",
                    ),
                ),
                (
                    "action",
                    models.CharField(
                        choices=[
                            ("LOGIN", "Login"),
                            ("LOGIN_FAILED", "Login gagal"),
                            ("LOGOUT", "Logout"),
                            ("CREATE", "Buat"),
                            ("UPDATE", "Ubah"),
                            ("DELETE", "Hapus"),
                            ("ACTIVATE", "Aktifkan"),
                            ("DEACTIVATE", "Nonaktifkan"),
                            ("STATUS_CHANGE", "Ubah status"),
                            ("EXPORT", "Ekspor"),
                            ("APPROVE", "Setujui"),
                            ("REJECT", "Tolak"),
                            ("PASSWORD_CHANGE", "Ubah password"),
                            ("PASSWORD_RESET", "Reset password"),
                        ],
                        db_index=True,
                        max_length=32,
                        verbose_name="aksi",
                    ),
                ),
                (
                    "resource_type",
                    models.CharField(
                        choices=[
                            ("auth", "Autentikasi"),
                            ("user", "Pengguna"),
                            ("applicant", "Pelamar"),
                            ("company", "Perusahaan"),
                            ("staff", "Staf"),
                            ("job", "Lowongan"),
                            ("batch", "Batch"),
                            ("cohort", "Sesi interview"),
                            ("application", "Lamaran"),
                            ("news", "Berita"),
                            ("broadcast", "Broadcast"),
                            ("document", "Dokumen"),
                            ("deletion_request", "Permintaan hapus akun"),
                            ("export", "Ekspor"),
                        ],
                        db_index=True,
                        max_length=32,
                        verbose_name="tipe resource",
                    ),
                ),
                (
                    "resource_id",
                    models.CharField(
                        blank=True,
                        default="",
                        max_length=64,
                        verbose_name="id resource",
                    ),
                ),
                (
                    "resource_label",
                    models.CharField(
                        blank=True,
                        default="",
                        max_length=255,
                        verbose_name="label resource",
                    ),
                ),
                (
                    "summary",
                    models.CharField(max_length=512, verbose_name="ringkasan"),
                ),
                (
                    "ip_address",
                    models.GenericIPAddressField(
                        blank=True, null=True, verbose_name="alamat IP"
                    ),
                ),
                (
                    "user_agent",
                    models.CharField(
                        blank=True,
                        default="",
                        max_length=512,
                        verbose_name="user agent",
                    ),
                ),
                (
                    "metadata",
                    models.JSONField(blank=True, default=dict, verbose_name="metadata"),
                ),
                (
                    "actor",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="audit_events",
                        to=settings.AUTH_USER_MODEL,
                        verbose_name="aktor",
                    ),
                ),
            ],
            options={
                "verbose_name": "event audit",
                "verbose_name_plural": "event audit",
                "ordering": ["-created_at", "-id"],
            },
        ),
        migrations.AddIndex(
            model_name="auditevent",
            index=models.Index(
                fields=["-created_at", "-id"], name="audit_created_id_desc"
            ),
        ),
        migrations.AddIndex(
            model_name="auditevent",
            index=models.Index(
                fields=["action", "created_at"], name="audit_action_created"
            ),
        ),
        migrations.AddIndex(
            model_name="auditevent",
            index=models.Index(
                fields=["resource_type", "resource_id"], name="audit_resource_lookup"
            ),
        ),
        migrations.AddIndex(
            model_name="auditevent",
            index=models.Index(
                fields=["actor", "created_at"], name="audit_actor_created"
            ),
        ),
    ]
