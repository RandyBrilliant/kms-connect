"""
API views untuk account (admin-side CRUD: Admin, Staff, Company).
Endpoint terpisah per role; partial update didukung; hanya deactivate (no hard delete).
Pesan dan response format konsisten via api_responses (frontend-friendly).
"""
import logging

from rest_framework import status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, AllowAny
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter
from .filters import ApplicantUserFilterSet

from django.conf import settings as django_settings
from django.core.cache import cache
from django.shortcuts import get_object_or_404
from django.http import HttpResponse
from datetime import timedelta, datetime

from django.db.models import Count, F, Q
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
    Broadcast,
    Notification,
    NotificationPreference,
    AccountDeletionRequest,
)
from .permissions import IsBackofficeAdmin, IsMasterAdmin, IsApplicant
from .throttles import AuthPublicRateThrottle
from .email_utils import (
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
    NotificationSerializer,
    BroadcastSerializer,
    NotificationPreferenceSerializer,
    AccountDeletionRequestSerializer,
)
from .api_responses import (
    ApiCode,
    ApiMessage,
    error_response,
    success_response,
)
from .services.export import generate_applicants_excel
from .services.biodata_pdf import generate_biodata_pdf
from .services.inbond_pdf import generate_inbond_pdf
from .services.notification_delivery import send_broadcast
from .services.notification_dispatcher import dispatch
from .services.notification_events import NotificationEvent
from .services.notification_recipients import get_recipient_count, validate_recipient_config
from .tasks import send_event_email_task

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Current user profile (any role: view & edit own profile)
# ---------------------------------------------------------------------------

