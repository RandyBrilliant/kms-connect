"""
API views untuk account (admin-side CRUD: Admin, Staff, Company).
Endpoint terpisah per role; partial update didukung; hanya deactivate (no hard delete).
Pesan dan response format konsisten via api_responses (frontend-friendly).
"""
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, AllowAny
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter

from django.conf import settings as django_settings
from django.core.cache import cache
from django.shortcuts import get_object_or_404
from urllib.parse import urlencode
from datetime import timedelta

from django.db.models import Count
from django.db.models.functions import TruncDate
from django.utils import timezone

from .models import (
    CustomUser,
    UserRole,
    ApplicantProfile,
    WorkExperience,
    ApplicantDocument,
    DocumentType,
    ApplicantVerificationStatus,
)
from .permissions import IsBackofficeAdmin, IsApplicant
from .throttles import AuthPublicRateThrottle
from .email_utils import (
    FRONTEND_URL,
    verification_link,
    send_verification_email,
    send_password_reset_email,
)
from .serializers import (
    AdminUserSerializer,
    StaffUserSerializer,
    CompanyUserSerializer,
    ApplicantUserSerializer,
    ApplicantProfileSerializer,
    ReferrerListSerializer,
    WorkExperienceSerializer,
    ApplicantDocumentSerializer,
    DocumentTypeSerializer,
)
from .api_responses import (
    ApiCode,
    ApiMessage,
    error_response,
    success_response,
)


# ---------------------------------------------------------------------------
# Current user profile (any role: view & edit own profile)
# ---------------------------------------------------------------------------

def _get_serializer_class_for_role(role):
    """Return the user serializer class for the given role (for /api/me/)."""
    return {
        UserRole.ADMIN: AdminUserSerializer,
        UserRole.STAFF: StaffUserSerializer,
        UserRole.COMPANY: CompanyUserSerializer,
        UserRole.APPLICANT: ApplicantUserSerializer,
    }.get(role, ApplicantUserSerializer)


