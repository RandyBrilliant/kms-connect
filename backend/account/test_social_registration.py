"""Google/Apple sign-in must not revive deactivated accounts or reuse another user's NIK."""

from unittest.mock import patch

from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from account.api_responses import ApiCode, ApiMessage
from account.models import ApplicantProfile, ApplicantVerificationStatus, CustomUser, UserRole


NIK = "3201010101010001"


def _make_applicant(*, email: str, nik: str, is_active: bool = True, **extra):
    user = CustomUser.objects.create_user(
        email=email,
        password="pass12345",
        role=UserRole.APPLICANT,
        is_active=is_active,
        email_verified=True,
        **extra,
    )
    ApplicantProfile.objects.create(
        user=user,
        nik=nik,
        verification_status=ApplicantVerificationStatus.SUBMITTED,
    )
    return user


@override_settings(
    GOOGLE_CLIENT_ID="test-google-client.apps.googleusercontent.com",
    APPLE_CLIENT_ID="id.kmsconnect.app",
    CACHES={"default": {"BACKEND": "django.core.cache.backends.dummy.DummyCache"}},
)
class SocialRegistrationIdentityTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_social_complete_rejects_nik_owned_by_active_user(self):
        _make_applicant(email="owner@example.com", nik=NIK)
        new_user = _make_applicant(email="newgoogle@example.com", nik="G000000000000001")
        self.client.force_authenticate(user=new_user)

        response = self.client.post("/api/auth/social-complete/", {"nik": NIK})

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data["code"], ApiCode.NIK_TAKEN)
        self.assertEqual(response.data["detail"], ApiMessage.NIK_TAKEN)
        new_user.applicant_profile.refresh_from_db()
        self.assertEqual(new_user.applicant_profile.nik, "G000000000000001")

    def test_social_complete_rejects_nik_owned_by_deactivated_user(self):
        _make_applicant(email="deleted@example.com", nik=NIK, is_active=False)
        new_user = _make_applicant(email="newapple@example.com", nik="A000000000000002")
        self.client.force_authenticate(user=new_user)

        response = self.client.post("/api/auth/social-complete/", {"nik": NIK})

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data["code"], ApiCode.NIK_TAKEN)
        self.assertEqual(response.data["detail"], ApiMessage.NIK_TAKEN)

    @patch("account.registration_views._verify_google_id_token")
    def test_google_oauth_rejects_deactivated_account(self, mock_verify):
        _make_applicant(
            email="gone@example.com",
            nik=NIK,
            is_active=False,
            google_id="google-sub-1",
        )
        mock_verify.return_value = {
            "sub": "google-sub-1",
            "email": "gone@example.com",
            "name": "Gone User",
        }

        response = self.client.post("/api/auth/google/", {"id_token": "fake-token"})

        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.data["code"], ApiCode.ACCOUNT_INACTIVE)
        self.assertEqual(CustomUser.objects.filter(email="gone@example.com").count(), 1)

    @patch("account.registration_views._verify_google_id_token")
    def test_google_oauth_rejects_deactivated_account_matched_by_email(self, mock_verify):
        user = _make_applicant(email="gone@example.com", nik=NIK, is_active=False)
        mock_verify.return_value = {
            "sub": "google-sub-new",
            "email": "gone@example.com",
            "name": "Gone User",
        }

        response = self.client.post("/api/auth/google/", {"id_token": "fake-token"})

        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.data["code"], ApiCode.ACCOUNT_INACTIVE)
        user.refresh_from_db()
        self.assertFalse(user.google_id)

    @patch("account.registration_views._verify_apple_identity_token")
    def test_apple_oauth_rejects_deactivated_account(self, mock_verify):
        _make_applicant(
            email="gone-apple@example.com",
            nik=NIK,
            is_active=False,
            apple_id="apple-sub-1",
        )
        mock_verify.return_value = {
            "sub": "apple-sub-1",
            "email": "gone-apple@example.com",
        }

        response = self.client.post(
            "/api/auth/apple/",
            {"identity_token": "fake-token"},
        )

        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.data["code"], ApiCode.ACCOUNT_INACTIVE)
        self.assertEqual(CustomUser.objects.filter(email="gone-apple@example.com").count(), 1)
