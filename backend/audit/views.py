"""
Read-only API for Master Admin audit event browsing.
"""
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import serializers, viewsets
from rest_framework.filters import SearchFilter
from rest_framework.pagination import CursorPagination
from rest_framework.permissions import IsAuthenticated

from account.permissions import IsMasterAdmin

from .models import AuditAction, AuditEvent, AuditResourceType


class AuditEventCursorPagination(CursorPagination):
    """Efficient for append-only logs that grow forever."""

    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100
    ordering = ("-created_at", "-id")


class AuditEventSerializer(serializers.ModelSerializer):
    action_display = serializers.CharField(source="get_action_display", read_only=True)
    resource_type_display = serializers.CharField(
        source="get_resource_type_display", read_only=True
    )
    # actor_id is historical; the referenced user may already be deleted.
    actor = serializers.IntegerField(source="actor_id", read_only=True, allow_null=True)

    class Meta:
        model = AuditEvent
        fields = [
            "id",
            "created_at",
            "actor",
            "actor_email",
            "actor_role",
            "actor_name",
            "action",
            "action_display",
            "resource_type",
            "resource_type_display",
            "resource_id",
            "resource_label",
            "summary",
            "ip_address",
            "user_agent",
            "metadata",
        ]
        read_only_fields = fields


class AuditEventViewSet(viewsets.ReadOnlyModelViewSet):
    """
    GET /api/audit-events/ — list (cursor pagination)
    GET /api/audit-events/{id}/ — retrieve

    Master Admin / superuser only. No writes.
    """

    serializer_class = AuditEventSerializer
    permission_classes = [IsAuthenticated, IsMasterAdmin]
    pagination_class = AuditEventCursorPagination
    filter_backends = [DjangoFilterBackend, SearchFilter]
    filterset_fields = ["action", "resource_type", "actor"]
    search_fields = ["summary", "actor_email", "resource_label", "resource_id"]
    http_method_names = ["get", "head", "options"]

    def get_queryset(self):
        qs = AuditEvent.objects.all()
        params = self.request.query_params

        created_after = params.get("created_after")
        if created_after:
            qs = qs.filter(created_at__gte=created_after)

        created_before = params.get("created_before")
        if created_before:
            qs = qs.filter(created_at__lte=created_before)

        return qs

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        # Expose choice maps for optional UI use without a separate endpoint.
        ctx["action_choices"] = list(AuditAction.choices)
        ctx["resource_type_choices"] = list(AuditResourceType.choices)
        return ctx