class MeView(APIView):
    """
    Endpoint untuk setiap pengguna (semua role) melihat dan mengubah profil sendiri.
    GET: data user + profil sesuai role.
    PUT/PATCH: update profil sendiri (is_active, email_verified, verification fields read-only).
    """
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        return _get_serializer_class_for_role(self.request.user.role)

    def get_serializer(self, instance=None, data=None, partial=False):
        context = {"request": self.request, "is_own_profile": True}
        cls = self.get_serializer_class()
        if data is not None:
            return cls(instance=instance, data=data, partial=partial, context=context)
        return cls(instance=instance, context=context)

    def get(self, request):
        serializer = self.get_serializer(instance=request.user)
        return Response(
            success_response(data=serializer.data),
            status=status.HTTP_200_OK,
        )

    def put(self, request):
        serializer = self.get_serializer(instance=request.user, data=request.data, partial=False)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(
            success_response(
                data=serializer.data,
                detail=ApiMessage.PROFILE_UPDATED,
                code=ApiCode.PROFILE_UPDATED,
            ),
            status=status.HTTP_200_OK,
        )

    def patch(self, request):
        serializer = self.get_serializer(instance=request.user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(
            success_response(
                data=serializer.data,
                detail=ApiMessage.PROFILE_UPDATED,
                code=ApiCode.PROFILE_UPDATED,
            ),
            status=status.HTTP_200_OK,
        )


# ---------------------------------------------------------------------------
# Reusable: no-delete + deactivate/activate
# ---------------------------------------------------------------------------

def destroy_disallowed_response():
    """Response 405 untuk aksi delete; gunakan deactivate."""
    return Response(
        error_response(
            detail=ApiMessage.DELETE_NOT_ALLOWED,
            code=ApiCode.DELETE_NOT_ALLOWED,
            status_code=status.HTTP_405_METHOD_NOT_ALLOWED,
        ),
        status=status.HTTP_405_METHOD_NOT_ALLOWED,
    )


class DeactivateActivateMixin:
    """
    Mixin untuk ViewSet yang mengelola user: deactivate/activate (no hard delete).
    Asumsi: get_object() mengembalikan CustomUser (atau model dengan is_active).
    """

    @action(detail=True, methods=["post"], url_path="deactivate")
    def deactivate(self, request, pk=None):
        """Nonaktifkan akun (set is_active=False)."""
        user = self.get_object()
        if not user.is_active:
            return Response(
                error_response(
                    detail=ApiMessage.ALREADY_DEACTIVATED,
                    code=ApiCode.ALREADY_DEACTIVATED,
                    status_code=status.HTTP_400_BAD_REQUEST,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        user.is_active = False
        user.save(update_fields=["is_active"])
        serializer = self.get_serializer(user)
        return Response(
            success_response(
                data=serializer.data,
                detail=ApiMessage.DEACTIVATED,
                code=ApiCode.DEACTIVATED,
            ),
            status=status.HTTP_200_OK,
        )

    @action(detail=True, methods=["post"], url_path="activate")
    def activate(self, request, pk=None):
        """Aktifkan kembali akun (set is_active=True)."""
        user = self.get_object()
        if user.is_active:
            return Response(
                error_response(
                    detail=ApiMessage.ALREADY_ACTIVATED,
                    code=ApiCode.ALREADY_ACTIVATED,
                    status_code=status.HTTP_400_BAD_REQUEST,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        user.is_active = True
        user.save(update_fields=["is_active"])
        serializer = self.get_serializer(user)
        return Response(
            success_response(
                data=serializer.data,
                detail=ApiMessage.ACTIVATED,
                code=ApiCode.ACTIVATED,
            ),
            status=status.HTTP_200_OK,
        )


# ---------------------------------------------------------------------------
# ViewSets
# ---------------------------------------------------------------------------

class AdminUserViewSet(DeactivateActivateMixin, viewsets.ModelViewSet):
    """
    CRUD untuk pengguna Admin (CustomUser role=ADMIN).
    List, create, retrieve, update, partial_update. Tidak ada delete; gunakan deactivate.
    """

    http_method_names = ["get", "post", "put", "patch", "head", "options"]
    serializer_class = AdminUserSerializer
    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["is_active", "email_verified"]
    search_fields = ["email", "full_name"]  # full_name on CustomUser
    ordering_fields = ["email", "full_name", "date_joined", "updated_at"]
    ordering = ["email"]

    def get_queryset(self):
        return CustomUser.objects.filter(role=UserRole.ADMIN)

    def destroy(self, request, *args, **kwargs):
        return destroy_disallowed_response()


class StaffUserViewSet(DeactivateActivateMixin, viewsets.ModelViewSet):
    """
    CRUD untuk pengguna Staff (CustomUser + StaffProfile).
    List, create, retrieve, update, partial_update. Tidak ada delete; gunakan deactivate.
    """

    http_method_names = ["get", "post", "put", "patch", "head", "options"]
    serializer_class = StaffUserSerializer
    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["is_active", "email_verified"]
    search_fields = ["email", "staff_profile__user__full_name", "staff_profile__contact_phone"]
    ordering_fields = ["email", "date_joined", "updated_at", "staff_profile__user__full_name"]
    ordering = ["email"]

    def get_queryset(self):
        return (
            CustomUser.objects.filter(role=UserRole.STAFF)
            .select_related("staff_profile")
        )

    def destroy(self, request, *args, **kwargs):
        return destroy_disallowed_response()


class CompanyUserViewSet(DeactivateActivateMixin, viewsets.ModelViewSet):
    """
    CRUD untuk pengguna Perusahaan (CustomUser + CompanyProfile).
    List, create, retrieve, update, partial_update. Tidak ada delete; gunakan deactivate.
    """

    http_method_names = ["get", "post", "put", "patch", "head", "options"]
    serializer_class = CompanyUserSerializer
    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["is_active", "email_verified"]
    search_fields = [
        "email",
        "company_profile__company_name",
        "company_profile__contact_phone",
    ]
    ordering_fields = [
        "email",
        "date_joined",
        "updated_at",
        "company_profile__company_name",
    ]
    ordering = ["email"]

    def get_queryset(self):
        return (
            CustomUser.objects.filter(role=UserRole.COMPANY)
            .select_related("company_profile")
        )

    def destroy(self, request, *args, **kwargs):
        return destroy_disallowed_response()


class ApplicantUserViewSet(DeactivateActivateMixin, viewsets.ModelViewSet):
    """
    CRUD untuk pelamar (CustomUser + ApplicantProfile).
    Admin: list, create (backdoor), retrieve, update, partial_update. Review data pelamar.
    Tidak ada delete; gunakan deactivate/activate.
    """

    http_method_names = ["get", "post", "put", "patch", "head", "options"]
    serializer_class = ApplicantUserSerializer
    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["is_active", "email_verified", "applicant_profile__verification_status"]
    search_fields = [
        "email",
        "applicant_profile__user__full_name",
        "applicant_profile__nik",
        "applicant_profile__contact_phone",
    ]
    ordering_fields = [
        "email",
        "date_joined",
        "updated_at",
        "applicant_profile__user__full_name",
        "applicant_profile__verification_status",
        "applicant_profile__created_at",
    ]
    ordering = ["-applicant_profile__created_at"]

    def get_queryset(self):
        return (
            CustomUser.objects.filter(role=UserRole.APPLICANT)
            .select_related("applicant_profile__user")
            .select_related(
                "applicant_profile__province",
                "applicant_profile__district",
                "applicant_profile__referrer",
                "applicant_profile__verified_by",
            )
        )

    def destroy(self, request, *args, **kwargs):
        return destroy_disallowed_response()


# ---------------------------------------------------------------------------
# ApplicantProfile ViewSet (Admin approval/rejection workflow)
# ---------------------------------------------------------------------------

class ApplicantProfileViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Admin-only ViewSet untuk ApplicantProfile.
    Provides actions for approving/rejecting individual or bulk applicants.
    """

    permission_classes = [IsBackofficeAdmin]
    serializer_class = ApplicantProfileSerializer

    def get_queryset(self):
        return ApplicantProfile.objects.with_related()
    
    @action(detail=True, methods=["post"], url_path="approve")
    def approve(self, request, pk=None):
        """
        Approve single applicant profile.
        POST /api/applicant-profiles/{id}/approve/
        Body: { "notes": "Optional approval notes" }
        """
        profile = self.get_object()
        notes = request.data.get("notes", "")
        
        # Validate status
        if profile.verification_status != ApplicantVerificationStatus.SUBMITTED:
            return Response(
                error_response(
                    detail=f"Hanya pelamar dengan status SUBMITTED yang dapat disetujui. Status saat ini: {profile.verification_status}",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        # Use the model helper method
        try:
            profile.approve(verified_by=request.user, notes=notes)
            return Response(
                success_response(
                    data={
                        "id": profile.id,
                        "full_name": profile.user.full_name,
                        "verification_status": profile.verification_status,
                    },
                    detail="Pelamar berhasil disetujui.",
                    code=ApiCode.SUCCESS,
                ),
                status=status.HTTP_200_OK,
            )
        except Exception as e:
            from django.core.exceptions import ValidationError as DjangoValidationError
            if isinstance(e, DjangoValidationError):
                msg = getattr(e, "message_dict", None) or getattr(e, "messages", None) or str(e)
                return Response(
                    error_response(detail=str(msg), code=ApiCode.VALIDATION_ERROR),
                    status=status.HTTP_400_BAD_REQUEST,
                )
            return Response(
                error_response(
                    detail=f"Gagal menyetujui pelamar: {str(e)}",
                    code=ApiCode.SERVER_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    @action(detail=True, methods=["post"], url_path="reject")
    def reject(self, request, pk=None):
        """
        Reject single applicant profile.
        POST /api/applicant-profiles/{id}/reject/
        Body: { "notes": "Required rejection reason" }
        """
        profile = self.get_object()
        notes = request.data.get("notes", "")
        
        # Validate notes required for rejection
        if not notes or not notes.strip():
            return Response(
                error_response(
                    detail="Catatan penolakan wajib diisi.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        # Validate status
        if profile.verification_status != ApplicantVerificationStatus.SUBMITTED:
            return Response(
                error_response(
                    detail=f"Hanya pelamar dengan status SUBMITTED yang dapat ditolak. Status saat ini: {profile.verification_status}",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        # Use the model helper method
        try:
            profile.reject(verified_by=request.user, notes=notes)
            return Response(
                success_response(
                    data={
                        "id": profile.id,
                        "full_name": profile.user.full_name,
                        "verification_status": profile.verification_status,
                    },
                    detail="Pelamar berhasil ditolak.",
                    code=ApiCode.SUCCESS,
                ),
                status=status.HTTP_200_OK,
            )
        except Exception as e:
            from django.core.exceptions import ValidationError as DjangoValidationError
            if isinstance(e, DjangoValidationError):
                msg = getattr(e, "message_dict", None) or getattr(e, "messages", None) or str(e)
                return Response(
                    error_response(detail=str(msg), code=ApiCode.VALIDATION_ERROR),
                    status=status.HTTP_400_BAD_REQUEST,
                )
            return Response(
                error_response(
                    detail=f"Gagal menolak pelamar: {str(e)}",
                    code=ApiCode.SERVER_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    @action(detail=False, methods=["post"], url_path="bulk-approve")
    def bulk_approve(self, request):
        """
        Bulk approve applicant profiles.
        POST /api/applicant-profiles/bulk-approve/
        Body: { "profile_ids": [1, 2, 3], "notes": "Optional approval notes" }
        """
        profile_ids = request.data.get("profile_ids", [])
        notes = request.data.get("notes", "")
        
        # Validate input
        if not profile_ids or not isinstance(profile_ids, list):
            return Response(
                error_response(
                    detail="profile_ids harus berupa array yang tidak kosong.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        # Use the optimized bulk update from manager
        try:
            updated = ApplicantProfile.objects.bulk_update_status(
                profile_ids=profile_ids,
                status=ApplicantVerificationStatus.ACCEPTED,
                verified_by=request.user,
                notes=notes,
            )
            
            return Response(
                success_response(
                    data={"updated": updated},
                    detail=f"{updated} pelamar berhasil disetujui.",
                    code=ApiCode.SUCCESS,
                ),
                status=status.HTTP_200_OK,
            )
        except Exception as e:
            return Response(
                error_response(
                    detail=f"Gagal menyetujui pelamar: {str(e)}",
                    code=ApiCode.SERVER_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
    
    @action(detail=False, methods=["post"], url_path="bulk-reject")
    def bulk_reject(self, request):
        """
        Bulk reject applicant profiles.
        POST /api/applicant-profiles/bulk-reject/
        Body: { "profile_ids": [1, 2, 3], "notes": "Required rejection reason" }
        """
        profile_ids = request.data.get("profile_ids", [])
        notes = request.data.get("notes", "")
        
        # Validate input
        if not profile_ids or not isinstance(profile_ids, list):
            return Response(
                error_response(
                    detail="profile_ids harus berupa array yang tidak kosong.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        # Validate notes required for rejection
        if not notes or not notes.strip():
            return Response(
                error_response(
                    detail="Catatan penolakan wajib diisi.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        # Use the optimized bulk update from manager
        try:
            updated = ApplicantProfile.objects.bulk_update_status(
                profile_ids=profile_ids,
                status=ApplicantVerificationStatus.REJECTED,
                verified_by=request.user,
                notes=notes,
            )
            
            return Response(
                success_response(
                    data={"updated": updated},
                    detail=f"{updated} pelamar berhasil ditolak.",
                    code=ApiCode.SUCCESS,
                ),
                status=status.HTTP_200_OK,
            )
        except Exception as e:
            return Response(
                error_response(
                    detail=f"Gagal menolak pelamar: {str(e)}",
                    code=ApiCode.SERVER_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


# ---------------------------------------------------------------------------
# Admin: kirim email verifikasi & reset password (user_id di body)
# ---------------------------------------------------------------------------

def _admin_email_logo_url(request):
    """URL logo untuk email: LOGO_URL atau build dari request + static."""
    url = getattr(django_settings, "LOGO_URL", None) or ""
    if url:
        return url.strip()
    try:
        base = request.build_absolute_uri("/").rstrip("/")
        static = getattr(django_settings, "STATIC_URL", "static/").lstrip("/")
        return f"{base}/{static}image/logo.jpg"
    except Exception:
        return ""


class SendVerificationEmailView(APIView):
    """
    Admin only. POST { "user_id": <id> } → kirim email verifikasi ke user.
    """
    permission_classes = [IsBackofficeAdmin]

    def post(self, request):
        user_id = request.data.get("user_id")
        if user_id is None:
            return Response(
                error_response(
                    detail="user_id wajib diisi.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        user = CustomUser.objects.filter(pk=user_id).first()
        if not user:
            return Response(
                error_response(
                    detail=ApiMessage.NOT_FOUND,
                    code=ApiCode.NOT_FOUND,
                    status_code=status.HTTP_404_NOT_FOUND,
                ),
                status=status.HTTP_404_NOT_FOUND,
            )
        if user.email_verified:
            return Response(
                error_response(
                    detail=ApiMessage.EMAIL_ALREADY_VERIFIED,
                    code=ApiCode.EMAIL_ALREADY_VERIFIED,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        verify_token = verification_link(user)
        # Prefer frontend URL for a friendly verification page; fallback to API endpoint.
        if FRONTEND_URL:
            base = FRONTEND_URL.rstrip("/")
            verify_url = f"{base}/verify-email?token={verify_token}"
        else:
            verify_url = request.build_absolute_uri("/api/auth/verify-email/") + "?" + urlencode({"token": verify_token})
        logo_url = _admin_email_logo_url(request)
        send_verification_email(user, logo_url=logo_url, verify_url=verify_url)
        return Response(
            success_response(
                data={"user_id": user.pk, "email": user.email},
                detail=ApiMessage.EMAIL_SENT,
                code=ApiCode.EMAIL_SENT,
            ),
            status=status.HTTP_200_OK,
        )


class SendPasswordResetEmailView(APIView):
    """
    Admin only. POST { "user_id": <id> } → kirim email reset password ke user.
    """
    permission_classes = [IsBackofficeAdmin]

    def post(self, request):
        user_id = request.data.get("user_id")
        if user_id is None:
            return Response(
                error_response(
                    detail="user_id wajib diisi.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        user = CustomUser.objects.filter(pk=user_id).first()
        if not user:
            return Response(
                error_response(
                    detail=ApiMessage.NOT_FOUND,
                    code=ApiCode.NOT_FOUND,
                    status_code=status.HTTP_404_NOT_FOUND,
                ),
                status=status.HTTP_404_NOT_FOUND,
            )
        logo_url = _admin_email_logo_url(request)
        send_password_reset_email(user, logo_url=logo_url)
        return Response(
            success_response(
                data={"user_id": user.pk, "email": user.email},
                detail=ApiMessage.EMAIL_SENT,
                code=ApiCode.EMAIL_SENT,
            ),
            status=status.HTTP_200_OK,
        )


# ---------------------------------------------------------------------------
# Referrers (Staff + Admin for dropdown pemberi rujukan)
# ---------------------------------------------------------------------------

class ReferrerListView(APIView):
    """
    List Staff and Admin users for referrer dropdown.
    GET /api/referrers/ → [{ id, full_name, email, referral_code }, ...]
    """

    permission_classes = [IsBackofficeAdmin]

    def get(self, request):
        qs = (
            CustomUser.objects.filter(role__in=[UserRole.STAFF, UserRole.ADMIN])
            .order_by("full_name", "email")
        )
        serializer = ReferrerListSerializer(qs, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)


# DocumentType (read-only untuk dropdown / daftar tipe)
# ---------------------------------------------------------------------------

class DocumentTypeViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Daftar tipe dokumen (read-only). Untuk dropdown di admin/frontend.
    """

    queryset = DocumentType.objects.all().order_by("sort_order", "code")
    serializer_class = DocumentTypeSerializer
    permission_classes = [IsBackofficeAdmin]


class DocumentTypePublicListView(APIView):
    """
    Public read-only list of document types (for mobile/applicant upload checklist).
    Cached to reduce DB hits. GET only; no auth required.
    """

    permission_classes = [AllowAny]
    authentication_classes = ()  # Empty tuple disables authentication

    def get_authenticators(self):
        """Override to ensure no authentication is performed."""
        return []

    def get(self, request):
        cache_key = "document_types_public_list"
        timeout = getattr(django_settings, "DOCUMENT_TYPES_CACHE_TIMEOUT", 900)
        data = cache.get(cache_key)
        if data is None:
            qs = DocumentType.objects.all().order_by("sort_order", "code")
            serializer = DocumentTypeSerializer(qs, many=True)
            data = serializer.data
            cache.set(cache_key, data, timeout=timeout)
        return Response(
            success_response(data=data),
            status=status.HTTP_200_OK,
        )


# ---------------------------------------------------------------------------
# WorkExperience (nested under applicant)
# ---------------------------------------------------------------------------

class WorkExperienceViewSet(viewsets.ModelViewSet):
    """
    CRUD pengalaman kerja per pelamar.
    Nested: /api/applicants/<applicant_pk>/work_experiences/
    """

    serializer_class = WorkExperienceSerializer
    permission_classes = [IsBackofficeAdmin]

    def get_queryset(self):
        applicant_pk = self.kwargs.get("applicant_pk")
        if not applicant_pk:
            return WorkExperience.objects.none()
        return (
            WorkExperience.objects.filter(applicant_profile__user_id=applicant_pk)
            .select_related("applicant_profile__user")
            .order_by("sort_order", "-start_date")
        )

    def get_applicant_profile(self):
        applicant_pk = self.kwargs.get("applicant_pk")
        return get_object_or_404(ApplicantProfile, user_id=applicant_pk)

    def perform_create(self, serializer):
        serializer.save(applicant_profile=self.get_applicant_profile())


# ---------------------------------------------------------------------------
# ApplicantDocument (nested under applicant, file upload)
# ---------------------------------------------------------------------------

class ApplicantDocumentViewSet(viewsets.ModelViewSet):
    """
    CRUD dokumen pelamar (file upload). Nested: /api/applicants/<applicant_pk>/documents/
    """

    serializer_class = ApplicantDocumentSerializer
    permission_classes = [IsBackofficeAdmin]

    def get_queryset(self):
        applicant_pk = self.kwargs.get("applicant_pk")
        if not applicant_pk:
            return ApplicantDocument.objects.none()
        return (
            ApplicantDocument.objects.filter(applicant_profile__user_id=applicant_pk)
            .select_related("document_type", "reviewed_by")
            .order_by("document_type__sort_order")
        )

    def get_applicant_profile(self):
        applicant_pk = self.kwargs.get("applicant_pk")
        return get_object_or_404(ApplicantProfile, user_id=applicant_pk)

    def perform_create(self, serializer):
        serializer.save(applicant_profile=self.get_applicant_profile())


# ---------------------------------------------------------------------------
# Admin dashboard: applicant statistics & latest applicants
# ---------------------------------------------------------------------------


class AdminApplicantDashboardSummaryView(APIView):
    """
    Ringkasan statistik pelamar untuk dashboard Admin.

    - total_applicants: jumlah seluruh pelamar terdaftar
    - total_active_workers: pelamar dengan status verifikasi DITERIMA
    - total_inactive_workers: pelamar lain (belum diterima)
    - growth_rate_30d: persen pertumbuhan pendaftaran pelamar 30 hari terakhir
      dibanding 30 hari sebelumnya.
    """

    permission_classes = [IsBackofficeAdmin]

    def get(self, request):
        now = timezone.now()
        total_applicants = ApplicantProfile.objects.count()
        total_active_workers = ApplicantProfile.objects.filter(
            verification_status=ApplicantVerificationStatus.ACCEPTED
        ).count()
        total_inactive_workers = max(total_applicants - total_active_workers, 0)

        # Growth rate: 30 hari terakhir vs 30 hari sebelumnya
        current_start = now - timedelta(days=30)
        prev_start = now - timedelta(days=60)

        current_count = ApplicantProfile.objects.filter(created_at__gte=current_start).count()
        prev_count = ApplicantProfile.objects.filter(
            created_at__gte=prev_start, created_at__lt=current_start
        ).count()

        if prev_count == 0:
            growth_rate_30d = 100.0 if current_count > 0 else 0.0
        else:
            growth_rate_30d = ((current_count - prev_count) / prev_count) * 100.0

        data = {
            "total_applicants": total_applicants,
            "total_active_workers": total_active_workers,
            "total_inactive_workers": total_inactive_workers,
            "growth_rate_30d": round(growth_rate_30d, 2),
        }
        return Response(data, status=status.HTTP_200_OK)


class AdminApplicantDashboardTimeseriesView(APIView):
    """
    Time series pelamar baru per hari untuk 90 hari terakhir.
    Frontend dapat memfilter 90/30/7 hari dari data ini.
    """

    permission_classes = [IsBackofficeAdmin]

    def get(self, request):
        now = timezone.now()
        start = now - timedelta(days=90)
        qs = (
            ApplicantProfile.objects.filter(created_at__gte=start)
            .annotate(day=TruncDate("created_at"))
            .values("day")
            .order_by("day")
            .annotate(count=Count("id"))
        )
        data = [
            {"date": row["day"].isoformat(), "count": row["count"]}
            for row in qs
        ]
        return Response(data, status=status.HTTP_200_OK)


class AdminApplicantDashboardLatestView(APIView):
    """
    Top 10 pelamar terbaru (berdasarkan created_at ApplicantProfile).
    Dipakai untuk tabel di dashboard Admin.
    """

    permission_classes = [IsBackofficeAdmin]

    def get(self, request):
        profiles = (
            ApplicantProfile.objects.select_related("user")
            .order_by("-created_at")[:10]
        )
        data = [
            {
                "id": p.user_id,
                "full_name": p.user.full_name,
                "email": p.user.email if p.user_id else "",
                "verification_status": p.verification_status,
                "created_at": p.created_at,
            }
            for p in profiles
        ]
        return Response(data, status=status.HTTP_200_OK)
