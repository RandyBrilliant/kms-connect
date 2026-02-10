"""
Custom user manager for email-based authentication and role handling.
Uses role string literals to avoid circular import with models.
"""

from django.contrib.auth.models import BaseUserManager
from django.utils.translation import gettext_lazy as _


class CustomUserManager(BaseUserManager):
    """
    Manager where email is the unique identifier for authentication.
    Normalizes email (lowercase, strip) and enforces role for superuser.
    """

    def _normalize_email(self, email: str) -> str:
        return self.normalize_email(email).strip().lower() if email else ""

    def create_user(self, email: str, password: str | None = None, **extra_fields):
        """
        Create and save a user with the given email and password.
        Role should be provided; default to APPLICANT for registration flows.
        If password is None (e.g. OAuth), an unusable password is set.
        """
        if not email:
            raise ValueError(_("Alamat email wajib diisi."))
        email = self._normalize_email(email)
        extra_fields.setdefault("role", "APPLICANT")
        user = self.model(email=email, **extra_fields)
        if password is not None:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, email: str, password: str | None = None, **extra_fields):
        """
        Create and save a superuser with the given email and password.
        Forces role=ADMIN, is_staff=True, is_superuser=True.
        """
        extra_fields.setdefault("role", "ADMIN")
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)

        if extra_fields.get("is_staff") is not True:
            raise ValueError(_("Superuser harus is_staff=True."))
        if extra_fields.get("is_superuser") is not True:
            raise ValueError(_("Superuser harus is_superuser=True."))
        if extra_fields.get("role") != "ADMIN":
            raise ValueError(_("Superuser harus role=ADMIN."))
        return self.create_user(email, password, **extra_fields)
