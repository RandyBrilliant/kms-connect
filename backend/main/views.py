"""
API views untuk main app (admin-side CRUD untuk News dan LowonganKerja).
Public endpoints untuk pelamar: jobs dan news yang sudah dipublikasikan.
"""

from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.filters import SearchFilter, OrderingFilter

from account.permissions import IsBackofficeAdmin, IsApplicant, IsCompany, IsStaff
from account.api_responses import success_response, error_response, ApiCode
from account.models import ApplicantProfile

from .models import (
    ApplicationSource,
    ApplicationStatus,
    ApplicationStatusHistory,
    JobApplication,
    JobStatus,
    LowonganKerja,
    News,
    NewsStatus,
)
from .serializers import (
    ApplicationAssignSerializer,
    ApplicationTransitionSerializer,
    JobApplicationSerializer,
    LowonganKerjaSerializer,
    NewsSerializer,
)
from .services import ApplicationService, CooldownError, TransitionError


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
    authentication_classes = []  # No auth required for public endpoint
    pagination_class = None  # Return plain list — mobile parses raw array
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
    authentication_classes = []  # No auth required for public endpoint
    pagination_class = None  # Return plain list — mobile parses raw array
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
    CRUD + custom actions untuk lamaran kerja (admin/backoffice).

    Standard CRUD:
      GET    /api/applications/          — list all applications
      GET    /api/applications/{id}/     — application detail (includes status_history)
      PATCH  /api/applications/{id}/     — update notes field only (status via transition/)
      DELETE /api/applications/{id}/     — hard delete (use sparingly)

    Custom actions:
      POST  /api/applications/assign/            — admin assigns applicant to job
      PATCH /api/applications/{id}/transition/   — move to a new status (FSM enforced)
    """

    serializer_class = JobApplicationSerializer
    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["status", "source", "job", "applicant"]
    search_fields = ["applicant__user__full_name", "applicant__user__email", "job__title"]
    ordering_fields = ["applied_at", "reviewed_at", "status"]
    ordering = ["-applied_at"]

    def get_queryset(self):
        return (
            JobApplication.objects
            .select_related(
                "applicant", "applicant__user",
                "job", "job__company",
                "reviewed_by", "assigned_by",
            )
            .prefetch_related("status_history__changed_by")
        )

    @action(detail=False, methods=["post"], url_path="assign")
    def assign(self, request):
        """
        POST /api/applications/assign/
        Admin directly assigns an applicant to a job at OFFERED status.
        Body: { "job": <id>, "applicant": <id>, "note": "..." }
        """
        serializer = ApplicationAssignSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail="Data tidak valid.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        job = serializer.validated_data["job"]
        applicant_profile = serializer.validated_data["applicant"]
        note = serializer.validated_data.get("note", "")

        try:
            application = ApplicationService.admin_assign(
                job=job,
                applicant_profile=applicant_profile,
                assigned_by=request.user,
                note=note,
            )
        except CooldownError as e:
            return Response(
                error_response(
                    detail=str(e),
                    code=ApiCode.VALIDATION_ERROR,
                    errors={"eligible_date": str(e.eligible_date)},
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Re-fetch with full relations for response
        application.refresh_from_db()
        out = JobApplicationSerializer(
            self.get_queryset().get(pk=application.pk),
            context={"request": request},
        )
        return Response(
            success_response(data=out.data, detail="Pelamar berhasil ditugaskan."),
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=["patch"], url_path="transition")
    def transition(self, request, pk=None):
        """
        PATCH /api/applications/{id}/transition/
        Move an application to a new status (FSM enforced).
        Body: { "status": "OFFERED", "note": "...", "placement_end_date": "2026-02-27" }
        placement_end_date is only required when transitioning to COMPLETED.
        """
        application = self.get_object()

        serializer = ApplicationTransitionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail="Data tidak valid.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            ApplicationService.transition(
                application=application,
                new_status=serializer.validated_data["status"],
                actor=request.user,
                note=serializer.validated_data.get("note", ""),
                placement_end_date=serializer.validated_data.get("placement_end_date"),
            )
        except TransitionError as e:
            return Response(
                error_response(detail=str(e), code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Re-fetch with full relations (history just appended)
        out = JobApplicationSerializer(
            self.get_queryset().get(pk=application.pk),
            context={"request": request},
        )
        return Response(success_response(data=out.data, detail="Status lamaran diperbarui."))


class ApplicantJobApplicationViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Self-service untuk pelamar melihat lamaran mereka sendiri.
    GET /api/applicants/me/applications/     — list own applications
    GET /api/applicants/me/applications/:id/ — detail (includes status_history)
    """

    serializer_class = JobApplicationSerializer
    permission_classes = [IsApplicant]
    pagination_class = None  # Return plain list — mobile parses raw array
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ["status", "source"]
    ordering_fields = ["applied_at", "status"]
    ordering = ["-applied_at"]

    def get_queryset(self):
        if not self.request.user.is_authenticated:
            return JobApplication.objects.none()
        try:
            applicant_profile = self.request.user.applicant_profile
        except Exception:
            return JobApplication.objects.none()
        return (
            JobApplication.objects
            .filter(applicant=applicant_profile)
            .select_related("job", "job__company", "reviewed_by", "assigned_by")
            .prefetch_related("status_history__changed_by")
        )


