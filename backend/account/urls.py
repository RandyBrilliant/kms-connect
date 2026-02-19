"""
Account API URLs.
Admin-side CRUD: Admin, Staff, Company (endpoint terpisah per role).
Nested: work_experiences dan documents di bawah applicants.
Self-service endpoints untuk pelamar: /api/applicants/me/
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views
from . import applicant_self_service_views

app_name = "account"

router = DefaultRouter()
router.register(r"admins", views.AdminUserViewSet, basename="admin-user")
router.register(r"staff", views.StaffUserViewSet, basename="staff-user")
router.register(r"companies", views.CompanyUserViewSet, basename="company-user")
router.register(r"applicants", views.ApplicantUserViewSet, basename="applicant-user")
router.register(r"applicant-profiles", views.ApplicantProfileViewSet, basename="applicant-profile")
router.register(r"document-types", views.DocumentTypeViewSet, basename="document-type")

# Referrers list for dropdown (before router)
referrer_paths = [
    path("referrers/", views.ReferrerListView.as_view(), name="referrer-list"),
]

# Admin: send verification & password reset email (before router)
admin_email_paths = [
    path(
        "admins/send-verification-email/",
        views.SendVerificationEmailView.as_view(),
        name="admin-send-verification-email",
    ),
    path(
        "admins/send-password-reset/",
        views.SendPasswordResetEmailView.as_view(),
        name="admin-send-password-reset",
    ),
]

# Nested under applicant (must be before router so more specific paths match first)
nested_applicant = [
    path(
        "applicants/<int:applicant_pk>/work_experiences/",
        views.WorkExperienceViewSet.as_view({"get": "list", "post": "create"}),
        name="applicant-work-experiences",
    ),
    path(
        "applicants/<int:applicant_pk>/work_experiences/<int:pk>/",
        views.WorkExperienceViewSet.as_view(
            {"get": "retrieve", "put": "update", "patch": "partial_update", "delete": "destroy"}
        ),
        name="applicant-work-experience-detail",
    ),
    path(
        "applicants/<int:applicant_pk>/documents/",
        views.ApplicantDocumentViewSet.as_view({"get": "list", "post": "create"}),
        name="applicant-documents",
    ),
    path(
        "applicants/<int:applicant_pk>/documents/<int:pk>/",
        views.ApplicantDocumentViewSet.as_view(
            {"get": "retrieve", "put": "update", "patch": "partial_update", "delete": "destroy"}
        ),
        name="applicant-document-detail",
    ),
]

# Public document types (cached; for mobile/applicant upload checklist). Must be before router.
public_document_types = [
    path(
        "document-types/public/",
        views.DocumentTypePublicListView.as_view(),
        name="document-types-public",
    ),
]

# Applicant self-service endpoints (must be before router for /me/ paths)
applicant_self_service_router = DefaultRouter()
applicant_self_service_router.register(
    r"applicants/me/profile",
    applicant_self_service_views.ApplicantProfileSelfServiceViewSet,
    basename="applicant-me-profile",
)
applicant_self_service_router.register(
    r"applicants/me/work_experiences",
    applicant_self_service_views.ApplicantWorkExperienceSelfServiceViewSet,
    basename="applicant-me-work-experiences",
)
applicant_self_service_router.register(
    r"applicants/me/documents",
    applicant_self_service_views.ApplicantDocumentSelfServiceViewSet,
    basename="applicant-me-documents",
)

# Admin dashboard (applicants overview)
dashboard_paths = [
    path(
        "dashboard/applicants/summary/",
        views.AdminApplicantDashboardSummaryView.as_view(),
        name="dashboard-applicants-summary",
    ),
    path(
        "dashboard/applicants/timeseries/",
        views.AdminApplicantDashboardTimeseriesView.as_view(),
        name="dashboard-applicants-timeseries",
    ),
    path(
        "dashboard/applicants/latest/",
        views.AdminApplicantDashboardLatestView.as_view(),
        name="dashboard-applicants-latest",
    ),
]

urlpatterns = [
    path("me/", views.MeView.as_view(), name="me"),
    path("", include(public_document_types)),
    path("", include(dashboard_paths)),
    path("", include(referrer_paths)),
    path("", include(admin_email_paths)),
    path("", include(applicant_self_service_router.urls)),  # Self-service endpoints
    path("", include(nested_applicant)),
    path("", include(router.urls)),
]
