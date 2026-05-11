"""
API views untuk main app.
Admin-side CRUD: News, LowonganKerja, LamaranBatch, JobApplication (read).
Applicant self-service: my applications, confirm attendance.
Public endpoints: published news, OPEN jobs.
Company/Staff self-service: read-only views of their own data.
"""

from django.db.models import Prefetch
from django.shortcuts import get_object_or_404
from django.db.models import Count, Q
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.filters import SearchFilter, OrderingFilter

from account.permissions import (
    IsBackofficeAdmin,
    IsMasterAdmin,
    IsApplicant,
    IsCompany,
    IsStaff,
)
from account.api_responses import success_response, error_response, ApiCode
from account.models import ApplicantDocument, ApplicantProfile, ApplicantVerificationStatus, CustomUser, UserRole
from account.serializers import _staff_rujukan_display_name
from account.pagination import StandardResultsSetPagination
from account.services.export import (
    EXPORT_SELECT_RELATED_APPLICANT_PROFILE_REGIONS,
    generate_applicants_excel,
)

from .eligible_applicants_query import (
    applicant_ktp_address_line,
    apply_eligible_applicant_filters,
)
from .models import (
    ApplicationStatus,
    ApplicationStatusHistory,
    BatchAnnouncement,
    InterviewCohort,
    InterviewCohortAnnouncement,
    JobApplication,
    JobStatus,
    LamaranBatch,
    LowonganKerja,
    News,
    NewsStatus,
)
from .serializers import (
    ApplicantSearchSerializer,
    ApplicationAttendanceConfirmSerializer,
    ApplicationDocumentStepConfirmSerializer,
    BatchAdvanceToCohortSerializer,
    BulkApplicationTransitionSerializer,
    ApplicationTransitionSerializer,
    BatchAnnouncementCreateSerializer,
    BatchAnnouncementSerializer,
    BatchCheckEligibilitySerializer,
    BatchScheduleSerializer,
    CohortBulkTransitionSerializer,
    GroupAssignSerializer,
    InterviewCohortAnnouncementCreateSerializer,
    InterviewCohortAnnouncementSerializer,
    InterviewCohortCreateSerializer,
    InterviewCohortScheduleSerializer,
    InterviewCohortSerializer,
    InterviewCohortUpdateSerializer,
    JobApplicationListSerializer,
    JobApplicationSerializer,
    LamaranBatchCreateSerializer,
    LamaranBatchSerializer,
    LamaranBatchUpdateSerializer,
    LowonganKerjaSerializer,
    MoveApplicationsToBatchSerializer,
    MoveApplicationsToCohortSerializer,
    NewsSerializer,
)
from .services import ApplicationService, CooldownError, EligibilityError, TransitionError


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
        return News.objects.select_related("created_by")


class LowonganKerjaViewSet(viewsets.ModelViewSet):
    """
    CRUD lowongan kerja untuk admin/backoffice.
    Admin Utama mengubah master data; Admin operator hanya baca (list/detail).
    """

    http_method_names = ["get", "post", "put", "patch", "delete", "head", "options"]
    serializer_class = LowonganKerjaSerializer
    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["status", "employment_type", "company", "location_country"]
    search_fields = ["title", "description", "requirements", "company__company_name"]
    ordering_fields = ["posted_at", "deadline", "created_at", "updated_at", "title"]
    ordering = ["-posted_at", "-created_at"]

    def get_permissions(self):
        if self.action in ("list", "retrieve"):
            return [IsBackofficeAdmin()]
        return [IsMasterAdmin()]

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
    pagination_class = StandardResultsSetPagination
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
    pagination_class = StandardResultsSetPagination
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
# LamaranBatch — Admin batch management
# ---------------------------------------------------------------------------


def _first_serializer_error_detail(errors: dict) -> str | None:
    """Return the first string message from DRF serializer.errors for API detail."""
    if not errors:
        return None
    for val in errors.values():
        if isinstance(val, list) and val:
            first = val[0]
            if isinstance(first, dict):
                sub = _first_serializer_error_detail(first)
                if sub:
                    return sub
            else:
                return str(first)
        elif isinstance(val, str):
            return val
        elif isinstance(val, dict):
            sub = _first_serializer_error_detail(val)
            if sub:
                return sub
    return None