def _get_serializer_class_for_role(role):
    """Return the user serializer class for the given role (for /api/me/)."""
    return {
        UserRole.MASTER_ADMIN: AdminUserSerializer,
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
# Notification Preferences (own preferences: GET + PATCH)
# ---------------------------------------------------------------------------

class NotificationPreferenceView(APIView):
    """
    Retrieve and update the current user's notification preferences.

    GET  /api/me/notification-preferences/  → returns own preferences
    PATCH /api/me/notification-preferences/ → partial update (any subset of fields)

    Auto-creates the preference record if it doesn't exist yet (idempotent).
    """

    permission_classes = [IsAuthenticated]

    def _get_or_create_pref(self, user):
        pref, _ = NotificationPreference.objects.get_or_create(user=user)
        return pref

    def get(self, request):
        pref = self._get_or_create_pref(request.user)
        serializer = NotificationPreferenceSerializer(pref)
        return Response(success_response(data=serializer.data))

    def patch(self, request):
        pref = self._get_or_create_pref(request.user)
        serializer = NotificationPreferenceSerializer(pref, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(success_response(data=serializer.data))
        return Response(
            error_response(
                ApiMessage.VALIDATION_ERROR,
                ApiCode.VALIDATION_ERROR,
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            ),
            status=status.HTTP_400_BAD_REQUEST,
        )


# ---------------------------------------------------------------------------
# ViewSets
# ---------------------------------------------------------------------------

class AdminUserViewSet(DeactivateActivateMixin, viewsets.ModelViewSet):
    """
    CRUD untuk pengguna Admin Utama / Admin (operator).
    List & retrieve: kedua jenis admin. Tulis & deactivate: hanya Admin Utama / superuser.
    """

    http_method_names = ["get", "post", "put", "patch", "head", "options"]
    serializer_class = AdminUserSerializer
    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["is_active", "email_verified"]
    search_fields = ["email", "full_name"]  # full_name on CustomUser
    ordering_fields = ["email", "full_name", "date_joined", "updated_at"]
    ordering = ["email"]

    def get_permissions(self):
        if self.action in ("list", "retrieve"):
            return [IsBackofficeAdmin()]
        return [IsMasterAdmin()]

    def get_queryset(self):
        return CustomUser.objects.filter(
            role__in=[UserRole.MASTER_ADMIN, UserRole.ADMIN]
        )

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

    def get_permissions(self):
        if self.action in ("list", "retrieve"):
            return [IsBackofficeAdmin()]
        return [IsMasterAdmin()]

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
    permission_classes = [IsMasterAdmin]
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
    filterset_class = ApplicantUserFilterSet
    search_fields = [
        "email",
        "full_name",
        "applicant_profile__nik",
        "applicant_profile__contact_phone",
    ]
    ordering_fields = [
        "email",
        "full_name",
        "date_joined",
        "updated_at",
        "applicant_profile__verification_status",
        "applicant_profile__created_at",
        "applicant_profile__score",
    ]
    ordering = ["-applicant_profile__created_at"]

    def get_permissions(self):
        if self.action in ("deactivate", "activate"):
            return [IsMasterAdmin()]
        return [IsBackofficeAdmin()]

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

    @action(detail=False, methods=["get"], url_path="export")
    def export(self, request):
        """
        Export applicants to Excel file.
        GET /api/applicants/export/?search=...&is_active=...&verification_status=...
        
        Supports the same filters as the list endpoint:
        - search: search in email, full_name, nik, contact_phone
        - is_active: filter by active status
        - email_verified: filter by email verification status
        - applicant_profile__verification_status: filter by verification status
        - ordering: sort order (default: -applicant_profile__created_at)
        
        Returns Excel file (.xlsx) with all matching applicants.
        """
        # Get filtered queryset using the same logic as list()
        queryset = self.filter_queryset(self.get_queryset())
        
        # Prefetch work experiences and documents for export
        queryset = queryset.prefetch_related(
            "applicant_profile__work_experiences",
            "applicant_profile__documents__document_type",
            "applicant_profile__documents__reviewed_by",
        )
        
        # Apply ordering
        ordering = request.query_params.get("ordering", self.ordering[0] if self.ordering else None)
        if ordering:
            queryset = queryset.order_by(*ordering.split(","))
        
        # Generate Excel file
        try:
            excel_file = generate_applicants_excel(queryset, request)
            
            # Generate filename with timestamp
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"pelamar_export_{timestamp}.xlsx"
            
            # Create HTTP response with Excel content
            response = HttpResponse(
                excel_file.read(),
                content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
            response["Content-Disposition"] = f'attachment; filename="{filename}"'
            
            return response
        except Exception as e:
            return Response(
                error_response(
                    detail=f"Gagal mengekspor data: {str(e)}",
                    code=ApiCode.SERVER_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    @action(detail=True, methods=["get"], url_path="download-documents")
    def download_documents(self, request, pk=None):
        """
        GET /api/applicants/{id}/download-documents/

        Returns a ZIP archive containing all uploaded documents for this applicant.
        The ZIP is structured as:

            <FullName>_<NIK>_<id>/
                ktp.jpg
                ijasah.pdf
                paspor.jpg
                ...

        Files that are physically missing from storage are silently skipped;
        a custom response header `X-Missing-Files` lists any skipped doc-type
        codes so the caller can surface a warning if needed.
        """
        import io
        import os
        import zipfile
        from django.core.files.storage import default_storage

        applicant = self.get_object()
        profile = getattr(applicant, "applicant_profile", None)

        if not profile:
            return Response(
                error_response(
                    detail="Profil pelamar tidak ditemukan.",
                    code=ApiCode.NOT_FOUND,
                ),
                status=status.HTTP_404_NOT_FOUND,
            )

        documents = (
            ApplicantDocument.objects
            .filter(applicant_profile=profile)
            .select_related("document_type")
            .order_by("document_type__sort_order", "document_type__code")
        )

        if not documents.exists():
            return Response(
                error_response(
                    detail="Pelamar belum memiliki dokumen yang diunggah.",
                    code=ApiCode.NOT_FOUND,
                ),
                status=status.HTTP_404_NOT_FOUND,
            )

        # Build a safe folder name: FullName_NIK_id
        full_name = (applicant.full_name or "pelamar").strip()
        nik = (profile.nik or "").strip()
        safe_name = "".join(
            c for c in full_name if c.isalnum() or c in (" ", "-", "_")
        ).strip().replace(" ", "_") or "pelamar"
        folder = f"{safe_name}_{nik}_{applicant.id}" if nik else f"{safe_name}_{applicant.id}"

        buffer = io.BytesIO()
        missing = []

        with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as zf:
            for doc in documents:
                try:
                    doc_type_code = (
                        doc.document_type.code if doc.document_type_id else "dokumen"
                    )
                    _, ext = os.path.splitext(doc.file.name)
                    arc_name = f"{folder}/{doc_type_code}{ext.lower() or '.bin'}"

                    with default_storage.open(doc.file.name, "rb") as fh:
                        zf.writestr(arc_name, fh.read())
                except Exception:
                    label = (
                        doc.document_type.code
                        if doc.document_type_id
                        else str(doc.pk)
                    )
                    missing.append(label)

        buffer.seek(0)

        zip_filename = (
            f"Dokumen_{safe_name}_{nik}.zip" if nik else f"Dokumen_{safe_name}.zip"
        )
        response = HttpResponse(buffer.read(), content_type="application/zip")
        response["Content-Disposition"] = f'attachment; filename="{zip_filename}"'
        response["Content-Transfer-Encoding"] = "binary"
        if missing:
            response["X-Missing-Files"] = ",".join(missing)
        return response


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
    Admin only. POST { "user_id": <id> } → kirim kode verifikasi email ke user.
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
        logo_url = _admin_email_logo_url(request)
        send_verification_email(user, logo_url=logo_url)
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
            CustomUser.objects.filter(
                role__in=[UserRole.STAFF, UserRole.MASTER_ADMIN, UserRole.ADMIN]
            )
            .order_by("full_name", "email")
        )
        serializer = ReferrerListSerializer(qs, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)


class PublicStaffReferrersView(APIView):
    """
    Public list of active staff/admin users for the referral staff picker
    shown during applicant registration (no auth required).

    GET /api/staff-referrers/
    Response: [{ id, full_name, referral_code }, ...]

    Cached for 5 minutes to minimise DB load — staff list rarely changes.
    """

    permission_classes = [AllowAny]
    authentication_classes = []  # skip auth entirely for speed

    _CACHE_KEY = "public_staff_referrers_v1"
    _CACHE_TTL = 300  # 5 minutes

    def get_authenticators(self):
        return []

    def get(self, request):
        data = cache.get(self._CACHE_KEY)
        if data is None:
            data = list(
                CustomUser.objects.filter(
                    role__in=[UserRole.STAFF, UserRole.MASTER_ADMIN, UserRole.ADMIN],
                    is_active=True,
                    referral_code__isnull=False,
                )
                .exclude(referral_code="")
                .order_by("full_name")
                .values("id", "full_name", "referral_code")
            )
            cache.set(self._CACHE_KEY, data, self._CACHE_TTL)
        return Response(data, status=status.HTTP_200_OK)


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
    Public read-only list of all document types (cached). GET only; no auth.

    For the applicant upload checklist, prefer GET /api/applicants/me/document-types/
    (authenticated) so INITIAL vs POST_INTERVIEW can follow lamaran progress.
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
        profile = self.get_applicant_profile()
        if WorkExperience.objects.filter(applicant_profile=profile).count() >= 2:
            from rest_framework.exceptions import ValidationError
            raise ValidationError(
                {"non_field_errors": [ApiMessage.WORK_EXPERIENCE_LIMIT]}
            )
        serializer.save(applicant_profile=profile)


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


# ---------------------------------------------------------------------------
# Reports (Laporan)
# ---------------------------------------------------------------------------

class AdminReportView(APIView):
    """
    Laporan statistik pelamar dengan filter rentang tanggal.
    Default: bulan berjalan jika start_date dan end_date tidak diberikan.
    Hanya Admin Utama / superuser (bukan Admin operator).

    Query params:
    - start_date: YYYY-MM-DD (default: first day of current month)
    - end_date: YYYY-MM-DD (default: today)

    Response:
    - summary: total counts and growth
    - by_status: breakdown by verification status
    - by_province: breakdown by province
    - by_gender: breakdown by gender
    - by_education: breakdown by education level
    - by_destination: breakdown by destination country
    - timeline: daily registrations within date range
    """

    permission_classes = [IsMasterAdmin]

    def get(self, request):
        # Parse date range from query params
        start_date_str = request.query_params.get("start_date")
        end_date_str = request.query_params.get("end_date")
        
        # Default to current month if not provided
        now = timezone.now()
        if not start_date_str:
            start_date = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        else:
            try:
                start_date = datetime.strptime(start_date_str, "%Y-%m-%d")
                start_date = timezone.make_aware(start_date.replace(hour=0, minute=0, second=0, microsecond=0))
            except ValueError:
                return Response(
                    error_response(
                        detail="Format start_date tidak valid. Gunakan YYYY-MM-DD.",
                        code=ApiCode.VALIDATION_ERROR,
                        status_code=status.HTTP_400_BAD_REQUEST,
                    ),
                    status=status.HTTP_400_BAD_REQUEST,
                )
        
        if not end_date_str:
            end_date = now.replace(hour=23, minute=59, second=59, microsecond=999999)
        else:
            try:
                end_date = datetime.strptime(end_date_str, "%Y-%m-%d")
                end_date = timezone.make_aware(end_date.replace(hour=23, minute=59, second=59, microsecond=999999))
            except ValueError:
                return Response(
                    error_response(
                        detail="Format end_date tidak valid. Gunakan YYYY-MM-DD.",
                        code=ApiCode.VALIDATION_ERROR,
                        status_code=status.HTTP_400_BAD_REQUEST,
                    ),
                    status=status.HTTP_400_BAD_REQUEST,
                )
        
        # Filter applicants by date range
        queryset = ApplicantProfile.objects.filter(
            created_at__gte=start_date,
            created_at__lte=end_date
        ).select_related("user", "province", "referrer")
        
        total_count = queryset.count()
        
        # Summary statistics
        by_status = list(
            queryset.values("verification_status")
            .annotate(count=Count("id"))
            .order_by("-count")
        )
        
        by_province = list(
            queryset.values(province_name=F("province__name"))
            .annotate(count=Count("id"))
            .order_by("-count")[:10]  # Top 10 provinces
        )
        
        by_gender = list(
            queryset.values("gender")
            .annotate(count=Count("id"))
            .order_by("-count")
        )
        
        by_education = list(
            queryset.values("education_level")
            .annotate(count=Count("id"))
            .order_by("-count")
        )
        
        by_destination = list(
            queryset.values("destination_country")
            .annotate(count=Count("id"))
            .order_by("-count")
        )
        
        # Timeline - daily registrations
        timeline = list(
            queryset.annotate(day=TruncDate("created_at"))
            .values("day")
            .annotate(count=Count("id"))
            .order_by("day")
        )
        
        # Referral statistics
        by_referrer = list(
            queryset.filter(referrer__isnull=False)
            .values(
                staff_id=F("referrer__id"),
                staff_name=F("referrer__full_name")
            )
            .annotate(count=Count("id"))
            .order_by("-count")[:10]  # Top 10 referrers
        )
        
        # Calculate completion rate (applicants with all required documents)
        required_doc_types = DocumentType.objects.filter(is_required=True).count()
        
        # Applicants who have submitted all required documents
        completed_applicants = queryset.annotate(
            doc_count=Count(
                "documents",
                filter=Q(
                    documents__document_type__is_required=True
                )
            )
        ).filter(doc_count__gte=required_doc_types).count()
        
        completion_rate = (completed_applicants / total_count * 100) if total_count > 0 else 0
        
        data = {
            "date_range": {
                "start_date": start_date.date().isoformat(),
                "end_date": end_date.date().isoformat(),
            },
            "summary": {
                "total_applicants": total_count,
                "total_accepted": queryset.filter(verification_status=ApplicantVerificationStatus.ACCEPTED).count(),
                "total_rejected": queryset.filter(verification_status=ApplicantVerificationStatus.REJECTED).count(),
                "total_submitted": queryset.filter(verification_status=ApplicantVerificationStatus.SUBMITTED).count(),
                "total_draft": queryset.filter(verification_status=ApplicantVerificationStatus.DRAFT).count(),
                "completion_rate": round(completion_rate, 2),
            },
            "by_status": by_status,
            "by_province": by_province,
            "by_gender": by_gender,
            "by_education": by_education,
            "by_destination": by_destination,
            "by_referrer": by_referrer,
            "timeline": [
                {
                    "date": row["day"].isoformat(),
                    "count": row["count"]
                }
                for row in timeline
            ],
        }
        
        return Response(data, status=status.HTTP_200_OK)


# ---------------------------------------------------------------------------
# Biodata PDF
# ---------------------------------------------------------------------------

class AdminBiodataPdfView(APIView):
    """
    Generate and download a Biodata CPMI PDF for a single applicant.
    GET /api/applicants/<pk>/biodata-pdf/
    """

    permission_classes = [IsBackofficeAdmin]

    def get(self, request, pk):
        applicant = get_object_or_404(
            ApplicantProfile.objects.select_related(
                "user",
                "birth_place",
                "province",
                "district",
                "village",
                "family_province",
                "family_district",
                "family_village",
            ).prefetch_related("work_experiences"),
            user__id=pk,
        )
        try:
            pdf_bytes = generate_biodata_pdf(applicant)
        except Exception as e:
            return Response(
                error_response(
                    detail=f"Gagal membuat PDF: {str(e)}",
                    code=ApiCode.INTERNAL_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        safe_name = (applicant.user.full_name or "biodata").replace(" ", "_")
        filename = f"Biodata_{safe_name}.pdf"
        response = HttpResponse(pdf_bytes, content_type="application/pdf")
        response["Content-Disposition"] = f'inline; filename="{filename}"'
        return response


# ---------------------------------------------------------------------------
# Inbond Cost PDF
# ---------------------------------------------------------------------------

class AdminInbondPdfView(APIView):
    """
    Generate the Tanda Terima Pengembalian Biaya Transportasi CPMI (Inbond Cost) PDF.
    Admin-only.
    GET /api/applicants/<pk>/inbond-pdf/
    """

    permission_classes = [IsBackofficeAdmin]

    def get(self, request, pk):
        applicant = get_object_or_404(
            ApplicantProfile.objects.select_related(
                "user",
                "birth_place",
                "district",
            ).prefetch_related("job_applications__job__company"),
            user__id=pk,
        )
        try:
            pdf_bytes = generate_inbond_pdf(applicant)
        except Exception as e:
            return Response(
                error_response(
                    detail=f"Gagal membuat PDF: {str(e)}",
                    code=ApiCode.INTERNAL_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        safe_name = (applicant.user.full_name or "cpmi").replace(" ", "_")
        filename = f"InboundCost_{safe_name}.pdf"
        response = HttpResponse(pdf_bytes, content_type="application/pdf")
        response["Content-Disposition"] = f'inline; filename="{filename}"'
        return response


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

class NotificationViewSet(viewsets.ModelViewSet):
    """
    ViewSet untuk notifikasi pengguna saat ini.
    GET /api/notifications/ - List notifikasi (unread first)
    GET /api/notifications/{id}/ - Detail notifikasi
    PATCH /api/notifications/{id}/mark-read/ - Tandai sebagai dibaca
    DELETE /api/notifications/{id}/ - Hapus notifikasi
    """
    
    http_method_names = ["get", "patch", "delete", "head", "options"]
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ["is_read", "notification_type", "priority"]
    ordering_fields = ["created_at", "priority"]
    ordering = ["-created_at"]

    def get_queryset(self):
        """Only return notifications for the current user."""
        return Notification.objects.filter(user=self.request.user)

    def destroy(self, request, *args, **kwargs):
        """Delete notification (only if it belongs to current user)."""
        notification = self.get_object()
        if notification.user != request.user:
            return Response(
                error_response(
                    detail="Notifikasi tidak ditemukan.",
                    code=ApiCode.NOT_FOUND,
                    status_code=status.HTTP_404_NOT_FOUND,
                ),
                status=status.HTTP_404_NOT_FOUND,
            )
        
        notification.delete()
        return Response(
            success_response(
                detail="Notifikasi berhasil dihapus.",
            ),
            status=status.HTTP_200_OK,
        )

    @action(detail=True, methods=["patch"], url_path="mark-read")
    def mark_read(self, request, pk=None):
        """Mark notification as read."""
        notification = self.get_object()
        if notification.user != request.user:
            return Response(
                error_response(
                    detail="Notifikasi tidak ditemukan.",
                    code=ApiCode.NOT_FOUND,
                    status_code=status.HTTP_404_NOT_FOUND,
                ),
                status=status.HTTP_404_NOT_FOUND,
            )
        
        notification.mark_as_read()
        serializer = self.get_serializer(notification)
        return Response(
            success_response(
                data=serializer.data,
                detail="Notifikasi ditandai sebagai dibaca.",
            ),
            status=status.HTTP_200_OK,
        )

    @action(detail=False, methods=["post"], url_path="mark-all-read")
    def mark_all_read(self, request):
        """Mark all unread notifications as read."""
        updated = Notification.objects.filter(
            user=request.user,
            is_read=False
        ).update(
            is_read=True,
            read_at=timezone.now()
        )
        return Response(
            success_response(
                data={"updated_count": updated},
                detail=f"{updated} notifikasi ditandai sebagai dibaca.",
            ),
            status=status.HTTP_200_OK,
        )

    @action(detail=False, methods=["get"], url_path="unread-count")
    def unread_count(self, request):
        """Get count of unread notifications."""
        count = Notification.objects.filter(
            user=request.user,
            is_read=False
        ).count()
        return Response(
            success_response(
                data={"count": count},
            ),
            status=status.HTTP_200_OK,
        )


class BroadcastViewSet(viewsets.ModelViewSet):
    """
    ViewSet untuk broadcast notifications (admin only).
    GET /api/broadcasts/ - List broadcasts
    POST /api/broadcasts/ - Create broadcast
    GET /api/broadcasts/{id}/ - Detail broadcast
    POST /api/broadcasts/{id}/send/ - Send broadcast immediately
    POST /api/broadcasts/{id}/preview-recipients/ - Preview recipient count
    """
    
    serializer_class = BroadcastSerializer
    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ["notification_type", "priority", "created_by"]
    ordering_fields = ["created_at", "sent_at", "total_recipients"]
    ordering = ["-created_at"]

    def get_queryset(self):
        return Broadcast.objects.select_related("created_by").all()

    def get_serializer_class(self):
        if self.action == "create":
            from .serializers import BroadcastCreateSerializer
            return BroadcastCreateSerializer
        return BroadcastSerializer

    def perform_create(self, serializer):
        """Set created_by to current user."""
        serializer.save(created_by=self.request.user)

    @action(detail=True, methods=["post"], url_path="send")
    def send(self, request, pk=None):
        """Send broadcast immediately (or schedule if scheduled_at is set)."""
        broadcast = self.get_object()
        
        if broadcast.sent_at:
            return Response(
                error_response(
                    detail="Broadcast sudah dikirim sebelumnya.",
                    code=ApiCode.ALREADY_PROCESSED,
                    status_code=status.HTTP_400_BAD_REQUEST,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        # Check if scheduled
        if broadcast.scheduled_at and broadcast.scheduled_at > timezone.now():
            # Schedule via Celery
            from .tasks import send_broadcast_task
            send_broadcast_task.apply_async(
                args=[broadcast.id],
                eta=broadcast.scheduled_at
            )
            return Response(
                success_response(
                    data={"scheduled_at": broadcast.scheduled_at},
                    detail="Broadcast dijadwalkan untuk dikirim.",
                ),
                status=status.HTTP_200_OK,
            )
        
        # Send immediately
        try:
            recipient_count = send_broadcast(broadcast)
            serializer = self.get_serializer(broadcast)
            return Response(
                success_response(
                    data=serializer.data,
                    detail=f"Broadcast dikirim ke {recipient_count} penerima.",
                ),
                status=status.HTTP_200_OK,
            )
        except Exception as e:
            return Response(
                error_response(
                    detail=f"Gagal mengirim broadcast: {str(e)}",
                    code=ApiCode.INTERNAL_ERROR,
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    @action(detail=False, methods=["post"], url_path="preview-recipients")
    def preview_recipients(self, request):
        """Preview recipient count based on recipient_config (before creating broadcast)."""
        recipient_config = request.data.get("recipient_config", {})
        
        # Validate config
        is_valid, error_msg = validate_recipient_config(recipient_config)
        if not is_valid:
            return Response(
                error_response(
                    detail=error_msg,
                    code=ApiCode.VALIDATION_ERROR,
                    status_code=status.HTTP_400_BAD_REQUEST,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        # Get count
        count = get_recipient_count(recipient_config)
        return Response(
            success_response(
                data={"recipient_count": count},
                detail=f"Preview: {count} penerima akan menerima broadcast.",
            ),
            status=status.HTTP_200_OK,
        )


# ---------------------------------------------------------------------------
# FCM Token Management
# ---------------------------------------------------------------------------

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def register_fcm_token(request):
    """
    Register FCM token for current user.
    POST /api/fcm/register/
    Body: {"token": "...", "device_type": "web|android|ios"}
    """
    from .models import DeviceToken
    
    token = request.data.get("token")
    device_type = request.data.get("device_type", "web")
    
    if not token:
        return Response(
            error_response(
                detail="Token FCM diperlukan.",
                code=ApiCode.VALIDATION_ERROR,
                status_code=status.HTTP_400_BAD_REQUEST,
            ),
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Validate device_type
    valid_types = ["web", "android", "ios"]
    if device_type not in valid_types:
        return Response(
            error_response(
                detail=f"device_type harus salah satu dari: {', '.join(valid_types)}",
                code=ApiCode.VALIDATION_ERROR,
                status_code=status.HTTP_400_BAD_REQUEST,
            ),
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Create or update token
    device_token, created = DeviceToken.objects.update_or_create(
        token=token,
        defaults={
            "user": request.user,
            "device_type": device_type,
            "is_active": True,
        }
    )
    
    action = "registered" if created else "updated"
    return Response(
        success_response(
            data={
                "token_id": device_token.id,
                "device_type": device_token.device_type,
            },
            detail=f"FCM token {action} successfully.",
        ),
        status=status.HTTP_201_CREATED if created else status.HTTP_200_OK
    )


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def unregister_fcm_token(request):
    """
    Unregister FCM token for current user.
    POST /api/fcm/unregister/
    Body: {"token": "..."}
    """
    from .models import DeviceToken
    
    token = request.data.get("token")
    
    if not token:
        return Response(
            error_response(
                detail="Token FCM diperlukan.",
                code=ApiCode.VALIDATION_ERROR,
                status_code=status.HTTP_400_BAD_REQUEST,
            ),
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Deactivate token (safer than deleting)
    updated = DeviceToken.objects.filter(
        user=request.user,
        token=token
    ).update(is_active=False)
    
    if updated:
        return Response(
            success_response(
                detail="FCM token unregistered successfully.",
            ),
            status=status.HTTP_200_OK
        )
    else:
        return Response(
            error_response(
                detail="Token tidak ditemukan.",
                code=ApiCode.NOT_FOUND,
                status_code=status.HTTP_404_NOT_FOUND,
            ),
            status=status.HTTP_404_NOT_FOUND
        )


# ---------------------------------------------------------------------------
# Account Deletion Requests
# ---------------------------------------------------------------------------

class AccountDeletionRequestViewSet(viewsets.GenericViewSet):
    """
    Admin CRUD + applicant self-service for account deletion requests.

    Admin endpoints (require IsMasterAdmin — operator Admin cannot access):
      GET    /api/deletion-requests/          – list all requests (filterable by status)
      GET    /api/deletion-requests/<id>/     – retrieve one request
      POST   /api/deletion-requests/<id>/approve/ – approve (triggers user deactivation)
      POST   /api/deletion-requests/<id>/reject/  – reject with notes

    Applicant self-service (require IsAuthenticated + IsApplicant):
      POST   /api/deletion-requests/              – submit own request
      GET    /api/deletion-requests/my/           – view own request
      POST   /api/deletion-requests/my/cancel/    – cancel own pending request
    """

    serializer_class = AccountDeletionRequestSerializer

    def get_permissions(self):
        if self.action in ("my_request", "submit", "cancel"):
            return [IsAuthenticated(), IsApplicant()]
        return [IsMasterAdmin()]

    # ------------------------------------------------------------------ admin

    def list(self, request):
        """GET /api/deletion-requests/ — admin list, filterable by ?status=PENDING"""
        qs = (
            AccountDeletionRequest.objects
            .select_related("user", "reviewed_by")
            .order_by("-requested_at")
        )
        status_filter = request.query_params.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter.upper())
        search = request.query_params.get("search")
        if search:
            qs = qs.filter(
                Q(user__email__icontains=search) | Q(user__full_name__icontains=search)
            )
        serializer = self.get_serializer(qs, many=True)
        return Response(success_response(data=serializer.data), status=status.HTTP_200_OK)

    def retrieve(self, request, pk=None):
        """GET /api/deletion-requests/<id>/ — admin retrieve"""
        obj = get_object_or_404(
            AccountDeletionRequest.objects.select_related("user", "reviewed_by"), pk=pk
        )
        return Response(success_response(data=self.get_serializer(obj).data))

    @action(detail=True, methods=["post"], url_path="approve")
    def approve(self, request, pk=None):
        """POST /api/deletion-requests/<id>/approve/ — admin approves → email user, then delete account."""
        obj = get_object_or_404(AccountDeletionRequest, pk=pk)
        if obj.status != AccountDeletionRequest.DeletionStatus.PENDING:
            return Response(
                error_response(
                    detail=ApiMessage.DELETION_REQUEST_NOT_PENDING,
                    code=ApiCode.DELETION_REQUEST_NOT_PENDING,
                    status_code=status.HTTP_400_BAD_REQUEST,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        admin_notes = request.data.get("admin_notes", "")
        obj.status = AccountDeletionRequest.DeletionStatus.APPROVED
        obj.reviewed_by = request.user
        obj.reviewed_at = timezone.now()
        obj.admin_notes = admin_notes
        obj.save(update_fields=["status", "reviewed_by", "reviewed_at", "admin_notes"])

        # Snapshot response before deleting user (CASCADE removes this request row).
        payload_data = self.get_serializer(obj).data
        user = obj.user
        # Email must run synchronously while the user row still exists (async Celery would run after delete).
        email_ctx = {
            "user_name": (user.full_name or "").strip() or user.email.split("@")[0],
            "admin_notes": admin_notes or "",
        }
        try:
            send_event_email_task.delay(
                user.pk,
                NotificationEvent.ACCOUNT_DELETION_APPROVED.value,
                email_ctx,
                "",
            )
        except Exception:
            logger.exception(
                "Failed to queue account deletion approval email user_id=%s", user.pk
            )

        user.delete()

        return Response(
            success_response(
                data=payload_data,
                detail=ApiMessage.DELETION_REQUEST_APPROVED,
                code=ApiCode.DELETION_REQUEST_APPROVED,
            ),
            status=status.HTTP_200_OK,
        )

    @action(detail=True, methods=["post"], url_path="reject")
    def reject(self, request, pk=None):
        """POST /api/deletion-requests/<id>/reject/ — admin rejects"""
        obj = get_object_or_404(AccountDeletionRequest, pk=pk)
        if obj.status != AccountDeletionRequest.DeletionStatus.PENDING:
            return Response(
                error_response(
                    detail=ApiMessage.DELETION_REQUEST_NOT_PENDING,
                    code=ApiCode.DELETION_REQUEST_NOT_PENDING,
                    status_code=status.HTTP_400_BAD_REQUEST,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        admin_notes = request.data.get("admin_notes", "")
        obj.status = AccountDeletionRequest.DeletionStatus.REJECTED
        obj.reviewed_by = request.user
        obj.reviewed_at = timezone.now()
        obj.admin_notes = admin_notes
        obj.save(update_fields=["status", "reviewed_by", "reviewed_at", "admin_notes"])

        recipient = obj.user
        try:
            dispatch(
                NotificationEvent.ACCOUNT_DELETION_REJECTED,
                recipient,
                context={
                    "user_name": (recipient.full_name or "").strip()
                    or recipient.email.split("@")[0],
                    "admin_notes": admin_notes or "",
                },
                force_email=True,
                deduplicate=False,
            )
        except Exception:
            logger.exception(
                "Failed to dispatch account deletion rejection notification user_id=%s",
                recipient.pk,
            )

        return Response(
            success_response(
                data=self.get_serializer(obj).data,
                detail=ApiMessage.DELETION_REQUEST_REJECTED,
                code=ApiCode.DELETION_REQUEST_REJECTED,
            ),
            status=status.HTTP_200_OK,
        )

    # -------------------------------------------------------- applicant self-service

    @action(detail=False, methods=["post"], url_path="submit")
    def submit(self, request):
        """POST /api/deletion-requests/submit/ — applicant submits own request"""
        if AccountDeletionRequest.objects.filter(
            user=request.user,
            status=AccountDeletionRequest.DeletionStatus.PENDING,
        ).exists():
            return Response(
                error_response(
                    detail=ApiMessage.DELETION_REQUEST_ALREADY_PENDING,
                    code=ApiCode.DELETION_REQUEST_ALREADY_PENDING,
                    status_code=status.HTTP_400_BAD_REQUEST,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        # Replace any previous non-pending request
        AccountDeletionRequest.objects.filter(user=request.user).delete()
        obj = AccountDeletionRequest.objects.create(
            user=request.user,
            reason=request.data.get("reason", ""),
        )
        return Response(
            success_response(
                data=self.get_serializer(obj).data,
                detail=ApiMessage.DELETION_REQUEST_SUBMITTED,
                code=ApiCode.DELETION_REQUEST_SUBMITTED,
            ),
            status=status.HTTP_201_CREATED,
        )

    @action(detail=False, methods=["get"], url_path="my")
    def my_request(self, request):
        """GET /api/deletion-requests/my/ — applicant views own request"""
        try:
            obj = AccountDeletionRequest.objects.get(user=request.user)
        except AccountDeletionRequest.DoesNotExist:
            return Response(success_response(data=None), status=status.HTTP_200_OK)
        return Response(success_response(data=self.get_serializer(obj).data))

    @action(detail=False, methods=["post"], url_path="my/cancel")
    def cancel(self, request):
        """POST /api/deletion-requests/my/cancel/ — applicant cancels own pending request"""
        try:
            obj = AccountDeletionRequest.objects.get(
                user=request.user,
                status=AccountDeletionRequest.DeletionStatus.PENDING,
            )
        except AccountDeletionRequest.DoesNotExist:
            return Response(
                error_response(
                    detail=ApiMessage.DELETION_REQUEST_NOT_FOUND,
                    code=ApiCode.DELETION_REQUEST_NOT_FOUND,
                    status_code=status.HTTP_404_NOT_FOUND,
                ),
                status=status.HTTP_404_NOT_FOUND,
            )
        obj.status = AccountDeletionRequest.DeletionStatus.CANCELLED
        obj.save(update_fields=["status"])
        return Response(
            success_response(
                data=self.get_serializer(obj).data,
                detail=ApiMessage.DELETION_REQUEST_CANCELLED,
                code=ApiCode.DELETION_REQUEST_CANCELLED,
            ),
            status=status.HTTP_200_OK,
        )

