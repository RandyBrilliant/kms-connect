"""
Custom filtersets for account app.

Provides advanced filtering capabilities beyond basic filterset_fields,
such as date range filtering for applicant join dates.
"""
from datetime import date, timedelta

import django_filters
from dateutil.relativedelta import relativedelta

from .models import CustomUser, ApplicantVerificationStatus, Gender, Religion


class ApplicantUserFilterSet(django_filters.FilterSet):
    """
    Custom filterset for ApplicantUserViewSet.
    
    Supports:
    - Basic filters: is_active, email_verified, verification_status, referrer (perujuk id)
    - Date range filter: applicant_profile__created_at (bergabung date)
    - Profile filters: gender, religion, age_min / age_max (from tanggal lahir)
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
    # Staff/admin pemberi rujukan (FK id on ApplicantProfile)
    referrer = django_filters.NumberFilter(
        field_name="applicant_profile__referrer",
        lookup_expr="exact",
        help_text="Filter pelamar by perujuk (CustomUser id — Staf/Admin).",
    )
    # True = pelamar tanpa staff rujukan (referrer NULL), mis. daftar mandiri.
    referrer_isnull = django_filters.BooleanFilter(
        field_name="applicant_profile__referrer",
        lookup_expr="isnull",
        help_text="True: hanya pelamar tanpa staff rujukan.",
    )

    gender = django_filters.ChoiceFilter(
        field_name="applicant_profile__gender",
        choices=Gender.choices,
        help_text="Filter by jenis kelamin (M/F).",
    )
    religion = django_filters.ChoiceFilter(
        field_name="applicant_profile__religion",
        choices=Religion.choices,
        help_text="Filter by agama.",
    )

    age_min = django_filters.NumberFilter(
        method="filter_age_min",
        help_text="Umur minimal (tahun), berdasarkan tanggal lahir.",
    )
    age_max = django_filters.NumberFilter(
        method="filter_age_max",
        help_text="Umur maksimal (tahun), berdasarkan tanggal lahir.",
    )

    def filter_age_min(self, queryset, name, value):
        """Pelamar berusia minimal ``value`` tahun (tanggal lahir terisi)."""
        if value is None:
            return queryset
        try:
            years = int(value)
        except (TypeError, ValueError):
            return queryset
        if years < 0:
            return queryset
        today = date.today()
        latest_birthday = today - relativedelta(years=years)
        return queryset.filter(
            applicant_profile__birth_date__isnull=False,
            applicant_profile__birth_date__lte=latest_birthday,
        )

    def filter_age_max(self, queryset, name, value):
        """Pelamar berusia maksimal ``value`` tahun (tanggal lahir terisi)."""
        if value is None:
            return queryset
        try:
            years = int(value)
        except (TypeError, ValueError):
            return queryset
        if years < 0:
            return queryset
        today = date.today()
        earliest_birthday = today - relativedelta(years=years + 1) + timedelta(days=1)
        return queryset.filter(
            applicant_profile__birth_date__isnull=False,
            applicant_profile__birth_date__gte=earliest_birthday,
        )

    class Meta:
        model = CustomUser
        fields = [
            "is_active",
            "email_verified",
            "verification_status",
            "referrer",
            "referrer_isnull",
            "created_at_after",
            "created_at_before",
            "gender",
            "religion",
            "age_min",
            "age_max",
        ]
