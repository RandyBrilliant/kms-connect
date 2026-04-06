"""
Permissions for account API.
Master Admin mengelola admin/staff/company; Admin (operator) punya akses terbatas.
"""
from rest_framework import permissions

from .models import UserRole
from .api_responses import ApiMessage


def user_is_master_admin(user) -> bool:
    """Superuser atau Admin Utama (bukan operator Admin)."""
    if not user or not user.is_authenticated:
        return False
    return user.is_superuser or user.role == UserRole.MASTER_ADMIN


def user_is_any_dashboard_admin(user) -> bool:
    """Master admin atau Admin operator (bukan Staff)."""
    if not user or not user.is_authenticated:
        return False
    if user.is_superuser:
        return True
    return user.role in (UserRole.MASTER_ADMIN, UserRole.ADMIN)


class IsMasterAdmin(permissions.BasePermission):
    """
    Hanya Admin Utama atau superuser (untuk CRUD penuh perusahaan, lowongan master, dll.).
    """

    message = ApiMessage.PERMISSION_DENIED

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return user_is_master_admin(request.user)


class IsBackofficeAdmin(permissions.BasePermission):
    """
    Admin Utama atau Admin operator (atau superuser).
    Dipakai untuk endpoint yang boleh diakses kedua jenis admin dashboard.
    """

    message = ApiMessage.PERMISSION_DENIED

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.is_superuser:
            return True
        return request.user.role in (UserRole.MASTER_ADMIN, UserRole.ADMIN)


class IsStaff(permissions.BasePermission):
    """
    Hanya pengguna dengan role STAFF (atau superuser) yang boleh akses.
    Dipakai untuk endpoint CRUD staff.
    """

    message = ApiMessage.PERMISSION_DENIED

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.is_superuser or request.user.role == UserRole.STAFF


class IsCompany(permissions.BasePermission):
    """
    Hanya pengguna dengan role COMPANY (atau superuser) yang boleh akses.
    Dipakai untuk endpoint CRUD company.
    """

    message = ApiMessage.PERMISSION_DENIED

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.is_superuser or request.user.role == UserRole.COMPANY


class IsApplicant(permissions.BasePermission):
    """
    Hanya pengguna dengan role APPLICANT (atau superuser) yang boleh akses.
    Dipakai untuk endpoint CRUD applicant.
    """

    message = ApiMessage.PERMISSION_DENIED

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.is_superuser or request.user.role == UserRole.APPLICANT
