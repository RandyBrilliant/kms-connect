"""
Tests for append-only audit log.
"""
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from rest_framework import status
from rest_framework.test import APIClient

from account.models import UserRole
from audit.models import AuditAction, AuditEvent, AuditResourceType
from audit.services import emit

User = get_user_model()

_LOCMEM_CACHE = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
        "LOCATION": "audit-tests",
    }
}


@override_settings(CACHES=_LOCMEM_CACHE)
class AuditEmitTests(TestCase):
    def test_emit_creates_event(self):
        user = User.objects.create_user(
            email="admin@example.com",
            password="testpass123",
            role=UserRole.MASTER_ADMIN,
            full_name="Admin Utama",
        )
        with self.captureOnCommitCallbacks(execute=True):
            emit(
                action=AuditAction.CREATE,
                resource_type=AuditResourceType.NEWS,
                resource_id=1,
                resource_label="Berita uji",
                summary="Membuat news Berita uji",
                actor=user,
            )
        self.assertEqual(AuditEvent.objects.count(), 1)
        event = AuditEvent.objects.get()
        self.assertEqual(event.action, AuditAction.CREATE)
        self.assertEqual(event.actor_email, "admin@example.com")
        self.assertEqual(event.actor_role, UserRole.MASTER_ADMIN)
        self.assertEqual(event.resource_label, "Berita uji")

    def test_emit_swallows_db_errors(self):
        with patch(
            "audit.models.AuditEvent.objects.create",
            side_effect=RuntimeError("db down"),
        ):
            with self.captureOnCommitCallbacks(execute=True):
                # Must not raise
                emit(
                    action=AuditAction.LOGIN,
                    resource_type=AuditResourceType.AUTH,
                    summary="should not crash",
                )
        self.assertEqual(AuditEvent.objects.count(), 0)

    def test_model_is_immutable(self):
        event = AuditEvent.objects.create(
            action=AuditAction.LOGIN,
            resource_type=AuditResourceType.AUTH,
            summary="login",
        )
        with self.assertRaises(PermissionError):
            event.summary = "changed"
            event.save()
        with self.assertRaises(PermissionError):
            event.delete()
        with self.assertRaises(PermissionError):
            AuditEvent.objects.filter(pk=event.pk).update(summary="x")
        with self.assertRaises(PermissionError):
            AuditEvent.objects.filter(pk=event.pk).delete()

    def test_deleting_actor_preserves_audit_events(self):
        user = User.objects.create_user(
            email="pelamar@example.com",
            password="testpass123",
            role=UserRole.APPLICANT,
            full_name="Pelamar Uji",
        )
        event = AuditEvent.objects.create(
            action=AuditAction.LOGIN,
            resource_type=AuditResourceType.AUTH,
            summary="login pelamar",
            actor=user,
            actor_email=user.email,
            actor_role=user.role,
            actor_name=user.full_name,
        )
        actor_id = user.id

        user.delete()

        event.refresh_from_db()
        self.assertEqual(event.actor_id, actor_id)
        self.assertEqual(event.actor_email, "pelamar@example.com")
        self.assertFalse(User.objects.filter(pk=actor_id).exists())


