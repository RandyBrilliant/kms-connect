"""
Custom filtersets for account app.

Provides advanced filtering capabilities beyond basic filterset_fields,
such as date range filtering for applicant join dates.
"""
import django_filters
from django.db import models

from .models import CustomUser, ApplicantProfile, ApplicantVerificationStatus


class ApplicantUserFilterSet(django_filters.FilterSet):
    """
    Custom filterset for ApplicantUserViewSet.
    
    Supports:
    - Basic filters: is_active, email_verified, verification_status
    - Date range filter: applicant_profile__created_at (bergabung date)
    """
    
    # Date range filtering for bergabung (created_at)
    created_at_after = django_filters.DateFilter(
        field_name="applicant_profile__created_at",
        lookup_expr="gte",
        help_text="Filter applicants who joined on or after this date (YYYY-MM-DD).",
    )
    created_at_before = django_filters.DateFilter(
        field_name="applicant_profile__created_at",
        lookup_expr="lte",
        help_text="Filter applicants who joined on or before this date (YYYY-MM-DD).",
    )
    
    # Basic filters
    is_active = django_filters.BooleanFilter()
    email_verified = django_filters.BooleanFilter()
    verification_status = django_filters.ChoiceFilter(
        field_name="applicant_profile__verification_status",
        choices=ApplicantVerificationStatus.choices,
    )

    class Meta:
        model = CustomUser
        fields = [
            "is_active",
            "email_verified",
            "verification_status",
            "created_at_after",
            "created_at_before",
        ]