class LamaranBatchViewSet(viewsets.ModelViewSet):
    """
    CRUD + custom actions untuk LamaranBatch (admin/backoffice).

    Standard CRUD:
      GET    /api/batches/             — list all batches (newest first)
      POST   /api/batches/             — create a new batch
      GET    /api/batches/{id}/        — batch detail + counts
      PATCH  /api/batches/{id}/        — update name/notes on the batch
      DELETE /api/batches/{id}/        — delete batch + semua lamaran di dalamnya (hanya Admin Utama / MASTER_ADMIN)

    Custom actions:
      GET   /api/batches/{id}/eligible-applicants/?q=   — applicant search table with eligibility
      POST  /api/batches/{id}/check-eligibility/         — dry-run: check selected applicant IDs
      POST  /api/batches/{id}/assign/                    — bulk assign selected applicants
      PATCH /api/batches/{id}/schedule/                  — set date/location for pra_seleksi or interview
      POST  /api/batches/{id}/bulk-transition/           — advance all apps in batch at once
    """

    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["job", "tahap_order"]
    search_fields = ["name", "notes", "tahap_label", "job__title"]
    ordering_fields = ["created_at", "pra_seleksi_date", "tahap_order"]
    ordering = ["job", "tahap_order", "-created_at"]

    def get_permissions(self):
        if self.action == "destroy":
            return [IsMasterAdmin()]
        return [IsBackofficeAdmin()]

    def get_serializer_class(self):
        if self.action == "create":
            return LamaranBatchCreateSerializer
        if self.action in ("update", "partial_update"):
            return LamaranBatchUpdateSerializer
        return LamaranBatchSerializer

    def get_queryset(self):
        return (
            LamaranBatch.objects.select_related("job", "job__company", "created_by")
            .annotate(
                _annotated_applicant_count=Count("applications", distinct=True),
                _annotated_pra_seleksi_count=Count(
                    "applications",
                    filter=Q(applications__status=ApplicationStatus.PRA_SELEKSI),
                    distinct=True,
                ),
                _annotated_advanced_count=Count(
                    "applications",
                    filter=Q(
                        applications__status__in=[
                            ApplicationStatus.INTERVIEW,
                            ApplicationStatus.DITERIMA,
                            ApplicationStatus.BERANGKAT,
                            ApplicationStatus.SELESAI,
                        ]
                    ),
                    distinct=True,
                ),
                _annotated_rejected_count=Count(
                    "applications",
                    filter=Q(applications__status=ApplicationStatus.DITOLAK),
                    distinct=True,
                ),
                _annotated_diterima_count=Count(
                    "applications",
                    filter=Q(applications__status=ApplicationStatus.DITERIMA),
                    distinct=True,
                ),
                _annotated_confirmed_pra_seleksi_count=Count(
                    "applications",
                    filter=Q(applications__pra_seleksi_confirmed_at__isnull=False),
                    distinct=True,
                ),
                _annotated_confirmed_interview_count=Count(
                    "applications",
                    filter=Q(applications__interview_confirmed_at__isnull=False),
                    distinct=True,
                ),
                _annotated_pengumpulan_dokumen_confirmed_count=Count(
                    "applications",
                    filter=Q(
                        applications__status=ApplicationStatus.DITERIMA,
                        applications__attendance_by_stage__has_key=ApplicationStatus.DITERIMA,
                    ),
                    distinct=True,
                ),
            )
        )

    def _get_batch_for_action(self, pk):
        """
        Resolve the batch by primary key without applying filter_queryset().

        Custom actions receive the same query params as list views (e.g. search,
        ordering, job). SearchFilter/OrderingFilter/DjangoFilterBackend would
        narrow LamaranBatch.objects and make get_object() return 404 even when
        the batch exists — breaking endpoints like eligible-applicants?q=...
        """
        return get_object_or_404(
            LamaranBatch.objects.select_related("job", "job__company", "created_by")
            .prefetch_related("applications"),
            pk=pk,
        )

    def create(self, request, *args, **kwargs):
        serializer = LamaranBatchCreateSerializer(data=request.data)
        if not serializer.is_valid():
            msg = _first_serializer_error_detail(serializer.errors) or "Data tidak valid."
            return Response(
                error_response(
                    detail=msg,
                    code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        vd = serializer.validated_data
        job = vd["job"]
        tahap_order = vd.get("tahap_order")
        if tahap_order is None:
            # Default: next tahapan number for this job.
            existing_max = (
                LamaranBatch.objects.filter(job=job)
                .order_by("-tahap_order").values_list("tahap_order", flat=True).first()
            )
            tahap_order = (existing_max or 0) + 1

        batch = LamaranBatch.objects.create(
            job=job,
            name=vd["name"],
            notes=vd.get("notes", ""),
            tahap_order=tahap_order,
            tahap_label=vd.get("tahap_label", ""),
            created_by=request.user,
        )
        out = LamaranBatchSerializer(
            self.get_queryset().get(pk=batch.pk),
            context={"request": request},
        )
        return Response(
            success_response(data=out.data, detail="Batch berhasil dibuat."),
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=["get"], url_path="eligible-applicants")
    def eligible_applicants(self, request, pk=None):
        """
        GET /api/batches/{id}/eligible-applicants/?q=...

        Full-text search `q`: full_name, email, NIK, referrer name/email/code.

        Extra filters / ordering: see eligible_applicants_query.apply_eligible_applicant_filters.

        Each row includes an `is_eligible` flag and `ineligible_reason`.

        The admin uses this table to select applicants before `assign/` or `check-eligibility/`.
        """
        self._get_batch_for_action(pk)
        q = request.query_params.get("q", "").strip()

        qs = (
            ApplicantProfile.objects.select_related(
                "user",
                "referrer",
                "province",
                "district",
                "district__province",
                "village",
                "village__district",
                "village__district__regency",
                "village__district__regency__province",
            )
            .filter(
                user__is_active=True,
                verification_status__in=[
                    ApplicantVerificationStatus.DRAFT,
                    ApplicantVerificationStatus.SUBMITTED,
                    ApplicantVerificationStatus.ACCEPTED,
                ],
            )
        )

        if q:
            from django.db.models import Q as DQ
            qs = qs.filter(
                DQ(user__full_name__icontains=q)
                | DQ(user__email__icontains=q)
                | DQ(nik__icontains=q)
                | DQ(referrer__full_name__icontains=q)
                | DQ(referrer__email__icontains=q)
                | DQ(referrer__referral_code__icontains=q)
            )

        qs, filter_err = apply_eligible_applicant_filters(qs, request)
        if filter_err:
            return Response(
                error_response(
                    detail=filter_err,
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Paginate
        paginator = StandardResultsSetPagination()
        page = paginator.paginate_queryset(qs, request, view=self)

        # Bulk-check eligibility for the current page only (2 queries)
        profiles_on_page = list(page)
        eligibility_map = {
            r.applicant_id: r
            for r in ApplicationService.bulk_check_eligibility(
                applicant_profiles=profiles_on_page,
            )
        }

        rows = []
        for profile in profiles_on_page:
            result = eligibility_map.get(profile.pk)
            ref = profile.referrer if getattr(profile, "referrer_id", None) else None
            ref_name = ""
            ref_code = ""
            if ref:
                ref_name = _staff_rujukan_display_name(
                    full_name=(getattr(ref, "full_name", None) or "").strip(),
                    email=getattr(ref, "email", None) or "",
                )
                ref_code = (getattr(ref, "referral_code", None) or "").strip()
            rows.append({
                "id": profile.pk,
                "nik": profile.nik or "",
                "full_name": profile.user.full_name if profile.user else "",
                "email": profile.user.email if profile.user else "",
                "phone": profile.contact_phone or "",
                "domicile": applicant_ktp_address_line(profile),
                "gender": profile.gender or "",
                "religion": profile.religion or "",
                "education_level": profile.education_level or "",
                "marital_status": profile.marital_status or "",
                "writing_hand": profile.writing_hand or "",
                "height_cm": profile.height_cm,
                "weight_kg": profile.weight_kg,
                "birth_date": profile.birth_date.isoformat()
                if getattr(profile, "birth_date", None)
                else None,
                "wears_glasses": profile.wears_glasses,
                "has_passport": profile.has_passport,
                "referrer_display_name": ref_name,
                "referrer_code": ref_code,
                "is_eligible": result.eligible if result else True,
                "ineligible_reason": result.reason if result and not result.eligible else None,
            })

        return paginator.get_paginated_response(rows)

    @action(detail=True, methods=["post"], url_path="check-eligibility")
    def check_eligibility(self, request, pk=None):
        """
        POST /api/batches/{id}/check-eligibility/
        Body: { "applicant_ids": [1, 2, 3] }

        Dry-run: returns eligibility result per selected applicant_id.
        No applications are created. Use this before calling `assign/` to
        preview which applicants will be skipped due to ineligibility.
        """
        self._get_batch_for_action(pk)
        serializer = BatchCheckEligibilitySerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail="Data tidak valid.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        profiles = serializer.validated_data["applicant_ids"]
        results = ApplicationService.bulk_check_eligibility(
            applicant_profiles=profiles,
        )

        data = [
            {
                "applicant_id": r.applicant_id,
                "eligible": r.eligible,
                "reason": r.reason,
            }
            for r in results
        ]

        return Response(success_response(data=data, detail="Hasil pengecekan kelayakan."))

    @action(detail=True, methods=["post"], url_path="assign")
    def assign(self, request, pk=None):
        """
        POST /api/batches/{id}/assign/
        Body: { "applicant_ids": [1, 2, 3], "note": "..." }

        Admin selects applicants from the eligible-applicants table and submits
        their IDs here.  The service layer bulk-creates applications (bulk_create,
        no N+1) and re-checks eligibility atomically, skipping ineligible ones.

        Response includes how many were assigned and which were skipped.
        """
        batch = self._get_batch_for_action(pk)
        serializer = GroupAssignSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail="Data tidak valid.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        profiles = serializer.validated_data["applicant_ids"]
        note = serializer.validated_data.get("note", "")

        result = ApplicationService.group_assign(
            batch=batch,
            applicant_profiles=profiles,
            assigned_by=request.user,
            note=note,
        )

        return Response(
            success_response(
                data={
                    "assigned_count": len(result.assigned),
                    "skipped_count": len(result.skipped),
                    "skipped": [
                        {
                            "applicant_id": s.applicant_id,
                            "reason": s.reason,
                        }
                        for s in result.skipped
                    ],
                },
                detail=(
                    f"{len(result.assigned)} pelamar berhasil ditambahkan ke batch."
                    + (
                        f" {len(result.skipped)} dilewati karena tidak memenuhi syarat."
                        if result.skipped else ""
                    )
                ),
            ),
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=["patch"], url_path="schedule")
    def schedule(self, request, pk=None):
        """
        PATCH /api/batches/{id}/schedule/
        Body: { "stage": "pra_seleksi", "date": "...", "location": "...", "notes": "..." }

        Hanya stage `pra_seleksi` yang valid pada batch — jadwal interview kini
        dikelola pada `InterviewCohort`. Permintaan dengan stage `interview`
        ditolak untuk mencegah kebocoran skema lama.
        """
        batch = self._get_batch_for_action(pk)
        serializer = BatchScheduleSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail="Data tidak valid.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        if serializer.validated_data["stage"] != "pra_seleksi":
            return Response(
                error_response(
                    detail=(
                        "Jadwal interview kini dikelola pada InterviewCohort. "
                        "Gunakan PATCH /api/interview-cohorts/{id}/schedule/."
                    ),
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            ApplicationService.schedule_stage(
                batch=batch,
                stage="pra_seleksi",
                stage_date=serializer.validated_data["date"],
                location=serializer.validated_data.get("location", ""),
                notes=serializer.validated_data.get("notes", ""),
            )
        except ValueError as e:
            return Response(
                error_response(detail=str(e), code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        out = LamaranBatchSerializer(
            self.get_queryset().get(pk=batch.pk),
            context={"request": request},
        )
        return Response(success_response(data=out.data, detail="Jadwal berhasil disimpan."))

    @action(detail=True, methods=["post"], url_path="bulk-transition")
    def bulk_transition(self, request, pk=None):
        """
        POST /api/batches/{id}/bulk-transition/
        Body: {
          "status": "INTERVIEW" | "DITOLAK",
          "interview_cohort": <id>,   # required when status=INTERVIEW
          "note": "..."
        }

        Memindahkan SEMUA pelamar PRA_SELEKSI di batch ini sekaligus.
        Dari batch hanya boleh ke INTERVIEW (butuh cohort) atau DITOLAK.
        Untuk transisi DITERIMA/BERANGKAT/SELESAI gunakan endpoint cohort.
        """
        batch = self._get_batch_for_action(pk)
        serializer = ApplicationTransitionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail=_first_serializer_error_detail(serializer.errors) or "Data tidak valid.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            updated = ApplicationService.bulk_transition(
                batch=batch,
                new_status=serializer.validated_data["status"],
                actor=request.user,
                note=serializer.validated_data.get("note", ""),
                placement_end_date=serializer.validated_data.get("placement_end_date"),
                interview_cohort=serializer.validated_data.get("interview_cohort"),
            )
        except TransitionError as e:
            return Response(
                error_response(detail=str(e), code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            success_response(
                data={"updated_count": len(updated)},
                detail=f"{len(updated)} lamaran berhasil dipindahkan ke status '{serializer.validated_data['status']}'.",
            )
        )

    @action(detail=True, methods=["post"], url_path="advance-to-interview")
    def advance_to_interview(self, request, pk=None):
        """
        POST /api/batches/{id}/advance-to-interview/
        Body: {
          "interview_cohort": <id>,
          "application_ids": [<id>, ...] (optional; default = semua PRA_SELEKSI di batch),
          "note": "..."
        }

        Helper khusus admin: pilih sebagian (atau semua) pelamar PRA_SELEKSI
        di batch ini lalu kirim ke cohort interview yang dipilih.
        Mengembalikan jumlah yang berhasil dipindah dan daftar yang gagal.
        """
        batch = self._get_batch_for_action(pk)
        serializer = BatchAdvanceToCohortSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail=_first_serializer_error_detail(serializer.errors) or "Data tidak valid.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        cohort = serializer.validated_data["interview_cohort"]
        ids = serializer.validated_data.get("application_ids")
        note = serializer.validated_data.get("note", "")

        if cohort.job_id != batch.job_id:
            return Response(
                error_response(
                    detail="Cohort yang dipilih bukan untuk lowongan yang sama dengan batch.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        qs = batch.applications.filter(status=ApplicationStatus.PRA_SELEKSI)
        if ids:
            qs = qs.filter(pk__in=ids)
        applications = list(qs)

        updated_ids: list[int] = []
        failed: list[dict] = []
        for app in applications:
            try:
                ApplicationService.transition(
                    application=app,
                    new_status=ApplicationStatus.INTERVIEW,
                    actor=request.user,
                    note=note,
                    interview_cohort=cohort,
                )
                updated_ids.append(app.pk)
            except TransitionError as e:
                failed.append({"application_id": app.pk, "reason": str(e)})

        return Response(
            success_response(
                data={
                    "updated_count": len(updated_ids),
                    "failed_count": len(failed),
                    "updated_ids": updated_ids,
                    "failed": failed,
                    "interview_cohort": cohort.pk,
                },
                detail=(
                    f"{len(updated_ids)} pelamar berhasil dipindah ke sesi interview "
                    f"'{cohort.name}'."
                ),
            )
        )

    @action(detail=True, methods=["post"], url_path="move-applicants")
    def move_applicants(self, request, pk=None):
        """
        POST /api/batches/{id}/move-applicants/
        Body: { "target_batch": <id>, "application_ids": [...], "note": "..." }

        Pindahkan pelamar PRA_SELEKSI ke batch (tahapan) lain di lowongan
        yang sama. Status tidak berubah; ini hanya pemindahan wadah.
        """
        batch = self._get_batch_for_action(pk)
        serializer = MoveApplicationsToBatchSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail=_first_serializer_error_detail(serializer.errors) or "Data tidak valid.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        target_batch = serializer.validated_data["target_batch"]
        if target_batch.job_id != batch.job_id:
            return Response(
                error_response(
                    detail="Batch tujuan bukan untuk lowongan yang sama.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        if target_batch.pk == batch.pk:
            return Response(
                error_response(
                    detail="Batch tujuan tidak boleh sama dengan batch asal.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        ids = serializer.validated_data["application_ids"]
        applications = list(batch.applications.filter(pk__in=ids))

        try:
            ApplicationService.move_applications_to_batch(
                applications=applications,
                target_batch=target_batch,
                actor=request.user,
            )
        except TransitionError as e:
            return Response(
                error_response(detail=str(e), code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            success_response(
                data={
                    "moved_count": len(applications),
                    "target_batch": target_batch.pk,
                },
                detail=(
                    f"{len(applications)} pelamar dipindahkan ke batch "
                    f"'{target_batch.name}'."
                ),
            )
        )

    @action(detail=True, methods=["get", "post"], url_path="announcements")
    def announcements(self, request, pk=None):
        """
        GET  /api/batches/{id}/announcements/  — list announcements for this batch (admin).
        POST /api/batches/{id}/announcements/  — create announcement + optional recipient_config.

        Pelamar hanya melihat pengumuman yang ditujukan ke tahapan mereka
        (GET /api/applicants/me/applications/{id}/announcements/).
        """
        batch = self._get_batch_for_action(pk)

        if request.method == "GET":
            qs = (
                BatchAnnouncement.objects
                .filter(batch=batch)
                .select_related("created_by")
                .order_by("-created_at")
            )
            serializer = BatchAnnouncementSerializer(qs, many=True, context={"request": request})
            return Response(success_response(data=serializer.data))

        # POST — create announcement
        serializer = BatchAnnouncementCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail="Data tidak valid.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        vd = serializer.validated_data
        announcement = BatchAnnouncement.objects.create(
            batch=batch,
            title=vd["title"],
            body=vd["body"],
            recipient_config=vd["recipient_config"],
            created_by=request.user,
        )
        from .batch_announcement_recipients import recipient_user_count

        n = recipient_user_count(batch, announcement.recipient_config)
        detail_msg = (
            f"Pengumuman dibuat dan dikirim ke {n} pelamar."
            if n
            else (
                "Pengumuman dibuat. Tidak ada pelamar yang cocok dengan filter penerima "
                "(notifikasi tidak dikirim)."
            )
        )
        return Response(
            success_response(
                data=BatchAnnouncementSerializer(announcement, context={"request": request}).data,
                detail=detail_msg,
            ),
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=["post"], url_path="announcements/preview-recipients")
    def announcements_preview_recipients(self, request, pk=None):
        """
        POST /api/batches/{id}/announcements/preview-recipients/
        Body: { "recipient_config": { "selection_type": "all_active" | "statuses", ... } }

        Returns how many distinct pelamar would receive the announcement for this batch.
        """
        batch = self._get_batch_for_action(pk)
        from .batch_announcement_recipients import (
            recipient_user_count,
            validate_recipient_config,
        )

        config = request.data.get("recipient_config")
        if config is None:
            return Response(
                error_response(
                    detail="recipient_config diperlukan.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        ok, err = validate_recipient_config(config)
        if not ok:
            return Response(
                error_response(detail=err, code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )
        count = recipient_user_count(batch, config)
        return Response(
            success_response(
                data={"recipient_count": count},
                detail=f"Preview: {count} pelamar akan menerima pengumuman.",
            )
        )

    @action(detail=True, methods=["get"], url_path="export-excel")
    def export_excel(self, request, pk=None):
        """
        GET /api/batches/{id}/export-excel/

        Query params (optional):
          status — repeat untuk setiap tahapan lamaran yang ingin diekspor,
                   mis. ?status=PRA_SELEKSI&status=INTERVIEW
          Tanpa parameter: semua lamaran di batch (semua tahapan).

        Returns an .xlsx file containing applicant biodata for matching
        JobApplications. Each row = one applicant.

        Kolom-kolom mengikuti format export pelamar global
        (lihat account.services.export.EXPORT_COLUMNS) supaya konsisten.
        """
        from django.http import HttpResponse

        batch = self._get_batch_for_action(pk)

        # Ambil semua user pelamar yang termasuk dalam batch ini
        applications = (
            JobApplication.objects.filter(batch=batch)
            .select_related("applicant__user")
            .order_by("applicant__user__full_name")
        )

        status_params = request.query_params.getlist("status")
        if status_params:
            valid_codes = {c[0] for c in ApplicationStatus.choices}
            unknown = [s for s in status_params if s not in valid_codes]
            if unknown:
                return Response(
                    error_response(
                        detail=f"Parameter status tidak valid: {', '.join(unknown)}",
                        code=ApiCode.VALIDATION_ERROR,
                    ),
                    status=status.HTTP_400_BAD_REQUEST,
                )
            applications = applications.filter(status__in=status_params)
        applicant_user_ids = (
            applications.values_list("applicant__user_id", flat=True).distinct()
        )

        applicants_qs = (
            CustomUser.objects.filter(
                id__in=applicant_user_ids,
                role=UserRole.APPLICANT,
            )
            .select_related(*EXPORT_SELECT_RELATED_APPLICANT_PROFILE_REGIONS)
            .prefetch_related(
                "applicant_profile__work_experiences",
                "applicant_profile__documents__document_type",
                "applicant_profile__documents__reviewed_by",
            )
            .order_by("applicant_profile__created_at")
        )

        excel_file = generate_applicants_excel(applicants_qs, request)

        safe_filename = "".join(
            c for c in batch.name if c.isalnum() or c in (" ", "-", "_")
        ).strip().replace(" ", "_")
        filename = f"pelamar_{safe_filename}.xlsx"

        response = HttpResponse(
            excel_file.read(),
            content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
        response["Content-Disposition"] = f'attachment; filename="{filename}"'
        return response


# ---------------------------------------------------------------------------
# InterviewCohortViewSet — admin operations for interview-and-onwards
# ---------------------------------------------------------------------------


class InterviewCohortViewSet(viewsets.ModelViewSet):
    """
    CRUD + custom actions for `InterviewCohort` (admin/backoffice).

    Standard CRUD:
      GET    /api/interview-cohorts/             — list (filterable by job, is_active)
      POST   /api/interview-cohorts/             — create cohort
      GET    /api/interview-cohorts/{id}/        — detail + counts
      PATCH  /api/interview-cohorts/{id}/        — update name/notes/schedule/is_active
      DELETE /api/interview-cohorts/{id}/        — delete (Master Admin only; only if no apps)

    Custom actions:
      PATCH /api/interview-cohorts/{id}/schedule/        — set/clear schedule
      POST  /api/interview-cohorts/{id}/bulk-transition/ — DITERIMA / BERANGKAT / SELESAI / DITOLAK
      POST  /api/interview-cohorts/{id}/move-applicants/ — re-cohort applicants
      GET   /api/interview-cohorts/{id}/announcements/   — list cohort announcements
      POST  /api/interview-cohorts/{id}/announcements/   — create cohort announcement
      POST  /api/interview-cohorts/{id}/announcements/preview-recipients/ — count preview
      GET   /api/interview-cohorts/{id}/export-excel/    — export applicants
    """

    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["job", "is_active"]
    search_fields = ["name", "notes", "job__title"]
    ordering_fields = ["created_at", "interview_date", "name"]
    ordering = ["-created_at"]

    def get_permissions(self):
        if self.action == "destroy":
            return [IsMasterAdmin()]
        return [IsBackofficeAdmin()]

    def get_serializer_class(self):
        if self.action == "create":
            return InterviewCohortCreateSerializer
        if self.action in ("update", "partial_update"):
            return InterviewCohortUpdateSerializer
        return InterviewCohortSerializer

    def get_queryset(self):
        return (
            InterviewCohort.objects
            .select_related("job", "job__company", "created_by")
            .annotate(
                _annotated_applicant_count=Count("applications", distinct=True),
                _annotated_interview_count=Count(
                    "applications",
                    filter=Q(applications__status=ApplicationStatus.INTERVIEW),
                    distinct=True,
                ),
                _annotated_cadangan_count=Count(
                    "applications",
                    filter=Q(applications__status=ApplicationStatus.CADANGAN),
                    distinct=True,
                ),
                _annotated_diterima_count=Count(
                    "applications",
                    filter=Q(applications__status=ApplicationStatus.DITERIMA),
                    distinct=True,
                ),
                _annotated_berangkat_count=Count(
                    "applications",
                    filter=Q(applications__status=ApplicationStatus.BERANGKAT),
                    distinct=True,
                ),
                _annotated_selesai_count=Count(
                    "applications",
                    filter=Q(applications__status=ApplicationStatus.SELESAI),
                    distinct=True,
                ),
                _annotated_ditolak_count=Count(
                    "applications",
                    filter=Q(applications__status=ApplicationStatus.DITOLAK),
                    distinct=True,
                ),
                _annotated_confirmed_interview_count=Count(
                    "applications",
                    filter=Q(applications__interview_confirmed_at__isnull=False),
                    distinct=True,
                ),
                _annotated_pengumpulan_dokumen_confirmed_count=Count(
                    "applications",
                    filter=Q(
                        applications__status=ApplicationStatus.DITERIMA,
                        applications__attendance_by_stage__has_key=ApplicationStatus.DITERIMA,
                    ),
                    distinct=True,
                ),
            )
        )

    def _get_cohort_for_action(self, pk):
        return get_object_or_404(
            InterviewCohort.objects
            .select_related("job", "job__company", "created_by")
            .prefetch_related("applications"),
            pk=pk,
        )

    def create(self, request, *args, **kwargs):
        serializer = InterviewCohortCreateSerializer(data=request.data)
        if not serializer.is_valid():
            msg = _first_serializer_error_detail(serializer.errors) or "Data tidak valid."
            return Response(
                error_response(
                    detail=msg,
                    code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        vd = serializer.validated_data
        cohort = ApplicationService.create_cohort(
            job=vd["job"],
            name=vd["name"],
            notes=vd.get("notes", ""),
            interview_date=vd.get("interview_date"),
            interview_location=vd.get("interview_location", ""),
            interview_notes=vd.get("interview_notes", ""),
            created_by=request.user,
        )
        out = InterviewCohortSerializer(
            self.get_queryset().get(pk=cohort.pk),
            context={"request": request},
        )
        return Response(
            success_response(data=out.data, detail="Sesi interview berhasil dibuat."),
            status=status.HTTP_201_CREATED,
        )

    def destroy(self, request, *args, **kwargs):
        cohort = self.get_object()
        if cohort.applications.exists():
            return Response(
                error_response(
                    detail=(
                        "Sesi interview ini sudah berisi pelamar dan tidak dapat "
                        "dihapus. Tandai non-aktif (is_active=false) bila ingin "
                        "menghentikan penggunaan."
                    ),
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        return super().destroy(request, *args, **kwargs)

    @action(detail=True, methods=["patch"], url_path="schedule")
    def schedule(self, request, pk=None):
        """PATCH /api/interview-cohorts/{id}/schedule/ — date / location / notes."""
        cohort = self._get_cohort_for_action(pk)
        serializer = InterviewCohortScheduleSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail=_first_serializer_error_detail(serializer.errors) or "Data tidak valid.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        ApplicationService.schedule_cohort(
            cohort=cohort,
            interview_date=serializer.validated_data.get("interview_date"),
            interview_location=serializer.validated_data.get("interview_location", ""),
            interview_notes=serializer.validated_data.get("interview_notes", ""),
        )
        out = InterviewCohortSerializer(
            self.get_queryset().get(pk=cohort.pk),
            context={"request": request},
        )
        return Response(success_response(data=out.data, detail="Jadwal interview tersimpan."))

    @action(detail=True, methods=["post"], url_path="bulk-transition")
    def bulk_transition(self, request, pk=None):
        """
        POST /api/interview-cohorts/{id}/bulk-transition/
        Body: { "status": "DITERIMA" | "BERANGKAT" | "SELESAI" | "DITOLAK", ... }

        Mengubah status SEMUA pelamar yang memenuhi syarat di cohort.
        Aturan FSM, kuota, dan kelengkapan dokumen tetap diberlakukan.
        """
        cohort = self._get_cohort_for_action(pk)
        serializer = CohortBulkTransitionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail=_first_serializer_error_detail(serializer.errors) or "Data tidak valid.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            updated = ApplicationService.cohort_bulk_transition(
                cohort=cohort,
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

        return Response(
            success_response(
                data={"updated_count": len(updated)},
                detail=(
                    f"{len(updated)} lamaran berhasil dipindahkan ke status "
                    f"'{serializer.validated_data['status']}'."
                ),
            )
        )

    @action(detail=True, methods=["post"], url_path="move-applicants")
    def move_applicants(self, request, pk=None):
        """Re-cohort: pindahkan pelamar dari cohort ini ke cohort lain (lowongan sama)."""
        cohort = self._get_cohort_for_action(pk)
        serializer = MoveApplicationsToCohortSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail=_first_serializer_error_detail(serializer.errors) or "Data tidak valid.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        target = serializer.validated_data["target_cohort"]
        if target.job_id != cohort.job_id:
            return Response(
                error_response(
                    detail="Cohort tujuan bukan untuk lowongan yang sama.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        if target.pk == cohort.pk:
            return Response(
                error_response(
                    detail="Cohort tujuan tidak boleh sama dengan cohort asal.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        ids = serializer.validated_data["application_ids"]
        applications = list(cohort.applications.filter(pk__in=ids))

        try:
            ApplicationService.move_applications_to_cohort(
                applications=applications,
                target_cohort=target,
                actor=request.user,
            )
        except TransitionError as e:
            return Response(
                error_response(detail=str(e), code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            success_response(
                data={
                    "moved_count": len(applications),
                    "target_cohort": target.pk,
                },
                detail=(
                    f"{len(applications)} pelamar dipindahkan ke sesi interview "
                    f"'{target.name}'."
                ),
            )
        )

    @action(detail=True, methods=["get", "post"], url_path="announcements")
    def announcements(self, request, pk=None):
        """List/create announcements scoped to this cohort."""
        cohort = self._get_cohort_for_action(pk)

        if request.method == "GET":
            qs = (
                InterviewCohortAnnouncement.objects
                .filter(cohort=cohort)
                .select_related("created_by")
                .order_by("-created_at")
            )
            serializer = InterviewCohortAnnouncementSerializer(
                qs, many=True, context={"request": request}
            )
            return Response(success_response(data=serializer.data))

        serializer = InterviewCohortAnnouncementCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail=_first_serializer_error_detail(serializer.errors) or "Data tidak valid.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        vd = serializer.validated_data
        announcement = InterviewCohortAnnouncement.objects.create(
            cohort=cohort,
            title=vd["title"],
            body=vd["body"],
            recipient_config=vd["recipient_config"],
            created_by=request.user,
        )
        from .batch_announcement_recipients import cohort_recipient_user_count

        n = cohort_recipient_user_count(cohort, announcement.recipient_config)
        detail_msg = (
            f"Pengumuman dibuat dan dikirim ke {n} pelamar."
            if n
            else (
                "Pengumuman dibuat. Tidak ada pelamar yang cocok dengan filter "
                "penerima (notifikasi tidak dikirim)."
            )
        )
        return Response(
            success_response(
                data=InterviewCohortAnnouncementSerializer(
                    announcement, context={"request": request}
                ).data,
                detail=detail_msg,
            ),
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=["post"], url_path="announcements/preview-recipients")
    def announcements_preview_recipients(self, request, pk=None):
        """Preview recipient count for a candidate cohort announcement."""
        cohort = self._get_cohort_for_action(pk)
        from .batch_announcement_recipients import (
            cohort_recipient_user_count,
            validate_recipient_config,
        )

        config = request.data.get("recipient_config")
        if config is None:
            return Response(
                error_response(
                    detail="recipient_config diperlukan.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )
        ok, err = validate_recipient_config(config)
        if not ok:
            return Response(
                error_response(detail=err, code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )
        count = cohort_recipient_user_count(cohort, config)
        return Response(
            success_response(
                data={"recipient_count": count},
                detail=f"Preview: {count} pelamar akan menerima pengumuman.",
            )
        )

    @action(detail=True, methods=["get"], url_path="export-excel")
    def export_excel(self, request, pk=None):
        """Export applicants in this cohort to Excel (optionally filtered by status)."""
        from django.http import HttpResponse

        cohort = self._get_cohort_for_action(pk)

        applications = (
            JobApplication.objects.filter(interview_cohort=cohort)
            .select_related("applicant__user")
            .order_by("applicant__user__full_name")
        )

        status_params = request.query_params.getlist("status")
        if status_params:
            valid_codes = {c[0] for c in ApplicationStatus.choices}
            unknown = [s for s in status_params if s not in valid_codes]
            if unknown:
                return Response(
                    error_response(
                        detail=f"Parameter status tidak valid: {', '.join(unknown)}",
                        code=ApiCode.VALIDATION_ERROR,
                    ),
                    status=status.HTTP_400_BAD_REQUEST,
                )
            applications = applications.filter(status__in=status_params)

        applicant_user_ids = (
            applications.values_list("applicant__user_id", flat=True).distinct()
        )

        applicants_qs = (
            CustomUser.objects.filter(
                id__in=applicant_user_ids,
                role=UserRole.APPLICANT,
            )
            .select_related(*EXPORT_SELECT_RELATED_APPLICANT_PROFILE_REGIONS)
            .prefetch_related(
                "applicant_profile__work_experiences",
                "applicant_profile__documents__document_type",
                "applicant_profile__documents__reviewed_by",
            )
            .order_by("applicant_profile__created_at")
        )

        excel_file = generate_applicants_excel(applicants_qs, request)

        safe_filename = "".join(
            c for c in cohort.name if c.isalnum() or c in (" ", "-", "_")
        ).strip().replace(" ", "_")
        filename = f"interview_{safe_filename}.xlsx"

        response = HttpResponse(
            excel_file.read(),
            content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
        response["Content-Disposition"] = f'attachment; filename="{filename}"'
        return response


# ---------------------------------------------------------------------------
# Job Application — Admin read + individual transitions
# ---------------------------------------------------------------------------


class JobApplicationViewSet(viewsets.ModelViewSet):
    def get_serializer_class(self):
        if self.action == "list":
            return JobApplicationListSerializer
        return JobApplicationSerializer

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["include_status_history"] = self.action == "retrieve"
        return context

    """
    Read + individual transitions for JobApplication (admin/backoffice).

    Standard:
      GET    /api/applications/          — list with filters
      GET    /api/applications/{id}/     — detail (includes status_history)
      PATCH  /api/applications/{id}/     — update notes field only
      DELETE /api/applications/{id}/     — hard delete (use sparingly)

    Custom actions:
      PATCH /api/applications/{id}/transition/   — FSM transition for one application
    """

    serializer_class = JobApplicationSerializer
    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["status", "job", "applicant", "batch", "interview_cohort"]
    search_fields = [
        "applicant__user__full_name",
        "applicant__user__email",
        "applicant__nik",
        "applicant__referrer__full_name",
        "applicant__referrer__email",
        "applicant__referrer__referral_code",
        "job__title",
    ]
    ordering_fields = ["applied_at", "status"]
    ordering = ["-applied_at"]

    def get_permissions(self):
        if self.action == "destroy":
            return [IsMasterAdmin()]
        return [IsBackofficeAdmin()]

    def get_queryset(self):
        qs = (
            JobApplication.objects
            .select_related(
                "applicant",
                "applicant__user",
                "applicant__referrer",
                "job", "job__company",
                "batch",
                "interview_cohort",
                "assigned_by",
            )
            .prefetch_related(
                Prefetch(
                    "applicant__documents",
                    queryset=ApplicantDocument.objects.filter(
                        document_type__code="paspor",
                    ).select_related("document_type"),
                    to_attr="_prefetched_paspor_docs",
                ),
            )
        )
        if self.action == "retrieve":
            qs = qs.prefetch_related("status_history__changed_by")
        return qs

    def _parse_diterima_step_param(self, request) -> str | None:
        """
        Parse and validate optional query param `diterima_step`.
        Returns normalized step code or None if not provided.
        Raises ValueError when provided but invalid.
        """
        raw = (request.query_params.get("diterima_step") or "").strip().upper()
        if not raw:
            return None
        valid_step_codes = {
            code for code, _ in ApplicationService.DOCUMENT_COLLECTION_STEP_ORDER
        }
        if raw not in valid_step_codes:
            raise ValueError(
                "Parameter diterima_step tidak valid. "
                f"Pilihan: {', '.join(sorted(valid_step_codes))}."
            )
        return raw

    def _filter_queryset_by_diterima_step(self, queryset, step_code: str):
        """
        Filter queryset to applicants currently at *step_code* within the
        DITERIMA sub-step flow.  Uses the indexed DB column for efficiency
        (O(log n) instead of the previous O(n) Python loop).
        """
        return queryset.filter(
            status=ApplicationStatus.DITERIMA,
            diterima_current_step=step_code,
        )

    def list(self, request, *args, **kwargs):
        try:
            diterima_step = self._parse_diterima_step_param(request)
        except ValueError as e:
            return Response(
                error_response(detail=str(e), code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        queryset = self.filter_queryset(self.get_queryset())
        if diterima_step:
            queryset = self._filter_queryset_by_diterima_step(queryset, diterima_step)

        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)

        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=["get"], url_path="export-excel")
    def export_excel(self, request):
        """
        GET /api/applications/export-excel/

        Export pelamar berdasarkan filter list aplikasi saat ini.
        Mendukung query params yang sama dengan endpoint list:
          - status
          - job
          - applicant
          - batch
          - interview_cohort
          - search
          - ordering
        """
        from django.http import HttpResponse

        applications = self.filter_queryset(self.get_queryset()).order_by(
            "applicant__user__full_name"
        )

        # Optional DITERIMA sub-step filter.
        # Intended for admin "Master Tahapan > Diterima" export:
        # - without parameter: export all rows from current list filter
        # - with diterima_step: export only applicants in DITERIMA where the
        #   selected step is not yet confirmed by pelamar (actionable queue).
        try:
            diterima_step = self._parse_diterima_step_param(request)
        except ValueError as e:
            return Response(
                error_response(detail=str(e), code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )
        if diterima_step:
            applications = self._filter_queryset_by_diterima_step(applications, diterima_step)

        applicant_user_ids = applications.values_list(
            "applicant__user_id", flat=True
        ).distinct()

        applicants_qs = (
            CustomUser.objects.filter(
                id__in=applicant_user_ids,
                role=UserRole.APPLICANT,
            )
            .select_related(*EXPORT_SELECT_RELATED_APPLICANT_PROFILE_REGIONS)
            .prefetch_related(
                "applicant_profile__work_experiences",
                "applicant_profile__documents__document_type",
                "applicant_profile__documents__reviewed_by",
            )
            .order_by("applicant_profile__created_at")
        )
        excel_file = generate_applicants_excel(applicants_qs, request)

        filename = "pelamar_applications_filter.xlsx"
        response = HttpResponse(
            excel_file.read(),
            content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
        response["Content-Disposition"] = f'attachment; filename="{filename}"'
        return response

    @action(detail=False, methods=["post"], url_path="bulk-advance-diterima-step")
    def bulk_advance_diterima_step(self, request):
        """
        POST /api/applications/bulk-advance-diterima-step/

        Advance a list of DITERIMA applicants to the next sub-step in the
        9-step sequential flow.  All applications must currently be in
        DITERIMA status; applications already at the last step are skipped
        and reported in the response.

        Body: { "application_ids": [1, 2, 3] }

        Response:
          {
            "advanced": [<id>, ...],      # successfully advanced
            "skipped": [<id>, ...],       # already at last step
            "errors": { "<id>": "msg" }   # other per-app errors
          }
        """
        ids = request.data.get("application_ids", [])
        if not isinstance(ids, list) or not ids:
            return Response(
                error_response(
                    detail="application_ids harus berupa list non-kosong.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Resolve applications the requester is allowed to see.
        queryset = self.get_queryset().filter(pk__in=ids)
        app_map: dict[int, JobApplication] = {app.pk: app for app in queryset}

        advanced: list[int] = []
        skipped: list[int] = []
        errors: dict[str, str] = {}

        for app_id in ids:
            try:
                app_id = int(app_id)
            except (TypeError, ValueError):
                errors[str(app_id)] = "ID tidak valid."
                continue

            app = app_map.get(app_id)
            if app is None:
                errors[str(app_id)] = "Lamaran tidak ditemukan atau tidak dapat diakses."
                continue

            try:
                ApplicationService.admin_advance_diterima_step(app, request.user)
                advanced.append(app_id)
            except TransitionError as exc:
                # Already at last step is expected; surface cleanly.
                skipped.append(app_id)
                errors[str(app_id)] = str(exc)

        return Response(
            success_response(
                data={"advanced": advanced, "skipped": skipped, "errors": errors},
                detail=(
                    f"{len(advanced)} pelamar berhasil dipindahkan ke sub-tahapan berikutnya."
                    + (f" {len(skipped)} dilewati." if skipped else "")
                ),
            ),
            status=status.HTTP_200_OK,
        )

    @action(detail=True, methods=["patch"], url_path="transition")
    def transition(self, request, pk=None):
        """
        PATCH /api/applications/{id}/transition/
        Body: {
          "status": "INTERVIEW",
          "interview_cohort": <id>,        # required when status=INTERVIEW
          "note": "...",
          "placement_end_date": "2026-12-31"
        }
        """
        application = self.get_object()

        serializer = ApplicationTransitionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail=_first_serializer_error_detail(serializer.errors) or "Data tidak valid.",
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
                interview_cohort=serializer.validated_data.get("interview_cohort"),
            )
        except TransitionError as e:
            return Response(
                error_response(detail=str(e), code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        out = JobApplicationSerializer(
            self.get_queryset().get(pk=application.pk),
            context={"request": request},
        )
        return Response(success_response(data=out.data, detail="Status lamaran diperbarui."))

    @action(detail=False, methods=["post"], url_path="bulk-transition")
    def bulk_transition(self, request):
        """
        POST /api/applications/bulk-transition/
        Body: {
          "application_ids": [1, 2, 3],
          "status": "INTERVIEW",
          "note": "...",
          "placement_end_date": "2026-12-31"
        }

        Performs selected-IDs transition in one API request.
        Returns updated_count and per-ID failures for rows that could not move.
        """
        serializer = BulkApplicationTransitionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail="Data tidak valid.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        ids = serializer.validated_data["application_ids"]
        target_status = serializer.validated_data["status"]
        note = serializer.validated_data.get("note", "")
        placement_end_date = serializer.validated_data.get("placement_end_date")
        interview_cohort = serializer.validated_data.get("interview_cohort")

        # Keep selection order so frontend can map failures predictably.
        apps_by_id = {
            app.id: app
            for app in self.get_queryset().filter(id__in=ids)
        }

        updated_ids: list[int] = []
        failed: list[dict] = []

        for app_id in ids:
            application = apps_by_id.get(app_id)
            if not application:
                failed.append(
                    {
                        "application_id": app_id,
                        "reason": "Lamaran tidak ditemukan atau tidak dapat diakses.",
                    }
                )
                continue
            try:
                ApplicationService.transition(
                    application=application,
                    new_status=target_status,
                    actor=request.user,
                    note=note,
                    placement_end_date=placement_end_date,
                    interview_cohort=interview_cohort,
                )
                updated_ids.append(app_id)
            except TransitionError as e:
                failed.append({"application_id": app_id, "reason": str(e)})
            except ValueError as e:
                failed.append({"application_id": app_id, "reason": str(e)})

        detail = (
            f"{len(updated_ids)} lamaran berhasil dipindahkan ke status '{target_status}'."
            + (
                f" {len(failed)} gagal dipindahkan."
                if failed
                else ""
            )
        )

        return Response(
            success_response(
                data={
                    "updated_count": len(updated_ids),
                    "failed_count": len(failed),
                    "updated_ids": updated_ids,
                    "failed": failed,
                },
                detail=detail,
            )
        )


# ---------------------------------------------------------------------------
# Applicant self-service
# ---------------------------------------------------------------------------


class ApplicantJobApplicationViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Self-service untuk pelamar melihat lamaran mereka sendiri.
    GET /api/applicants/me/applications/      — list own applications
    GET /api/applicants/me/applications/{id}/ — detail (includes status_history + batch schedule)

    Custom actions:
      POST /api/applicants/me/applications/{id}/confirm/ — confirm attendance at current stage
      POST /api/applicants/me/applications/{id}/complete/ — self-confirm BERANGKAT -> SELESAI
    """

    serializer_class = JobApplicationSerializer
    permission_classes = [IsApplicant]
    pagination_class = None  # Return plain list — mobile parses raw array
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ["status"]
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
            .select_related(
                "applicant",
                "applicant__user",
                "applicant__referrer",
                "job",
                "job__company",
                "batch",
                "interview_cohort",
                "assigned_by",
            )
            .prefetch_related("status_history__changed_by")
        )

    @action(detail=True, methods=["post"], url_path="confirm")
    def confirm(self, request, pk=None):
        """
        POST /api/applicants/me/applications/{id}/confirm/
        No body required.

        Pelamar mengkonfirmasi kehadiran di tahap saat ini:
        - PRA_SELEKSI → sets pra_seleksi_confirmed_at
        - INTERVIEW   → sets interview_confirmed_at
        """
        application = self.get_object()

        payload = ApplicationAttendanceConfirmSerializer(data=request.data or {})
        if not payload.is_valid():
            return Response(
                error_response(
                    detail="Data tidak valid.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors=payload.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            ApplicationService.confirm_attendance(
                application=application,
                applicant_user=request.user,
                stage=payload.validated_data.get("stage"),
            )
        except TransitionError as e:
            return Response(
                error_response(detail=str(e), code=ApiCode.PERMISSION_DENIED),
                status=status.HTTP_403_FORBIDDEN,
            )
        except ValueError as e:
            return Response(
                error_response(detail=str(e), code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        out = JobApplicationSerializer(
            self.get_queryset().get(pk=application.pk),
            context={"request": request},
        )
        return Response(success_response(data=out.data, detail="Kehadiran berhasil dikonfirmasi."))

    @action(detail=True, methods=["post"], url_path="complete")
    def complete(self, request, pk=None):
        """
        POST /api/applicants/me/applications/{id}/complete/

        Applicant self-confirms completion of overseas placement and transitions:
        BERANGKAT -> SELESAI.
        """
        application = self.get_object()
        try:
            ApplicationService.mark_placement_completed(
                application=application,
                applicant_user=request.user,
            )
        except TransitionError as e:
            return Response(
                error_response(detail=str(e), code=ApiCode.PERMISSION_DENIED),
                status=status.HTTP_403_FORBIDDEN,
            )
        except ValueError as e:
            return Response(
                error_response(detail=str(e), code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        out = JobApplicationSerializer(
            self.get_queryset().get(pk=application.pk),
            context={"request": request},
        )
        return Response(
            success_response(
                data=out.data,
                detail="Status lamaran berhasil dikonfirmasi menjadi Selesai.",
            )
        )

    @action(detail=True, methods=["post"], url_path="confirm-step")
    def confirm_step(self, request, pk=None):
        """
        POST /api/applicants/me/applications/{id}/confirm-step/
        Body: { "step": "<STEP_CODE>" }

        Pelamar mengkonfirmasi satu langkah pengumpulan dokumen dalam tahap Diterima.
        Langkah harus sudah siap (data diisi oleh admin) sebelum bisa dikonfirmasi.
        Konfirmasi bersifat idempoten — langkah yang sudah dikonfirmasi tidak berubah.

        Valid step codes:
          MASUK_BERKAS_ASLI, MEDICAL, BUAT_ID_PEKERJA, BUAT_PASPOR, FWCMS,
          PSIKOLOGI_TEST, PAP_BP3MI, PDO_KILANG, PERSIAPAN_KEBERANGKATAN
        """
        application = self.get_object()

        payload = ApplicationDocumentStepConfirmSerializer(data=request.data or {})
        if not payload.is_valid():
            return Response(
                error_response(
                    detail="Data tidak valid.",
                    code=ApiCode.VALIDATION_ERROR,
                    errors=payload.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            ApplicationService.confirm_document_step(
                application=application,
                applicant_user=request.user,
                step_code=payload.validated_data["step"],
            )
        except TransitionError as e:
            return Response(
                error_response(detail=str(e), code=ApiCode.PERMISSION_DENIED),
                status=status.HTTP_403_FORBIDDEN,
            )
        except ValueError as e:
            return Response(
                error_response(detail=str(e), code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )

        out = JobApplicationSerializer(
            self.get_queryset().get(pk=application.pk),
            context={"request": request},
        )
        return Response(
            success_response(data=out.data, detail="Langkah berhasil dikonfirmasi.")
        )

    @action(detail=True, methods=["get"], url_path="announcements")
    def announcements(self, request, pk=None):
        """
        GET /api/applicants/me/applications/{id}/announcements/

        Returns broadcast announcements relevant to this application:
          - announcements from the application's pra-seleksi `batch`,
          - announcements from the application's `interview_cohort` (if any),
        merged and ordered newest-first.

        Backward-compatible payload shape: each item still carries
        `id, title, body, recipient_config, created_by, created_by_name,
        created_at` (mobile reads this same shape). New keys: `kind`
        ("batch" or "cohort") and `source_id` for clients that want to
        differentiate, but old clients can ignore them safely.
        """
        application = self.get_object()

        from .batch_announcement_recipients import (
            announcement_visible_for_application,
            cohort_announcement_visible_for_application,
        )

        items: list[dict] = []

        if application.batch_id is not None:
            batch_qs = (
                BatchAnnouncement.objects.filter(batch_id=application.batch_id)
                .select_related("created_by")
                .order_by("-created_at")
            )
            for ann in batch_qs:
                if not announcement_visible_for_application(ann, application):
                    continue
                data = BatchAnnouncementSerializer(ann, context={"request": request}).data
                data["kind"] = "batch"
                data["source_id"] = application.batch_id
                items.append(data)

        if application.interview_cohort_id is not None:
            cohort_qs = (
                InterviewCohortAnnouncement.objects
                .filter(cohort_id=application.interview_cohort_id)
                .select_related("created_by")
                .order_by("-created_at")
            )
            for ann in cohort_qs:
                if not cohort_announcement_visible_for_application(ann, application):
                    continue
                data = InterviewCohortAnnouncementSerializer(
                    ann, context={"request": request}
                ).data
                data["kind"] = "cohort"
                data["source_id"] = application.interview_cohort_id
                # Re-key `cohort` to keep the older `batch` field present so
                # very old mobile parsers don't choke on missing key.
                data.setdefault("batch", None)
                items.append(data)

        items.sort(key=lambda x: x.get("created_at") or "", reverse=True)
        return Response(success_response(data=items))


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
            .select_related("applicant", "applicant__user", "job", "job__company", "batch", "assigned_by")
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

