from django.contrib import admin

from .models import AuditEvent


@admin.register(AuditEvent)
class AuditEventAdmin(admin.ModelAdmin):
    list_display = (
        "created_at",
        "action",
        "resource_type",
        "resource_label",
        "actor_email",
        "ip_address",
    )
    list_filter = ("action", "resource_type", "actor_role")
    search_fields = ("summary", "actor_email", "resource_label", "resource_id")
    ordering = ("-created_at", "-id")
    readonly_fields = (
        "created_at",
        "actor",
        "actor_email",
        "actor_role",
        "actor_name",
        "action",
        "resource_type",
        "resource_id",
        "resource_label",
        "summary",
        "ip_address",
        "user_agent",
        "metadata",
    )

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
