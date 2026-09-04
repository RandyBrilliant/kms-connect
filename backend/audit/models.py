"""
Append-only audit event log.

Rows are never updated or deleted via the ORM (manager + model.save)
or via PostgreSQL triggers in production.
"""
from __future__ import annotations

from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _


class AuditAction(models.TextChoices):
    LOGIN = "LOGIN", _("Login")
    LOGIN_FAILED = "LOGIN_FAILED", _("Login gagal")
    LOGOUT = "LOGOUT", _("Logout")
    CREATE = "CREATE", _("Buat")
    UPDATE = "UPDATE", _("Ubah")
    DELETE = "DELETE", _("Hapus")
    ACTIVATE = "ACTIVATE", _("Aktifkan")
    DEACTIVATE = "DEACTIVATE", _("Nonaktifkan")
    STATUS_CHANGE = "STATUS_CHANGE", _("Ubah status")
    EXPORT = "EXPORT", _("Ekspor")
    APPROVE = "APPROVE", _("Setujui")
    REJECT = "REJECT", _("Tolak")
    PASSWORD_CHANGE = "PASSWORD_CHANGE", _("Ubah password")
    PASSWORD_RESET = "PASSWORD_RESET", _("Reset password")


class AuditResourceType(models.TextChoices):
    AUTH = "auth", _("Autentikasi")
    USER = "user", _("Pengguna")
    APPLICANT = "applicant", _("Pelamar")
    COMPANY = "company", _("Perusahaan")
    STAFF = "staff", _("Staf")
    JOB = "job", _("Lowongan")
    BATCH = "batch", _("Batch")
    COHORT = "cohort", _("Sesi interview")
    APPLICATION = "application", _("Lamaran")
    NEWS = "news", _("Berita")
    BROADCAST = "broadcast", _("Broadcast")
    DOCUMENT = "document", _("Dokumen")
    DELETION_REQUEST = "deletion_request", _("Permintaan hapus akun")
    EXPORT = "export", _("Ekspor")


class AuditEventQuerySet(models.QuerySet):
    def update(self, **kwargs):
        raise PermissionError("AuditEvent rows are append-only and cannot be updated.")

    def delete(self):
        raise PermissionError("AuditEvent rows are append-only and cannot be deleted.")


class AuditEventManager(models.Manager.from_queryset(AuditEventQuerySet)):
    def bulk_update(self, *args, **kwargs):
        raise PermissionError("AuditEvent rows are append-only and cannot be updated.")

    def bulk_create(self, objs, **kwargs):
        # Allow bulk_create for testing / migration tooling only when explicitly needed.
        return super().bulk_create(objs, **kwargs)


class AuditEvent(models.Model):
    """
    Immutable activity event for Master Admin review.
    """

    created_at = models.DateTimeField(_("dibuat pada"), auto_now_add=True, db_index=True)

    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        # Append-only: deleting a user must not UPDATE/DELETE audit rows.
        # SET_NULL would rewrite actor_id; a real FK would also SET NULL / RESTRICT
        # at the database. Keep the historical id without a constraint.
        on_delete=models.DO_NOTHING,
        db_constraint=False,
        null=True,
        blank=True,
        related_name="audit_events",
        verbose_name=_("aktor"),
    )
    actor_email = models.CharField(_("email aktor"), max_length=254, blank=True, default="")
    actor_role = models.CharField(_("peran aktor"), max_length=32, blank=True, default="")
    actor_name = models.CharField(_("nama aktor"), max_length=255, blank=True, default="")

    action = models.CharField(
        _("aksi"),
        max_length=32,
        choices=AuditAction.choices,
        db_index=True,
    )
    resource_type = models.CharField(
        _("tipe resource"),
        max_length=32,
        choices=AuditResourceType.choices,
        db_index=True,
    )
    resource_id = models.CharField(_("id resource"), max_length=64, blank=True, default="")
    resource_label = models.CharField(
        _("label resource"),
        max_length=255,
        blank=True,
        default="",
    )
    summary = models.CharField(_("ringkasan"), max_length=512)

    ip_address = models.GenericIPAddressField(_("alamat IP"), null=True, blank=True)
    user_agent = models.CharField(_("user agent"), max_length=512, blank=True, default="")

    metadata = models.JSONField(_("metadata"), default=dict, blank=True)

    objects = AuditEventManager()

    class Meta:
        verbose_name = _("event audit")
        verbose_name_plural = _("event audit")
        ordering = ["-created_at", "-id"]
        indexes = [
            models.Index(fields=["-created_at", "-id"], name="audit_created_id_desc"),
            models.Index(fields=["action", "created_at"], name="audit_action_created"),
            models.Index(
                fields=["resource_type", "resource_id"],
                name="audit_resource_lookup",
            ),
            models.Index(fields=["actor", "created_at"], name="audit_actor_created"),
        ]

    def __str__(self) -> str:
        return f"{self.created_at} {self.action} {self.resource_type}:{self.resource_id}"

    def save(self, *args, **kwargs):
        if self.pk is not None:
            raise PermissionError("AuditEvent rows are append-only and cannot be updated.")
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        raise PermissionError("AuditEvent rows are append-only and cannot be deleted.")
