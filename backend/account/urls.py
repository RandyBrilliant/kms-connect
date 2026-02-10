"""
Account API URLs.
Admin-side CRUD: Admin, Staff, Company (endpoint terpisah per role).
Nested: work_experiences dan documents di bawah applicants.
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

app_name = "account"

router = DefaultRouter()
router.register(r"admins", views.AdminUserViewSet, basename="admin-user")
router.register(r"staff", views.StaffUserViewSet, basename="staff-user")
router.register(r"companies", views.CompanyUserViewSet, basename="company-user")
router.register(r"applicants", views.ApplicantUserViewSet, basename="applicant-user")
router.register(r"document-types", views.DocumentTypeViewSet, basename="document-type")

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

urlpatterns = [
    path("me/", views.MeView.as_view(), name="me"),
    path("", include(public_document_types)),
    path("", include(admin_email_paths)),
    path("", include(nested_applicant)),
    path("", include(router.urls)),
]
