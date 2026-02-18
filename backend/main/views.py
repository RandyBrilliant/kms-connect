"""
API views untuk main app (admin-side CRUD untuk News dan LowonganKerja).
Public endpoints untuk pelamar: jobs dan news yang sudah dipublikasikan.
"""

from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from rest_framework.filters import SearchFilter, OrderingFilter

from account.permissions import IsBackofficeAdmin, IsApplicant
from account.api_responses import success_response, error_response, ApiCode

from .models import News, LowonganKerja, NewsStatus, JobStatus, JobApplication, ApplicationStatus
from .serializers import NewsSerializer, LowonganKerjaSerializer, JobApplicationSerializer


class NewsViewSet(viewsets.ModelViewSet):
    """
    CRUD berita untuk admin/backoffice.
    Tidak ada delete fisik di requirement awal; namun untuk konten berita,
    hard delete sering kali diperbolehkan. Jika ingin soft-delete, bisa
    diganti nanti dengan status ARCHIVED saja.
    """

    http_method_names = ["get", "post", "put", "patch", "delete", "head", "options"]
    serializer_class = NewsSerializer
    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["status", "is_pinned"]
    search_fields = ["title", "summary", "content"]
    ordering_fields = ["published_at", "created_at", "updated_at", "title"]
    ordering = ["-published_at", "-created_at"]

    def get_queryset(self):
        return News.objects.all()


class LowonganKerjaViewSet(viewsets.ModelViewSet):
    """
    CRUD lowongan kerja untuk admin/backoffice.
    Admin mengelola lowongan yang nantinya dapat dilihat publik/pelamar.
    """

    http_method_names = ["get", "post", "put", "patch", "delete", "head", "options"]
    serializer_class = LowonganKerjaSerializer
    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["status", "employment_type", "company", "location_country"]
    search_fields = ["title", "description", "requirements", "company__company_name"]
    ordering_fields = ["posted_at", "deadline", "created_at", "updated_at", "title"]
    ordering = ["-posted_at", "-created_at"]

    def get_queryset(self):
        return (
            LowonganKerja.objects.select_related("company", "created_by")
        )


# ---------------------------------------------------------------------------
# Public endpoints untuk pelamar (mobile app)
# ---------------------------------------------------------------------------


class PublicNewsListViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Public read-only list untuk berita yang sudah dipublikasikan.
    Hanya menampilkan berita dengan status PUBLISHED.
    """

    serializer_class = NewsSerializer
    permission_classes = [AllowAny]
    authentication_classes = ()  # Empty tuple disables authentication
    
    def get_authenticators(self):
        """Override to ensure no authentication is performed."""
        return []
    
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["is_pinned"]
    search_fields = ["title", "summary"]
    ordering_fields = ["published_at", "created_at"]
    ordering = ["-is_pinned", "-published_at", "-created_at"]

    def get_queryset(self):
        return News.objects.filter(status=NewsStatus.PUBLISHED).select_related("created_by")


class PublicJobsListViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Public read-only list untuk lowongan kerja yang sudah dibuka (OPEN).
    Hanya menampilkan lowongan dengan status OPEN.
    """

    serializer_class = LowonganKerjaSerializer
    permission_classes = [AllowAny]
    authentication_classes = ()  # Empty tuple disables authentication
    
    def get_authenticators(self):
        """Override to ensure no authentication is performed."""
        return []
    
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["employment_type", "company", "location_country"]
    search_fields = ["title", "description", "requirements", "company__company_name"]
    ordering_fields = ["posted_at", "deadline", "created_at"]
    ordering = ["-posted_at", "-created_at"]

    def get_queryset(self):
        return (
            LowonganKerja.objects.filter(status=JobStatus.OPEN)
            .select_related("company", "created_by")
        )


# ---------------------------------------------------------------------------
# Job Application endpoints
# ---------------------------------------------------------------------------


class JobApplicationViewSet(viewsets.ModelViewSet):
    """
    CRUD untuk lamaran kerja.
    Admin: dapat melihat semua lamaran, update status, review.
    Applicant: dapat melihat lamaran sendiri, apply untuk job.
    """

    serializer_class = JobApplicationSerializer
    permission_classes = [IsBackofficeAdmin]  # Default: admin only
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["status", "job", "applicant"]
    search_fields = ["applicant__user__full_name", "applicant__user__email", "job__title"]
    ordering_fields = ["applied_at", "reviewed_at", "status"]
    ordering = ["-applied_at"]

    def get_queryset(self):
        return (
            JobApplication.objects.select_related(
                "applicant", "applicant__user", "job", "job__company", "reviewed_by"
            )
        )


class ApplicantJobApplicationViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Self-service untuk pelamar melihat lamaran mereka sendiri.
    GET /api/applicants/me/applications/ - List own applications
    GET /api/applicants/me/applications/:id/ - Get application details
    """

    serializer_class = JobApplicationSerializer
    permission_classes = [IsApplicant]
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ["status"]
    ordering_fields = ["applied_at", "status"]
    ordering = ["-applied_at"]

    def get_queryset(self):
        """Return applications untuk current user."""
        if not self.request.user.is_authenticated:
            return JobApplication.objects.none()
        try:
            applicant_profile = self.request.user.applicant_profile
        except:
            return JobApplication.objects.none()
        return (
            JobApplication.objects.filter(applicant=applicant_profile)
            .select_related("job", "job__company", "reviewed_by")
        )


class ApplyForJobView(APIView):
    """
    Endpoint untuk pelamar melamar pekerjaan.
    POST /api/jobs/:id/apply/ - Apply for a job
    """

    permission_classes = [IsApplicant]

    def post(self, request, pk=None):
        from django.utils import timezone

        # Get job
        try:
            job = LowonganKerja.objects.get(pk=pk, status=JobStatus.OPEN)
        except LowonganKerja.DoesNotExist:
            return Response(
                error_response(
                    detail="Lowongan kerja tidak ditemukan atau sudah ditutup.",
                    code=ApiCode.NOT_FOUND,
                ),
                status=status.HTTP_404_NOT_FOUND,
            )

        # Get applicant profile
        try:
            applicant_profile = request.user.applicant_profile
        except:
            return Response(
                error_response(
                    detail="Profil pelamar tidak ditemukan.",
                    code=ApiCode.NOT_FOUND,
                ),
                status=status.HTTP_404_NOT_FOUND,
            )

        # Cek apakah sudah pernah melamar
        if JobApplication.objects.filter(applicant=applicant_profile, job=job).exists():
            return Response(
                error_response(
                    detail="Anda sudah melamar pekerjaan ini sebelumnya.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Buat lamaran
        application = JobApplication.objects.create(
            applicant=applicant_profile,
            job=job,
            status=ApplicationStatus.APPLIED,
            applied_at=timezone.now(),
        )

        serializer = JobApplicationSerializer(instance=application, context={"request": request})
        return Response(
            success_response(
                data=serializer.data,
                detail="Lamaran berhasil dikirim.",
            ),
            status=status.HTTP_201_CREATED,
        )

