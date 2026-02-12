"""
Self-service views untuk pelamar (mobile app).
Pelamar dapat melihat dan mengubah profil, dokumen, dan pengalaman kerja mereka sendiri.
"""
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.shortcuts import get_object_or_404

from .models import (
    ApplicantProfile,
    WorkExperience,
    ApplicantDocument,
    DocumentType,
    ApplicantVerificationStatus,
)
from .serializers import (
    ApplicantProfileSerializer,
    WorkExperienceSerializer,
    ApplicantDocumentSerializer,
)
from .permissions import IsApplicant
from .api_responses import success_response, error_response, ApiCode
from .document_specs import validate_document_file
from .tasks import process_document_ocr, optimize_document_image


class ApplicantSelfServiceMixin:
    """Mixin untuk mendapatkan applicant profile dari current user."""

    def get_applicant_profile(self):
        """Return applicant profile untuk current user."""
        if not self.request.user.is_authenticated:
            return None
        try:
            return self.request.user.applicant_profile
        except ApplicantProfile.DoesNotExist:
            return None


class ApplicantProfileSelfServiceViewSet(ApplicantSelfServiceMixin, viewsets.ModelViewSet):
    """
    Self-service untuk profil pelamar sendiri.
    GET /api/applicants/me/profile/ - Get own profile
    PATCH /api/applicants/me/profile/ - Update own profile
    """

    serializer_class = ApplicantProfileSerializer
    permission_classes = [IsAuthenticated, IsApplicant]
    http_method_names = ["get", "patch", "head", "options"]

    def get_object(self):
        """Return applicant profile untuk current user."""
        profile = self.get_applicant_profile()
        if not profile:
            from rest_framework.exceptions import NotFound
            raise NotFound("Profil pelamar tidak ditemukan.")
        return profile

    def get_queryset(self):
        """Return queryset dengan hanya profile current user."""
        profile = self.get_applicant_profile()
        if profile:
            return ApplicantProfile.objects.filter(pk=profile.pk)
        return ApplicantProfile.objects.none()

    def list(self, request, *args, **kwargs):
        """Override list to return single profile (own profile)."""
        instance = self.get_object()
        serializer = self.get_serializer(instance, context={"request": request, "is_own_profile": True})
        return Response(
            success_response(data=serializer.data),
            status=status.HTTP_200_OK,
        )

    def retrieve(self, request, *args, **kwargs):
        """Override retrieve to return own profile (ignore pk)."""
        instance = self.get_object()
        serializer = self.get_serializer(instance, context={"request": request, "is_own_profile": True})
        return Response(
            success_response(data=serializer.data),
            status=status.HTTP_200_OK,
        )

    def partial_update(self, request, *args, **kwargs):
        """Update profil sendiri. Beberapa field read-only (verification_status, dll)."""
        instance = self.get_object()
        serializer = self.get_serializer(
            instance,
            data=request.data,
            partial=True,
            context={"request": request, "is_own_profile": True},
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(
            success_response(data=serializer.data, detail="Profil berhasil diperbarui."),
            status=status.HTTP_200_OK,
        )

    @action(detail=False, methods=["post"])
    def submit_for_verification(self, request):
        """Submit profil untuk verifikasi admin."""
        profile = self.get_object()

        # Validasi: harus ada data minimal (NIK, nama, alamat, kontak)
        if not profile.nik or not profile.full_name or not profile.address or not profile.contact_phone:
            return Response(
                error_response(
                    detail="Lengkapi data pribadi terlebih dahulu (NIK, Nama, Alamat, No. HP).",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Cek apakah sudah pernah submit
        if profile.verification_status != ApplicantVerificationStatus.DRAFT:
            return Response(
                error_response(
                    detail=f"Profil sudah dalam status: {profile.get_verification_status_display()}.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Update status ke SUBMITTED
        from django.utils import timezone

        profile.verification_status = ApplicantVerificationStatus.SUBMITTED
        profile.submitted_at = timezone.now()
        profile.save(update_fields=["verification_status", "submitted_at"])

        serializer = self.get_serializer(instance=profile, context={"request": request})
        return Response(
            success_response(
                data=serializer.data,
                detail="Profil berhasil dikirim untuk verifikasi. Admin akan memverifikasi data Anda.",
            ),
            status=status.HTTP_200_OK,
        )


class ApplicantWorkExperienceSelfServiceViewSet(ApplicantSelfServiceMixin, viewsets.ModelViewSet):
    """
    Self-service untuk pengalaman kerja pelamar sendiri.
    GET /api/applicants/me/work_experiences/ - List own work experiences
    POST /api/applicants/me/work_experiences/ - Create work experience
    GET /api/applicants/me/work_experiences/:id/ - Get work experience
    PATCH /api/applicants/me/work_experiences/:id/ - Update work experience
    DELETE /api/applicants/me/work_experiences/:id/ - Delete work experience
    """

    serializer_class = WorkExperienceSerializer
    permission_classes = [IsAuthenticated, IsApplicant]

    def get_queryset(self):
        """Return work experiences untuk current user."""
        profile = self.get_applicant_profile()
        if profile:
            return WorkExperience.objects.filter(applicant_profile=profile).order_by(
                "sort_order", "-end_date", "-start_date"
            )
        return WorkExperience.objects.none()

    def perform_create(self, serializer):
        """Create work experience untuk current user."""
        profile = self.get_applicant_profile()
        if not profile:
            from rest_framework.exceptions import NotFound
            raise NotFound("Profil pelamar tidak ditemukan.")
        serializer.save(applicant_profile=profile)


class ApplicantDocumentSelfServiceViewSet(ApplicantSelfServiceMixin, viewsets.ModelViewSet):
    """
    Self-service untuk dokumen pelamar sendiri.
    GET /api/applicants/me/documents/ - List own documents
    POST /api/applicants/me/documents/ - Upload document
    GET /api/applicants/me/documents/:id/ - Get document
    DELETE /api/applicants/me/documents/:id/ - Delete document
    """

    serializer_class = ApplicantDocumentSerializer
    permission_classes = [IsAuthenticated, IsApplicant]
    http_method_names = ["get", "post", "delete", "head", "options"]

    def get_queryset(self):
        """Return documents untuk current user."""
        profile = self.get_applicant_profile()
        if profile:
            return (
                ApplicantDocument.objects.filter(applicant_profile=profile)
                .select_related("document_type", "reviewed_by")
                .order_by("document_type__sort_order")
            )
        return ApplicantDocument.objects.none()

    def perform_create(self, serializer):
        """Upload document untuk current user."""
        profile = self.get_applicant_profile()
        if not profile:
            from rest_framework.exceptions import NotFound
            raise NotFound("Profil pelamar tidak ditemukan.")

        # Validasi file dari request
        file = self.request.FILES.get("file")
        document_type_id = self.request.data.get("document_type")

        if not file:
            from rest_framework.exceptions import ValidationError
            raise ValidationError({"file": "File wajib diunggah."})

        if not document_type_id:
            from rest_framework.exceptions import ValidationError
            raise ValidationError({"document_type": "Tipe dokumen wajib dipilih."})

        try:
            document_type = DocumentType.objects.get(pk=document_type_id)
        except DocumentType.DoesNotExist:
            from rest_framework.exceptions import ValidationError
            raise ValidationError({"document_type": "Tipe dokumen tidak ditemukan."})

        # Validasi format dan ukuran file
        try:
            validate_document_file(file, document_type.code)
        except Exception as e:
            from rest_framework.exceptions import ValidationError
            raise ValidationError({"file": str(e)})

        # Simpan document
        document = serializer.save(
            applicant_profile=profile,
            document_type=document_type,
            file=file,
        )

        # Trigger OCR processing untuk KTP (async)
        if document_type.code == "ktp":
            process_document_ocr.delay(document.id)

        # Trigger image optimization untuk image types (async)
        from .document_specs import is_image_type

        if is_image_type(document_type.code):
            optimize_document_image.delay(document.id)

    @action(detail=True, methods=["get"])
    def ocr_prefill(self, request, pk=None):
        """Get OCR prefill data untuk KTP document."""
        document = self.get_object()

        if document.document_type.code != "ktp":
            return Response(
                error_response(
                    detail="OCR prefill hanya tersedia untuk dokumen KTP.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        prefill_data = document.get_biodata_prefill()
        if not prefill_data:
            return Response(
                error_response(
                    detail="Data OCR belum tersedia. KTP sedang diproses atau tidak dapat diekstrak.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            success_response(
                data=prefill_data,
                detail="Data OCR berhasil diekstrak dari KTP.",
            ),
            status=status.HTTP_200_OK,
        )
