"""
Self-service views untuk pelamar (mobile app).
Pelamar dapat melihat dan mengubah profil, dokumen, dan pengalaman kerja mereka sendiri.
"""
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.shortcuts import get_object_or_404

from .models import (
    ApplicantProfile,
    WorkExperience,
    ApplicantDocument,
    DocumentType,
    ApplicantVerificationStatus,
    DocumentReviewStatus,
)
from .serializers import (
    ApplicantProfileSerializer,
    WorkExperienceSerializer,
    ApplicantDocumentSerializer,
    DocumentTypeSerializer,
)
from django.http import HttpResponse
from .permissions import IsApplicant
from .api_responses import success_response, error_response, ApiCode, ApiMessage
from .document_specs import validate_document_file, compress_image_file, is_image_type
from .services.biodata_pdf import generate_biodata_pdf
from .services.pengantar_medical_pdf import generate_pengantar_medical_pdf
from .services.pengantar_psikologi_pdf import generate_pengantar_psikologi_pdf


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
        """Return queryset dengan profile current user + regions prefetched."""
        profile = self.get_applicant_profile()
        if profile:
            return ApplicantProfile.objects.filter(pk=profile.pk).with_related()
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

        # Once profile has been ACCEPTED, pelamar tidak boleh mengubah data diri lagi
        if instance.verification_status == ApplicantVerificationStatus.ACCEPTED:
            return Response(
                error_response(
                    detail="Profil sudah diterima. Data diri tidak dapat diubah lagi.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

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
        if not profile.nik or not profile.user.full_name or not profile.address or not profile.contact_phone:
            return Response(
                error_response(
                    detail="Lengkapi data pribadi terlebih dahulu (NIK, Nama, Alamat, No. HP).",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        from django.utils import timezone

        if profile.verification_status == ApplicantVerificationStatus.ACCEPTED:
            return Response(
                error_response(
                    detail="Profil sudah diterima. Tidak perlu dikirim ulang.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        if profile.verification_status == ApplicantVerificationStatus.SUBMITTED:
            serializer = self.get_serializer(instance=profile, context={"request": request})
            return Response(
                success_response(
                    data=serializer.data,
                    detail="Profil sudah dalam antrean verifikasi (Dikirim).",
                ),
                status=status.HTTP_200_OK,
            )

        # REJECTED → SUBMITTED (kirim ulang)
        profile.verification_status = ApplicantVerificationStatus.SUBMITTED
        profile.submitted_at = timezone.now()
        profile.save(update_fields=["verification_status", "submitted_at"])

        serializer = self.get_serializer(instance=profile, context={"request": request})
        return Response(
            success_response(
                data=serializer.data,
                detail="Profil berhasil dikirim ulang untuk verifikasi. Admin akan memverifikasi data Anda.",
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
        """Create work experience for current user, enforcing max 2 per applicant."""
        profile = self.get_applicant_profile()
        if not profile:
            from rest_framework.exceptions import NotFound
            raise NotFound("Profil pelamar tidak ditemukan.")
        if WorkExperience.objects.filter(applicant_profile=profile).count() >= 2:
            from rest_framework.exceptions import ValidationError
            raise ValidationError(
                {"non_field_errors": [ApiMessage.WORK_EXPERIENCE_LIMIT]}
            )
        serializer.save(applicant_profile=profile)

    # ── Response wrappers ────────────────────────────────────────────────────
    # Wrap all responses in the standard {code, detail, data} envelope so the
    # mobile ApiResponse parser works correctly.

    def list(self, request, *args, **kwargs):
        queryset = self.filter_queryset(self.get_queryset())
        serializer = self.get_serializer(queryset, many=True)
        return Response(
            success_response(data=serializer.data),
            status=status.HTTP_200_OK,
        )

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        return Response(
            success_response(
                data=serializer.data,
                detail="Pengalaman kerja berhasil ditambahkan.",
            ),
            status=status.HTTP_201_CREATED,
        )

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        serializer = self.get_serializer(instance)
        return Response(
            success_response(data=serializer.data),
            status=status.HTTP_200_OK,
        )

    def partial_update(self, request, *args, **kwargs):
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(
            success_response(
                data=serializer.data,
                detail="Pengalaman kerja berhasil diperbarui.",
            ),
            status=status.HTTP_200_OK,
        )


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

    def create(self, request, *args, **kwargs):
        """
        Upload atau ganti dokumen. Jika dokumen dengan tipe yang sama sudah ada,
        file akan diganti dan status review di-reset ke PENDING (upsert).
        Mengembalikan 201 untuk dokumen baru, 200 untuk penggantian.
        """
        from rest_framework.exceptions import ValidationError, NotFound
        from .document_specs import is_image_type

        profile = self.get_applicant_profile()
        if not profile:
            raise NotFound("Profil pelamar tidak ditemukan.")

        file = request.FILES.get("file")
        document_type_id = request.data.get("document_type")

        if not file:
            raise ValidationError({"file": "File wajib diunggah."})

        if not document_type_id:
            raise ValidationError({"document_type": "Tipe dokumen wajib dipilih."})

        try:
            document_type = DocumentType.objects.get(pk=document_type_id)
        except DocumentType.DoesNotExist:
            raise ValidationError({"document_type": "Tipe dokumen tidak ditemukan."})

        # Validasi format dan ukuran file
        try:
            validate_document_file(file, document_type.code)
        except Exception as e:
            raise ValidationError({"file": str(e)})

        # Compress image files before saving (synchronous)
        if is_image_type(document_type.code):
            file = compress_image_file(file)

        existing = ApplicantDocument.objects.filter(
            applicant_profile=profile,
            document_type=document_type,
        ).first()

        if existing and existing.review_status == DocumentReviewStatus.APPROVED:
            return Response(
                error_response(
                    detail="Dokumen ini sudah disetujui dan tidak dapat diganti.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_403_FORBIDDEN,
            )

        if existing:
            # Ganti file lama dan reset status review / OCR
            existing.file = file
            existing.review_status = DocumentReviewStatus.PENDING
            existing.reviewed_by = None
            existing.reviewed_at = None
            existing.review_notes = ""
            existing.ocr_text = ""
            existing.ocr_data = {}
            existing.ocr_processed_at = None
            existing.save()
            document = existing
            created = False
        else:
            serializer = self.get_serializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            document = serializer.save(
                applicant_profile=profile,
                document_type=document_type,
                file=file,
            )
            created = True

        # OCR (Google Vision) hanya untuk KTP — di-signal dari post_save ApplicantDocument.

        response_serializer = self.get_serializer(document)
        response_status = status.HTTP_201_CREATED if created else status.HTTP_200_OK
        return Response(response_serializer.data, status=response_status)

    def destroy(self, request, *args, **kwargs):
        """
        Hapus dokumen. Dokumen yang sudah disetujui (APPROVED) tidak dapat dihapus.
        """
        document = self.get_object()
        if document.review_status == DocumentReviewStatus.APPROVED:
            return Response(
                error_response(
                    detail="Dokumen yang sudah disetujui tidak dapat dihapus.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().destroy(request, *args, **kwargs)

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

# Ahli waris (next of kin) is now stored as flat fields on ApplicantProfile:
#   heir_name, heir_relationship, heir_contact_phone
# Update them via PATCH /api/applicants/me/profile/


class ApplicantDocumentTypesChecklistView(APIView):
    """
    GET /api/applicants/me/document-types/

    Daftar tipe dokumen untuk checklist unggah (mobile), disesuaikan dengan
    progres lamaran:

    - Hanya fase INITIAL sampai pelamar lulus pra-seleksi pada minimal satu
      lamaran aktif (status PRA_SELEKSI dengan kehadiran terkonfirmasi) atau
      mencapai tahap INTERVIEW+.
    - Setelah itu: semua tipe (INITIAL + POST_INTERVIEW).
    """

    permission_classes = [IsAuthenticated, IsApplicant]

    def get(self, request):
        from main.models import JobApplication, ApplicationStatus

        profile = getattr(request.user, "applicant_profile", None)
        if profile is None:
            try:
                profile = ApplicantProfile.objects.get(user=request.user)
            except ApplicantProfile.DoesNotExist:
                profile = None
        if profile is None:
            return Response(
                error_response(
                    detail="Profil pelamar tidak ditemukan.",
                    code=ApiCode.NOT_FOUND,
                ),
                status=status.HTTP_404_NOT_FOUND,
            )

        # Unlock full document checklist once applicant has:
        # - at least one application where PRA_SELEKSI attendance is confirmed
        #   (pra_seleksi_confirmed_at is not null), OR
        # - reached INTERVIEW or later on any application.
        has_confirmed_pra_seleksi = JobApplication.objects.filter(
            applicant=profile,
            status=ApplicationStatus.PRA_SELEKSI,
            pra_seleksi_confirmed_at__isnull=False,
        ).exists()

        post_interview_onwards = [
            ApplicationStatus.INTERVIEW,
            ApplicationStatus.DITERIMA,
            ApplicationStatus.BERANGKAT,
            ApplicationStatus.SELESAI,
        ]
        has_reached_interview_or_later = JobApplication.objects.filter(
            applicant=profile,
            status__in=post_interview_onwards,
        ).exists()

        if has_confirmed_pra_seleksi or has_reached_interview_or_later:
            qs = DocumentType.objects.all().order_by("sort_order", "code")
        else:
            qs = DocumentType.objects.filter(phase=DocumentType.PHASE_INITIAL).order_by(
                "sort_order", "code"
            )

        serializer = DocumentTypeSerializer(qs, many=True)
        return Response(
            success_response(data=serializer.data),
            status=status.HTTP_200_OK,
        )


class ApplicantChangePasswordView(APIView):
    """
    POST /api/applicants/me/change-password/
    Allows an authenticated applicant to change their own password.
    Body: { "old_password": "...", "new_password": "..." }
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        old_password = request.data.get("old_password", "").strip()
        new_password = request.data.get("new_password", "").strip()

        if not old_password or not new_password:
            return Response(
                error_response(
                    detail="old_password dan new_password wajib diisi.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors={
                        **({"old_password": ["Wajib diisi."]} if not old_password else {}),
                        **({"new_password": ["Wajib diisi."]} if not new_password else {}),
                    },
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not user.check_password(old_password):
            return Response(
                error_response(
                    detail="Password lama tidak sesuai.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors={"old_password": ["Password lama tidak sesuai."]},
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        if old_password == new_password:
            return Response(
                error_response(
                    detail="Password baru tidak boleh sama dengan password lama.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors={"new_password": ["Password baru tidak boleh sama dengan password lama."]},
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            validate_password(new_password, user)
        except DjangoValidationError as e:
            msgs = list(e.messages)
            return Response(
                error_response(
                    detail=msgs[0] if msgs else "Password tidak memenuhi syarat.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors={"new_password": msgs},
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.set_password(new_password)
        user.save(update_fields=["password"])

        return Response(
            success_response(
                detail="Password berhasil diubah.",
                code=ApiCode.SUCCESS,
            ),
            status=status.HTTP_200_OK,
        )


class ApplicantBiodataPdfView(APIView):
    """
    GET /api/applicants/me/biodata-pdf/
    Generates and downloads the Biodata CPMI PDF for the logged-in applicant.
    """

    permission_classes = [IsAuthenticated, IsApplicant]

    def get(self, request):
        try:
            profile = ApplicantProfile.objects.select_related(
                "user",
                "birth_place",
                "province",
                "district",
                "village",
                "family_province",
                "family_district",
                "family_village",
            ).prefetch_related("work_experiences").get(user=request.user)
        except ApplicantProfile.DoesNotExist:
            return Response(
                error_response(
                    detail="Profil pelamar tidak ditemukan.",
                    code=ApiCode.NOT_FOUND,
                ),
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            pdf_bytes = generate_biodata_pdf(profile)
        except Exception as e:
            return Response(
                error_response(
                    detail=f"Gagal membuat PDF: {str(e)}",
                    code=ApiCode.INTERNAL_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        safe_name = (profile.user.full_name or "biodata").replace(" ", "_")
        filename = f"Biodata_{safe_name}.pdf"
        response = HttpResponse(pdf_bytes, content_type="application/pdf")
        response["Content-Disposition"] = f'attachment; filename="{filename}"'
        return response


class ApplicantPsychologyReferralPdfView(APIView):
    """
    GET /api/applicants/me/psychology-referral-pdf/

    Surat Pengantar Tes Psikologi — hanya jika ada lamaran berstatus Diterima.
    """

    permission_classes = [IsAuthenticated, IsApplicant]

    def get(self, request):
        from main.models import ApplicationStatus, JobApplication

        try:
            profile = ApplicantProfile.objects.select_related(
                "user",
                "birth_place",
                "district",
            ).prefetch_related(
                "job_applications__job__company",
            ).get(user=request.user)
        except ApplicantProfile.DoesNotExist:
            return Response(
                error_response(
                    detail="Profil pelamar tidak ditemukan.",
                    code=ApiCode.NOT_FOUND,
                ),
                status=status.HTTP_404_NOT_FOUND,
            )

        if not JobApplication.objects.filter(
            applicant=profile,
            status=ApplicationStatus.DITERIMA,
        ).exists():
            return Response(
                error_response(
                    detail="Surat pengantar tes psikologi hanya tersedia saat Anda berada di tahap Diterima.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_403_FORBIDDEN,
            )

        try:
            pdf_bytes = generate_pengantar_psikologi_pdf(profile)
        except Exception as e:
            return Response(
                error_response(
                    detail=f"Gagal membuat PDF: {str(e)}",
                    code=ApiCode.INTERNAL_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        safe_name = (profile.user.full_name or "cpmi").replace(" ", "_")
        filename = f"Pengantar_Psikologi_{safe_name}.pdf"
        response = HttpResponse(pdf_bytes, content_type="application/pdf")
        response["Content-Disposition"] = f'attachment; filename="{filename}"'
        return response


class ApplicantMedicalReferralPdfView(APIView):
    """
    GET /api/applicants/me/medical-referral-pdf/

    Surat Pengantar Medical Check Up — hanya jika ada lamaran berstatus Diterima.
    """

    permission_classes = [IsAuthenticated, IsApplicant]

    def get(self, request):
        from main.models import ApplicationStatus, JobApplication

        try:
            profile = ApplicantProfile.objects.select_related(
                "user",
                "birth_place",
                "district",
            ).prefetch_related(
                "job_applications__job__company",
            ).get(user=request.user)
        except ApplicantProfile.DoesNotExist:
            return Response(
                error_response(
                    detail="Profil pelamar tidak ditemukan.",
                    code=ApiCode.NOT_FOUND,
                ),
                status=status.HTTP_404_NOT_FOUND,
            )

        if not JobApplication.objects.filter(
            applicant=profile,
            status=ApplicationStatus.DITERIMA,
        ).exists():
            return Response(
                error_response(
                    detail="Surat pengantar medical hanya tersedia saat Anda berada di tahap Diterima.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_403_FORBIDDEN,
            )

        try:
            pdf_bytes = generate_pengantar_medical_pdf(profile)
        except Exception as e:
            return Response(
                error_response(
                    detail=f"Gagal membuat PDF: {str(e)}",
                    code=ApiCode.INTERNAL_ERROR,
                ),
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        safe_name = (profile.user.full_name or "cpmi").replace(" ", "_")
        filename = f"Pengantar_Medical_{safe_name}.pdf"
        response = HttpResponse(pdf_bytes, content_type="application/pdf")
        response["Content-Disposition"] = f'attachment; filename="{filename}"'
        return response