@override_settings(CACHES=_LOCMEM_CACHE)
class AuditAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.master = User.objects.create_user(
            email="master@example.com",
            password="testpass123",
            role=UserRole.MASTER_ADMIN,
            full_name="Master",
            is_active=True,
            email_verified=True,
        )
        self.operator = User.objects.create_user(
            email="operator@example.com",
            password="testpass123",
            role=UserRole.ADMIN,
            full_name="Operator",
            is_active=True,
            email_verified=True,
        )
        AuditEvent.objects.create(
            action=AuditAction.CREATE,
            resource_type=AuditResourceType.NEWS,
            summary="seed event",
            actor=self.master,
            actor_email=self.master.email,
            actor_role=self.master.role,
        )

    def test_master_admin_can_list(self):
        self.client.force_authenticate(user=self.master)
        res = self.client.get("/api/audit-events/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("results", res.data)
        self.assertGreaterEqual(len(res.data["results"]), 1)

    def test_operator_admin_forbidden(self):
        self.client.force_authenticate(user=self.operator)
        res = self.client.get("/api/audit-events/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_unauthenticated_unauthorized(self):
        res = self.client.get("/api/audit-events/")
        self.assertIn(
            res.status_code,
            (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN),
        )

    def test_writes_not_allowed(self):
        self.client.force_authenticate(user=self.master)
        event_id = AuditEvent.objects.first().pk
        for method in ("put", "patch", "delete", "post"):
            fn = getattr(self.client, method)
            url = (
                f"/api/audit-events/{event_id}/"
                if method != "post"
                else "/api/audit-events/"
            )
            res = fn(url, {}, format="json")
            self.assertIn(
                res.status_code,
                (
                    status.HTTP_405_METHOD_NOT_ALLOWED,
                    status.HTTP_403_FORBIDDEN,
                ),
                msg=f"{method} returned {res.status_code}",
            )

    def test_list_still_works_after_actor_deleted(self):
        self.client.force_authenticate(user=self.master)
        operator_id = self.operator.id
        AuditEvent.objects.create(
            action=AuditAction.LOGIN,
            resource_type=AuditResourceType.AUTH,
            summary="login operator",
            actor=self.operator,
            actor_email=self.operator.email,
            actor_role=self.operator.role,
        )
        self.operator.delete()

        res = self.client.get("/api/audit-events/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        matching = [
            row for row in res.data["results"] if row["summary"] == "login operator"
        ]
        self.assertEqual(len(matching), 1)
        self.assertEqual(matching[0]["actor"], operator_id)
        self.assertEqual(matching[0]["actor_email"], "operator@example.com")


@override_settings(CACHES=_LOCMEM_CACHE)
class ApplicantPermanentDeleteAuditTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.master = User.objects.create_user(
            email="master-delete@example.com",
            password="testpass123",
            role=UserRole.MASTER_ADMIN,
            full_name="Master",
            is_active=True,
            email_verified=True,
        )
        self.applicant = User.objects.create_user(
            email="hapus-pelamar@example.com",
            password="testpass123",
            role=UserRole.APPLICANT,
            full_name="Pelamar Hapus",
            is_active=True,
            email_verified=True,
        )
        AuditEvent.objects.create(
            action=AuditAction.LOGIN,
            resource_type=AuditResourceType.AUTH,
            summary="login pelamar sebelum hapus",
            actor=self.applicant,
            actor_email=self.applicant.email,
            actor_role=self.applicant.role,
            actor_name=self.applicant.full_name,
        )

    def test_permanent_delete_succeeds_when_applicant_has_audit_events(self):
        self.client.force_authenticate(user=self.master)
        applicant_id = self.applicant.id
        with self.captureOnCommitCallbacks(execute=True):
            res = self.client.post(
                f"/api/applicants/{applicant_id}/permanent-delete/"
            )
        self.assertEqual(
            res.status_code,
            status.HTTP_200_OK,
            msg=getattr(res, "data", res.content),
        )
        self.assertFalse(User.objects.filter(pk=applicant_id).exists())
        leftover = AuditEvent.objects.get(summary="login pelamar sebelum hapus")
        self.assertEqual(leftover.actor_id, applicant_id)


@override_settings(CACHES=_LOCMEM_CACHE)
class AuditLoginInstrumentationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            email="loginuser@example.com",
            password="CorrectHorseBattery",
            role=UserRole.MASTER_ADMIN,
            is_active=True,
            email_verified=True,
        )

    def test_login_success_creates_audit(self):
        before = AuditEvent.objects.filter(action=AuditAction.LOGIN).count()
        with self.captureOnCommitCallbacks(execute=True):
            res = self.client.post(
                "/api/auth/token/",
                {
                    "email": "loginuser@example.com",
                    "password": "CorrectHorseBattery",
                },
                format="json",
            )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(
            AuditEvent.objects.filter(action=AuditAction.LOGIN).count(),
            before + 1,
        )

    def test_login_failed_creates_audit(self):
        before = AuditEvent.objects.filter(action=AuditAction.LOGIN_FAILED).count()
        with self.captureOnCommitCallbacks(execute=True):
            res = self.client.post(
                "/api/auth/token/",
                {
                    "email": "loginuser@example.com",
                    "password": "wrong-password",
                },
                format="json",
            )
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertEqual(
            AuditEvent.objects.filter(action=AuditAction.LOGIN_FAILED).count(),
            before + 1,
        )


@override_settings(CACHES=_LOCMEM_CACHE)
class AuditMixinCreateTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.master = User.objects.create_user(
            email="newsadmin@example.com",
            password="testpass123",
            role=UserRole.MASTER_ADMIN,
            is_active=True,
            email_verified=True,
        )
        self.client.force_authenticate(user=self.master)

    def test_news_create_emits_audit_get_does_not(self):
        before = AuditEvent.objects.count()
        with self.captureOnCommitCallbacks(execute=True):
            create_res = self.client.post(
                "/api/news/",
                {
                    "title": "Judul Audit",
                    "slug": "judul-audit-test",
                    "summary": "Ringkas",
                    "content": "Isi berita cukup panjang untuk validasi.",
                    "status": "DRAFT",
                },
                format="json",
            )
        self.assertEqual(
            create_res.status_code,
            status.HTTP_201_CREATED,
            msg=getattr(create_res, "data", create_res.content),
        )
        self.assertEqual(
            AuditEvent.objects.filter(action=AuditAction.CREATE).count(),
            before + 1,
        )
        create_count = AuditEvent.objects.count()
        with self.captureOnCommitCallbacks(execute=True):
            list_res = self.client.get("/api/news/")
        self.assertEqual(list_res.status_code, status.HTTP_200_OK)
        self.assertEqual(AuditEvent.objects.count(), create_count)
