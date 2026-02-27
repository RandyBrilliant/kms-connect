"""
Serializers for the chat app.
"""
from rest_framework import serializers

from .models import ChatMessage, ChatThread


class ChatMessageSerializer(serializers.ModelSerializer):
    """Full read serializer for a single chat message."""

    sender_name = serializers.SerializerMethodField(read_only=True)
    sender_role = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = ChatMessage
        fields = [
            "id",
            "thread",
            "sender",
            "sender_name",
            "sender_role",
            "body",
            "sent_at",
            "is_read",
            "read_at",
        ]
        read_only_fields = fields  # All fields are read-only; use SendMessageSerializer for input

    def get_sender_name(self, obj) -> str:
        if not obj.sender:
            return ""
        return obj.sender.full_name or obj.sender.email

    def get_sender_role(self, obj) -> str:
        return obj.sender.role if obj.sender else ""


class SendMessageSerializer(serializers.Serializer):
    """Minimal input serializer for sending a new chat message."""

    body = serializers.CharField(
        min_length=1,
        max_length=2000,
        help_text="Isi pesan (teks).",
    )


class ChatThreadSerializer(serializers.ModelSerializer):
    """
    Thread summary used for listing threads (admin view).
    Includes computed fields for applicant name, job title, unread count, and last message.
    """

    applicant_name = serializers.SerializerMethodField(read_only=True)
    job_title = serializers.SerializerMethodField(read_only=True)
    application_status = serializers.SerializerMethodField(read_only=True)
    unread_count = serializers.SerializerMethodField(read_only=True)
    last_message = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = ChatThread
        fields = [
            "id",
            "application",
            "applicant_name",
            "job_title",
            "application_status",
            "is_closed",
            "unread_count",
            "last_message",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields

    def get_applicant_name(self, obj) -> str:
        try:
            user = obj.application.applicant.user
            return user.full_name or user.email
        except Exception:
            return ""

    def get_job_title(self, obj) -> str:
        try:
            return obj.application.job.title
        except Exception:
            return ""

    def get_application_status(self, obj) -> str:
        try:
            return obj.application.status
        except Exception:
            return ""

    def get_unread_count(self, obj) -> int:
        """
        Unread messages NOT sent by the current request user.
        Admin view: counts unread messages from the applicant.
        Applicant view: counts unread messages from admin.
        """
        request = self.context.get("request")
        if not request:
            return 0
        return obj.messages.filter(is_read=False).exclude(sender=request.user).count()

    def get_last_message(self, obj) -> dict | None:
        msg = obj.messages.order_by("-sent_at").first()
        if not msg:
            return None
        return {
            "body": msg.body[:100],
            "sent_at": msg.sent_at,
            "sender_name": msg.sender.full_name or msg.sender.email if msg.sender else "",
        }
