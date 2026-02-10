"""
Permissions for account API.
Hanya role Admin yang boleh mengelola data admin/staff/company dari backoffice.
"""
from rest_framework import permissions

from .models import UserRole
from .api_responses import ApiMessage


class IsBackofficeAdmin(permissions.BasePermission):
    """
    Hanya pengguna dengan role ADMIN (atau superuser) yang boleh akses.
    Dipakai untuk endpoint CRUD admin, staff, dan company.
    """

    message = ApiMessage.PERMISSION_DENIED

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.is_superuser or request.user.role == UserRole.ADMIN


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
