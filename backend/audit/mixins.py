"""
Optional mixin for dashboard ViewSets: emit CREATE/UPDATE/DELETE/ACTIVATE/DEACTIVATE.
Skip noisy ViewSets (notifications, chat, regions, public lists).
"""
from __future__ import annotations

from audit.models import AuditAction, AuditResourceType
from audit.services import emit


class AuditedMixin:
    """
    Emit audit events after successful create/update/destroy and activate/deactivate.

    Subclasses should set:
      audit_resource_type: str  (AuditResourceType value)
    Optionally override:
      get_audit_resource_label(instance) -> str
      get_audit_summary(action, instance) -> str
    """

    audit_resource_type: str = AuditResourceType.USER

    def get_audit_resource_label(self, instance) -> str:
        for attr in ("email", "title", "name", "full_name", "company_name"):
            value = getattr(instance, attr, None)
            if value:
                return str(value)[:255]
        profile = getattr(instance, "company_profile", None)
        if profile is not None:
            name = getattr(profile, "company_name", None)
            if name:
                return str(name)[:255]
        return str(getattr(instance, "pk", ""))[:255]

    def get_audit_summary(self, action: str, instance) -> str:
        label = self.get_audit_resource_label(instance)
        resource = self.audit_resource_type
        action_key = action.value if hasattr(action, "value") else str(action)
        verbs = {
            AuditAction.CREATE: "membuat",
            AuditAction.UPDATE: "mengubah",
            AuditAction.DELETE: "menghapus",
            AuditAction.ACTIVATE: "mengaktifkan",
            AuditAction.DEACTIVATE: "menonaktifkan",
            AuditAction.CREATE.value: "membuat",
            AuditAction.UPDATE.value: "mengubah",
            AuditAction.DELETE.value: "menghapus",
            AuditAction.ACTIVATE.value: "mengaktifkan",
            AuditAction.DEACTIVATE.value: "menonaktifkan",
        }
        verb = verbs.get(action, verbs.get(action_key, action_key.lower()))
        return f"{verb.capitalize()} {resource} {label}".strip()

    def _emit_audit(self, action: str, instance, metadata: dict | None = None) -> None:
        request = getattr(self, "request", None)
        actor = getattr(request, "user", None) if request is not None else None
        if actor is not None and not getattr(actor, "is_authenticated", False):
            actor = None
        # Capture label/id before any destroy clears relations.
        pk = getattr(instance, "pk", "")
        label = self.get_audit_resource_label(instance)
        emit(
            action=action,
            resource_type=self.audit_resource_type,
            resource_id=pk,
            resource_label=label,
            summary=self.get_audit_summary(action, instance),
            actor=actor,
            request=request,
            metadata=metadata or {},
        )

    def perform_create(self, serializer):
        super().perform_create(serializer)
        self._emit_audit(AuditAction.CREATE, serializer.instance)

    def perform_update(self, serializer):
        changed = list(getattr(serializer, "validated_data", {}).keys())
        super().perform_update(serializer)
        self._emit_audit(
            AuditAction.UPDATE,
            serializer.instance,
            metadata={"changed_fields": changed},
        )

    def perform_destroy(self, instance):
        label = self.get_audit_resource_label(instance)
        pk = getattr(instance, "pk", "")
        summary = self.get_audit_summary(AuditAction.DELETE, instance)
        request = getattr(self, "request", None)
        actor = getattr(request, "user", None) if request is not None else None
        if actor is not None and not getattr(actor, "is_authenticated", False):
            actor = None
        super().perform_destroy(instance)
        emit(
            action=AuditAction.DELETE,
            resource_type=self.audit_resource_type,
            resource_id=pk,
            resource_label=label,
            summary=summary,
            actor=actor,
            request=request,
        )

    def deactivate(self, request, *args, **kwargs):
        instance = self.get_object()
        response = super().deactivate(request, *args, **kwargs)
        if getattr(response, "status_code", 500) < 400:
            self._emit_audit(AuditAction.DEACTIVATE, instance)
        return response

    def activate(self, request, *args, **kwargs):
        instance = self.get_object()
        response = super().activate(request, *args, **kwargs)
        if getattr(response, "status_code", 500) < 400:
            self._emit_audit(AuditAction.ACTIVATE, instance)
        return response
