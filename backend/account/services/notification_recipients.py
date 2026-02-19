"""
Service for selecting notification recipients based on broadcast configuration.

Design goals:
- Pure functions for recipient selection (no DB writes here).
- Flexible recipient selection (by role, filters, specific users).
- Reusable logic that can be called from views or tasks.
- Follows the same patterns as scoring.py (services separation).
"""

from __future__ import annotations

from typing import Any, Iterable
from django.db.models import Q

from ..models import CustomUser, UserRole, ApplicantProfile, ApplicantVerificationStatus


def get_recipients_by_config(config: dict[str, Any]) -> Iterable[CustomUser]:
    """
    Get recipients based on broadcast configuration.
    
    Config format:
    {
        "selection_type": "all" | "roles" | "filters" | "users",
        "roles": ["ADMIN", "STAFF", ...],  # if selection_type is "roles"
        "user_ids": [1, 2, 3],  # if selection_type is "users"
        "filters": {  # if selection_type is "filters"
            "role": "APPLICANT",
            "is_active": true,
            "email_verified": true,
            "applicant_profile__verification_status": "ACCEPTED",
            ...
        }
    }
    
    Returns:
        QuerySet of CustomUser objects matching the criteria.
    """
    selection_type = config.get("selection_type", "all")
    
    queryset = CustomUser.objects.all()
    
    if selection_type == "all":
        # All active users
        queryset = queryset.filter(is_active=True)
    
    elif selection_type == "roles":
        # Filter by roles
        roles = config.get("roles", [])
        if roles:
            queryset = queryset.filter(role__in=roles, is_active=True)
        else:
            queryset = queryset.none()
    
    elif selection_type == "users":
        # Specific user IDs
        user_ids = config.get("user_ids", [])
        if user_ids:
            queryset = queryset.filter(id__in=user_ids, is_active=True)
        else:
            queryset = queryset.none()
    
    elif selection_type == "filters":
        # Advanced filtering (similar to applicant filters)
        filters = config.get("filters", {})
        if not filters:
            queryset = queryset.none()
        else:
            # Build Q objects for filtering
            q_objects = Q()
            
            if "role" in filters:
                q_objects &= Q(role=filters["role"])
            
            if "is_active" in filters:
                q_objects &= Q(is_active=filters["is_active"])
            
            if "email_verified" in filters:
                q_objects &= Q(email_verified=filters["email_verified"])
            
            # Applicant-specific filters
            if "applicant_profile__verification_status" in filters:
                q_objects &= Q(
                    applicant_profile__verification_status=filters["applicant_profile__verification_status"]
                )
            
            # Date range filters for applicants
            if "applicant_profile__created_at_after" in filters:
                q_objects &= Q(
                    applicant_profile__created_at__gte=filters["applicant_profile__created_at_after"]
                )
            
            if "applicant_profile__created_at_before" in filters:
                q_objects &= Q(
                    applicant_profile__created_at__lte=filters["applicant_profile__created_at_before"]
                )
            
            queryset = queryset.filter(q_objects, is_active=True)
    
    else:
        # Unknown selection type
        queryset = queryset.none()
    
    return queryset.distinct()


def get_recipient_count(config: dict[str, Any]) -> int:
    """
    Get count of recipients without fetching all objects.
    Useful for preview before sending.
    """
    return get_recipients_by_config(config).count()


def validate_recipient_config(config: dict[str, Any]) -> tuple[bool, str]:
    """
    Validate recipient configuration.
    
    Returns:
        (is_valid, error_message)
    """
    selection_type = config.get("selection_type")
    
    if not selection_type:
        return False, "selection_type wajib diisi."
    
    valid_types = ["all", "roles", "filters", "users"]
    if selection_type not in valid_types:
        return False, f"selection_type harus salah satu dari: {', '.join(valid_types)}"
    
    if selection_type == "roles":
        roles = config.get("roles", [])
        if not roles or not isinstance(roles, list):
            return False, "roles harus berupa array yang tidak kosong."
        # Validate role values
        valid_roles = [r[0] for r in UserRole.choices]
        invalid_roles = [r for r in roles if r not in valid_roles]
        if invalid_roles:
            return False, f"Role tidak valid: {', '.join(invalid_roles)}"
    
    elif selection_type == "users":
        user_ids = config.get("user_ids", [])
        if not user_ids or not isinstance(user_ids, list):
            return False, "user_ids harus berupa array yang tidak kosong."
        if not all(isinstance(uid, int) for uid in user_ids):
            return False, "Semua user_ids harus berupa angka."
    
    elif selection_type == "filters":
        filters = config.get("filters", {})
        if not filters or not isinstance(filters, dict):
            return False, "filters harus berupa object yang tidak kosong."
    
    return True, ""