class ApplyForJobView(APIView):
    """
    Endpoint untuk pelamar melamar pekerjaan.
    POST /api/jobs/:id/apply/

    Enforces via ApplicationService:
      - 2-year re-apply cooldown after COMPLETED placement.
      - No duplicate active application for (applicant, job).
      - Job must be OPEN.
    """

    permission_classes = [IsApplicant]

    def post(self, request, pk=None):
        # Validate job exists and is OPEN
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

        # Resolve applicant profile
        try:
            applicant_profile = request.user.applicant_profile
        except Exception:
            return Response(
                error_response(
                    detail="Profil pelamar tidak ditemukan.",
                    code=ApiCode.NOT_FOUND,
                ),
                status=status.HTTP_404_NOT_FOUND,
            )

        # Delegate to service layer (cooldown + duplicate check + create)
        try:
            application = ApplicationService.apply(
                job=job,
                applicant_profile=applicant_profile,
            )
        except CooldownError as e:
            return Response(
                error_response(
                    detail=str(e),
                    code=ApiCode.VALIDATION_ERROR,
                    errors={"eligible_date": str(e.eligible_date)},
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        except ValueError as e:
            return Response(
                error_response(detail=str(e), code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = JobApplicationSerializer(instance=application, context={"request": request})
        return Response(
            success_response(data=serializer.data, detail="Lamaran berhasil dikirim."),
            status=status.HTTP_201_CREATED,
        )


# ---------------------------------------------------------------------------
# Company self-service endpoints
# ---------------------------------------------------------------------------


class CompanyJobListingsViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Company dapat melihat lowongan kerja mereka sendiri (read-only).
    GET /api/companies/me/jobs/ - List own job listings
    GET /api/companies/me/jobs/:id/ - Get job details
    """

    serializer_class = LowonganKerjaSerializer
    permission_classes = [IsCompany]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["status", "employment_type", "location_country"]
    search_fields = ["title", "description", "requirements"]
    ordering_fields = ["posted_at", "deadline", "created_at", "updated_at", "title"]
    ordering = ["-posted_at", "-created_at"]

    def get_queryset(self):
        """Return job listings for the company's profile."""
        if not self.request.user.is_authenticated:
            return LowonganKerja.objects.none()
        try:
            company_profile = self.request.user.company_profile
        except:
            return LowonganKerja.objects.none()
        return (
            LowonganKerja.objects.filter(company=company_profile)
            .select_related("company", "created_by")
        )


class CompanyApplicantsViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Company dapat melihat pelamar yang melamar ke lowongan mereka (read-only).
    GET /api/companies/me/applicants/ - List applicants who applied to company's jobs
    GET /api/companies/me/applicants/:id/ - Get applicant details
    """

    from account.serializers import ApplicantUserSerializer
    serializer_class = ApplicantUserSerializer
    permission_classes = [IsCompany]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["is_active", "email_verified"]
    search_fields = ["email", "full_name", "applicant_profile__nik", "applicant_profile__contact_phone"]
    ordering_fields = ["email", "date_joined", "updated_at"]
    ordering = ["-date_joined"]

    def get_queryset(self):
        """Return applicants who applied to this company's job listings."""
        if not self.request.user.is_authenticated:
            from account.models import CustomUser
            return CustomUser.objects.none()
        try:
            company_profile = self.request.user.company_profile
        except:
            from account.models import CustomUser
            return CustomUser.objects.none()
        
        # Get unique applicants who applied to this company's jobs
        from account.models import CustomUser, UserRole
        applicant_ids = JobApplication.objects.filter(
            job__company=company_profile
        ).values_list('applicant__user_id', flat=True).distinct()
        
        return (
            CustomUser.objects.filter(
                id__in=applicant_ids,
                role=UserRole.APPLICANT
            )
            .select_related("applicant_profile")
            .prefetch_related(
                "applicant_profile__work_experiences",
                "applicant_profile__documents__document_type"
            )
        )


class CompanyJobApplicationsViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Company dapat melihat lamaran yang masuk ke lowongan mereka (read-only).
    GET /api/companies/me/applications/ - List applications to company's jobs
    GET /api/companies/me/applications/:id/ - Get application details
    """

    serializer_class = JobApplicationSerializer
    permission_classes = [IsCompany]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["status", "job"]
    search_fields = ["applicant__user__full_name", "applicant__user__email", "job__title"]
    ordering_fields = ["applied_at", "reviewed_at", "status"]
    ordering = ["-applied_at"]

    def get_queryset(self):
        """Return applications for this company's job listings."""
        if not self.request.user.is_authenticated:
            return JobApplication.objects.none()
        try:
            company_profile = self.request.user.company_profile
        except:
            return JobApplication.objects.none()
        return (
            JobApplication.objects.filter(job__company=company_profile)
            .select_related("applicant", "applicant__user", "job", "job__company", "reviewed_by", "assigned_by")
            .prefetch_related("status_history__changed_by")
        )


class CompanyDashboardStatsView(APIView):
    """
    Dashboard statistics untuk company.
    GET /api/companies/me/dashboard-stats/
    Returns:
    - total_jobs: total job listings
    - total_open_jobs: active job listings
    - total_applications: total applications received
    - total_applicants: unique applicants
    - recent_applications: 5 most recent applications
    """

    permission_classes = [IsCompany]

    def get(self, request):
        from django.db.models import Count, Q
        from django.utils import timezone
        
        try:
            company_profile = request.user.company_profile
        except:
            return Response(
                error_response(
                    detail="Profil perusahaan tidak ditemukan.",
                    code=ApiCode.NOT_FOUND,
                ),
                status=status.HTTP_404_NOT_FOUND,
            )

        # Count statistics
        total_jobs = LowonganKerja.objects.filter(company=company_profile).count()
        total_open_jobs = LowonganKerja.objects.filter(
            company=company_profile,
            status=JobStatus.OPEN
        ).count()
        
        applications_qs = JobApplication.objects.filter(job__company=company_profile)
        total_applications = applications_qs.count()
        total_applicants = applications_qs.values('applicant').distinct().count()
        
        # Status breakdown
        status_counts = applications_qs.values('status').annotate(
            count=Count('id')
        )
        status_breakdown = {item['status']: item['count'] for item in status_counts}
        
        # Recent applications
        recent_applications = applications_qs.select_related(
            'applicant', 'applicant__user', 'job'
        ).order_by('-applied_at')[:5]
        
        recent_apps_data = JobApplicationSerializer(
            recent_applications,
            many=True,
            context={"request": request}
        ).data

        data = {
            "total_jobs": total_jobs,
            "total_open_jobs": total_open_jobs,
            "total_applications": total_applications,
            "total_applicants": total_applicants,
            "status_breakdown": status_breakdown,
            "recent_applications": recent_apps_data,
        }

        return Response(
            success_response(
                data=data,
                detail="Dashboard data retrieved successfully.",
            ),
            status=status.HTTP_200_OK,
        )


# ---------------------------------------------------------------------------
# Staff self-service endpoints
# ---------------------------------------------------------------------------


class StaffJobListingsViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Staff dapat melihat semua lowongan kerja (read-only).
    GET /api/staff/me/jobs/ - List all job listings
    GET /api/staff/me/jobs/:id/ - Get job details
    """

    serializer_class = LowonganKerjaSerializer
    permission_classes = [IsStaff]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["status", "employment_type", "company", "location_country"]
    search_fields = ["title", "description", "requirements", "company__company_name"]
    ordering_fields = ["posted_at", "deadline", "created_at", "updated_at", "title"]
    ordering = ["-posted_at", "-created_at"]

    def get_queryset(self):
        """Return all job listings."""
        return (
            LowonganKerja.objects.select_related("company", "created_by")
        )


class StaffReferredApplicantsViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Staff dapat melihat pelamar yang mereka rujuk (read-only).
    GET /api/staff/me/applicants/ - List applicants referred by this staff
    GET /api/staff/me/applicants/:id/ - Get applicant details
    """

    from account.serializers import ApplicantUserSerializer
    serializer_class = ApplicantUserSerializer
    permission_classes = [IsStaff]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["is_active", "email_verified", "applicant_profile__verification_status"]
    search_fields = ["email", "full_name", "applicant_profile__nik", "applicant_profile__contact_phone"]
    ordering_fields = ["email", "date_joined", "updated_at"]
    ordering = ["-date_joined"]

    def get_queryset(self):
        """Return applicants referred by this staff member."""
        if not self.request.user.is_authenticated:
            from account.models import CustomUser
            return CustomUser.objects.none()
        
        from account.models import CustomUser, UserRole
        return (
            CustomUser.objects.filter(
                role=UserRole.APPLICANT,
                applicant_profile__referrer=self.request.user
            )
            .select_related("applicant_profile")
            .prefetch_related(
                "applicant_profile__work_experiences",
                "applicant_profile__documents__document_type"
            )
        )


class StaffDashboardStatsView(APIView):
    """
    Dashboard statistics untuk staff tentang pelamar yang mereka rujuk.
    GET /api/staff/me/dashboard-stats/
    Returns:
    - total_referred_applicants: total applicants referred by this staff
    - verification_status_breakdown: breakdown by verification status
    - recent_applicants: 5 most recent referred applicants
    - total_active: active applicants
    - total_accepted: accepted applicants
    """

    permission_classes = [IsStaff]

    def get(self, request):
        from django.db.models import Count, Q
        from account.models import CustomUser, UserRole, ApplicantVerificationStatus
        from account.serializers import ApplicantUserSerializer
        
        # Get applicants referred by this staff
        referred_applicants_qs = CustomUser.objects.filter(
            role=UserRole.APPLICANT,
            applicant_profile__referrer=request.user
        ).select_related("applicant_profile")

        total_referred = referred_applicants_qs.count()
        total_active = referred_applicants_qs.filter(is_active=True).count()
        
        # Verification status breakdown
        status_counts = referred_applicants_qs.values(
            'applicant_profile__verification_status'
        ).annotate(count=Count('id'))
        
        verification_breakdown = {
            item['applicant_profile__verification_status']: item['count'] 
            for item in status_counts if item['applicant_profile__verification_status']
        }
        
        total_accepted = referred_applicants_qs.filter(
            applicant_profile__verification_status=ApplicantVerificationStatus.ACCEPTED
        ).count()
        
        total_submitted = referred_applicants_qs.filter(
            applicant_profile__verification_status=ApplicantVerificationStatus.SUBMITTED
        ).count()
        
        # Recent applicants
        recent_applicants = referred_applicants_qs.order_by('-date_joined')[:5]
        recent_applicants_data = ApplicantUserSerializer(
            recent_applicants,
            many=True,
            context={"request": request}
        ).data

        data = {
            "total_referred_applicants": total_referred,
            "total_active": total_active,
            "total_accepted": total_accepted,
            "total_submitted": total_submitted,
            "verification_breakdown": verification_breakdown,
            "recent_applicants": recent_applicants_data,
        }

        return Response(
            success_response(
                data=data,
                detail="Dashboard data retrieved successfully.",
            ),
            status=status.HTTP_200_OK,
        )

