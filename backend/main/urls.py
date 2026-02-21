"""
Main app API URLs.
Admin-side CRUD:
- News
- LowonganKerja
- JobApplication
Public endpoints (untuk mobile app):
- Public news (published only)
- Public jobs (OPEN status only)
Applicant self-service:
- Apply for job
- My applications
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

app_name = "main"

router = DefaultRouter()
router.register(r"news", views.NewsViewSet, basename="news")
router.register(r"jobs", views.LowonganKerjaViewSet, basename="job")
router.register(r"applications", views.JobApplicationViewSet, basename="job-application")
# Public endpoints untuk mobile app
router.register(r"news/public", views.PublicNewsListViewSet, basename="news-public")
router.register(r"jobs/public", views.PublicJobsListViewSet, basename="jobs-public")
# Applicant self-service
router.register(
    r"applicants/me/applications",
    views.ApplicantJobApplicationViewSet,
    basename="applicant-me-applications",
)
# Company self-service
router.register(
    r"companies/me/jobs",
    views.CompanyJobListingsViewSet,
    basename="company-me-jobs",
)
router.register(
    r"companies/me/applicants",
    views.CompanyApplicantsViewSet,
    basename="company-me-applicants",
)
router.register(
    r"companies/me/applications",
    views.CompanyJobApplicationsViewSet,
    basename="company-me-applications",
)
# Staff self-service
router.register(
    r"staff/me/jobs",
    views.StaffJobListingsViewSet,
    basename="staff-me-jobs",
)
router.register(
    r"staff/me/applicants",
    views.StaffReferredApplicantsViewSet,
    basename="staff-me-applicants",
)

urlpatterns = [
    path("jobs/<int:pk>/apply/", views.ApplyForJobView.as_view(), name="apply-for-job"),
    path("companies/me/dashboard-stats/", views.CompanyDashboardStatsView.as_view(), name="company-dashboard-stats"),
    path("staff/me/dashboard-stats/", views.StaffDashboardStatsView.as_view(), name="staff-dashboard-stats"),
    path("", include(router.urls)),
]

