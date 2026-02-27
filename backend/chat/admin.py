from django.contrib import admin

from .models import ChatMessage, ChatThread


class ChatMessageInline(admin.TabularInline):
    model = ChatMessage
    extra = 0
    readonly_fields = ["sender", "body", "sent_at", "is_read", "read_at"]
    can_delete = False
    ordering = ["sent_at"]


@admin.register(ChatThread)
class ChatThreadAdmin(admin.ModelAdmin):
    list_display = ["id", "application", "is_closed", "created_at", "updated_at"]
    list_filter = ["is_closed"]
    readonly_fields = ["application", "created_at", "updated_at"]
    inlines = [ChatMessageInline]


@admin.register(ChatMessage)
class ChatMessageAdmin(admin.ModelAdmin):
    list_display = ["id", "thread", "sender", "body_preview", "sent_at", "is_read"]
    list_filter = ["is_read"]
    readonly_fields = ["thread", "sender", "body", "sent_at", "is_read", "read_at"]

    @admin.display(description="Pesan")
    def body_preview(self, obj):
        return obj.body[:80]
