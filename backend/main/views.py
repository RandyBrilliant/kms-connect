"""
API views untuk main app.
Admin-side CRUD: News, LowonganKerja, LamaranBatch, JobApplication (read).
Applicant self-service: my applications, confirm attendance.
Public endpoints: published news, OPEN jobs.
Company/Staff self-service: read-only views of their own data.
"""

from django.shortcuts import get_object_or_404
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
from account.models import ApplicantProfile, ApplicantVerificationStatus, CustomUser, UserRole
from account.serializers import _staff_rujukan_display_name
from account.pagination import StandardResultsSetPagination
from account.services.export import generate_applicants_excel

from .models import (
    ApplicationStatus,
    ApplicationStatusHistory,
    BatchAnnouncement,
    JobApplication,
    JobStatus,
    LamaranBatch,
    LowonganKerja,
    News,
    NewsStatus,
)
from .serializers import (
    ApplicantSearchSerializer,
    ApplicationTransitionSerializer,
    BatchAnnouncementCreateSerializer,
    BatchAnnouncementSerializer,
    BatchCheckEligibilitySerializer,
    BatchScheduleSerializer,
    GroupAssignSerializer,
    JobApplicationSerializer,
    LamaranBatchCreateSerializer,
    LamaranBatchSerializer,
    LowonganKerjaSerializer,
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
      DELETE /api/batches/{id}/        — delete batch (only if has no applications)

    Custom actions:
      GET   /api/batches/{id}/eligible-applicants/?q=   — applicant search table with eligibility
      POST  /api/batches/{id}/check-eligibility/         — dry-run: check selected applicant IDs
      POST  /api/batches/{id}/assign/                    — bulk assign selected applicants
      PATCH /api/batches/{id}/schedule/                  — set date/location for pra_seleksi or interview
      POST  /api/batches/{id}/bulk-transition/           — advance all apps in batch at once
    """

    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["job"]
    search_fields = ["name", "notes", "job__title"]
    ordering_fields = ["created_at", "pra_seleksi_date", "interview_date"]
    ordering = ["-created_at"]

    def get_serializer_class(self):
        if self.action == "create":
            return LamaranBatchCreateSerializer
        return LamaranBatchSerializer

    def get_queryset(self):
        return (
            LamaranBatch.objects.select_related("job", "job__company", "created_by")
            .prefetch_related("applications")
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
        batch = ApplicationService.create_batch(
            job=serializer.validated_data["job"],
            name=serializer.validated_data["name"],
            notes=serializer.validated_data.get("notes", ""),
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

        Returns a paginated table of ApplicantProfiles filtered by the search
        query `q` (searches full_name, email, NIK, referrer name/email/code).
        Each row includes an
        `is_eligible` flag and an `ineligible_reason` computed via the service
        layer so the admin can see at a glance who can be added to this batch.

        The admin uses this table to select applicants (checkboxes) before
        calling the `assign` or `check-eligibility` endpoints.
        """
        self._get_batch_for_action(pk)
        q = request.query_params.get("q", "").strip()

        qs = (
            ApplicantProfile.objects.select_related("user", "referrer")
            .filter(
                user__is_active=True,
                verification_status=ApplicantVerificationStatus.ACCEPTED,
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

        qs = qs.order_by("user__full_name")

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
                "domicile": ", ".join(filter(None, [
                    getattr(profile, "domicile_kelurahan", None),
                    getattr(profile, "domicile_kecamatan", None),
                    getattr(profile, "domicile_city", None),
                ])),
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
              OR
              { "stage": "interview", "date": "...", "location": "...", "notes": "..." }

        Admin sets the date, location, and notes for either the pra-seleksi
        or interview stage so applicants know when/where to show up.
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

        try:
            ApplicationService.schedule_stage(
                batch=batch,
                stage=serializer.validated_data["stage"],
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
        Body: { "status": "INTERVIEW", "note": "...", "placement_end_date": "..." }

        Advance ALL eligible applications in this batch to the next status at once.
        Useful for moving the entire batch from PRA_SELEKSI → INTERVIEW etc.
        """
        batch = self._get_batch_for_action(pk)
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
            updated = ApplicationService.bulk_transition(
                batch=batch,
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
                detail=f"{len(updated)} lamaran berhasil dipindahkan ke status '{serializer.validated_data['status']}'.",
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

        Returns an .xlsx file containing all applicant biodata for every
        JobApplication in this batch. Each row = one applicant.

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
        applicant_user_ids = (
            applications.values_list("applicant__user_id", flat=True).distinct()
        )

        applicants_qs = (
            CustomUser.objects.filter(
                id__in=applicant_user_ids,
                role=UserRole.APPLICANT,
            )
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
# Job Application — Admin read + individual transitions
# ---------------------------------------------------------------------------


class JobApplicationViewSet(viewsets.ModelViewSet):
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
    filterset_fields = ["status", "job", "applicant", "batch"]
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
        return (
            JobApplication.objects
            .select_related(
                "applicant",
                "applicant__user",
                "applicant__referrer",
                "job", "job__company",
                "batch",
                "assigned_by",
            )
            .prefetch_related("status_history__changed_by")
        )

    @action(detail=True, methods=["patch"], url_path="transition")
    def transition(self, request, pk=None):
        """
        PATCH /api/applications/{id}/transition/
        Body: { "status": "INTERVIEW", "note": "...", "placement_end_date": "2026-12-31" }
        placement_end_date is only required when transitioning to SELESAI.
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

        out = JobApplicationSerializer(
            self.get_queryset().get(pk=application.pk),
            context={"request": request},
        )
        return Response(success_response(data=out.data, detail="Status lamaran diperbarui."))


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

        try:
            ApplicationService.confirm_attendance(
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
        return Response(success_response(data=out.data, detail="Kehadiran berhasil dikonfirmasi."))

    @action(detail=True, methods=["get"], url_path="announcements")
    def announcements(self, request, pk=None):
        """
        GET /api/applicants/me/applications/{id}/announcements/

        Returns all broadcast announcements for this application's batch, ordered
        newest-first. Returns an empty list when the application has no batch
        (i.e. it was not assigned via the batch workflow).

        This endpoint is the primary communication channel for PRA_SELEKSI and
        INTERVIEW stages — applicants read batch-level messages here instead of
        opening an individual chat thread.
        """
        application = self.get_object()

        if application.batch_id is None:
            return Response(success_response(data=[]))

        from .batch_announcement_recipients import announcement_visible_for_application

        qs = (
            BatchAnnouncement.objects.filter(batch_id=application.batch_id)
            .select_related("created_by")
            .order_by("-created_at")
        )
        visible = [a for a in qs if announcement_visible_for_application(a, application)]
        serializer = BatchAnnouncementSerializer(
            visible, many=True, context={"request": request}
        )
        return Response(success_response(data=serializer.data))


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

