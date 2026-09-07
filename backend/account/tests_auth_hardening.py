"""B2 (refresh-token blacklist) and B3 (no SECRET_KEY / DEBUG defaults)."""

from django.core.exceptions import ImproperlyConfigured
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient

from account.models import CustomUser, UserRole
from backend.settings import (
    COMMITTED_INSECURE_SECRET_KEY,
    debug_from_env,
    require_secret_key,
)


class SecretKeyAndDebugTests(TestCase):
    def test_missing_secret_key_is_rejected(self):
        with self.assertRaises(ImproperlyConfigured):
            require_secret_key("")
        with self.assertRaises(ImproperlyConfigured):
            require_secret_key(None)

    def test_committed_insecure_key_is_rejected(self):
        with self.assertRaises(ImproperlyConfigured):
            require_secret_key(COMMITTED_INSECURE_SECRET_KEY)

    def test_a_real_key_is_accepted(self):
        self.assertEqual(require_secret_key("  test-only-key  "), "test-only-key")

    def test_debug_defaults_off(self):
        self.assertFalse(debug_from_env(None))
        self.assertFalse(debug_from_env(""))
        self.assertFalse(debug_from_env("False"))
        self.assertFalse(debug_from_env("0"))

    def test_debug_opt_in(self):
        self.assertTrue(debug_from_env("True"))
        self.assertTrue(debug_from_env("1"))
        self.assertTrue(debug_from_env("yes"))


class RefreshTokenBlacklistTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = CustomUser.objects.create_user(
            email="pelamar.jwt@example.com",
            password="testpass123",
            role=UserRole.APPLICANT,
            full_name="Budi Token",
            is_active=True,
            email_verified=True,
        )

    def _login(self):
        response = self.client.post(
            reverse("token_obtain_pair"),
            {"email": self.user.email, "password": "testpass123"},
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        return response.json()["data"]

    def test_rotated_refresh_token_is_rejected(self):
        tokens = self._login()
        old_refresh = tokens["refresh"]

        first = self.client.post(
            reverse("token_refresh"),
            {"refresh": old_refresh},
            format="json",
        )
        self.assertEqual(first.status_code, 200)
        new_refresh = first.json()["data"]["refresh"]
        self.assertNotEqual(new_refresh, old_refresh)
        self.assertIn("user", first.json()["data"])

        replay_client = APIClient()
        replay = replay_client.post(
            reverse("token_refresh"),
            {"refresh": old_refresh},
            format="json",
        )
        self.assertEqual(replay.status_code, 401)

        still_valid = self.client.post(
            reverse("token_refresh"),
            {"refresh": new_refresh},
            format="json",
        )
        self.assertEqual(still_valid.status_code, 200)

    def test_logout_blacklists_the_refresh_token(self):
        tokens = self._login()
        refresh = tokens["refresh"]

        logout = self.client.post(
            reverse("auth_logout"),
            {"refresh": refresh},
            format="json",
        )
        self.assertEqual(logout.status_code, 200)

        replay = self.client.post(
            reverse("token_refresh"),
            {"refresh": refresh},
            format="json",
        )
        self.assertEqual(replay.status_code, 401)
