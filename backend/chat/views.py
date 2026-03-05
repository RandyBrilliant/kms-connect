"""
Chat API views.

Admin endpoints (IsBackofficeAdmin):
  GET  /api/chat/threads/                      — list all threads
  GET  /api/chat/threads/{id}/                 — thread detail
  GET  /api/chat/threads/{id}/messages/        — messages in thread (?since=<ISO>)
  POST /api/chat/threads/{id}/send/            — admin sends a message
  POST /api/chat/threads/{id}/close/           — close thread
  POST /api/chat/threads/{id}/reopen/          — reopen thread

Applicant endpoints (IsApplicant):
  GET  /api/chat/applicant/thread/{id}/messages/ — fetch messages (?since=<ISO>)
  POST /api/chat/applicant/thread/{id}/messages/ — send a message
  POST /api/chat/applicant/thread/{id}/read/     — mark messages as read
"""
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.filters import OrderingFilter, SearchFilter
from rest_framework.response import Response
from rest_framework.views import APIView

from account.api_responses import ApiCode, error_response, success_response
from account.permissions import IsApplicant, IsBackofficeAdmin

from .models import ChatMessage, ChatThread

# Statuses at which an applicant is permitted to use individual chat.
_CHAT_ALLOWED_STATUSES = {"DITERIMA", "BERANGKAT", "SELESAI"}
from .serializers import (
    ApplicantChatThreadSerializer,
    ChatMessageSerializer,
    ChatThreadSerializer,
    SendMessageSerializer,
)
from .broadcast import broadcast_chat_message
from .tasks import send_chat_push_notification


# ---------------------------------------------------------------------------
# Admin-facing endpoints
# ---------------------------------------------------------------------------


class ChatThreadViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Admin: read-only list + detail of all threads.
    Custom actions for sending messages, closing, and reopening threads.
    ReadOnly base class keeps the router clean — mutations via explicit @action endpoints.
    """

    serializer_class = ChatThreadSerializer
    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["is_closed", "application__job", "application__applicant"]
    search_fields = [
        "application__applicant__user__full_name",
        "application__applicant__user__email",
        "application__job__title",
    ]
    ordering_fields = ["updated_at", "created_at"]
    ordering = ["-updated_at"]

    def get_queryset(self):
        return (
            ChatThread.objects
            .select_related(
                "application__applicant__user",
                "application__job",
                "application__reviewed_by",
                "application__assigned_by",
            )
            .prefetch_related("messages__sender")
        )

    @action(detail=True, methods=["get"], url_path="messages")
    def messages(self, request, pk=None):
        """
        GET /api/chat/threads/{id}/messages/
        Returns messages in chronological order.
        Optional query param: ?since=<ISO 8601 datetime> to fetch only new messages
        (used by the mobile app polling loop).
        """
        thread = self.get_object()
        qs = thread.messages.select_related("sender").order_by("sent_at")

        since_raw = request.query_params.get("since")
        if since_raw:
            since_dt = parse_datetime(since_raw)
            if since_dt:
                qs = qs.filter(sent_at__gt=since_dt)

        serializer = ChatMessageSerializer(qs, many=True, context={"request": request})
        return Response(success_response(data=serializer.data))

    @action(detail=True, methods=["post"], url_path="send")
    def send(self, request, pk=None):
        """
        POST /api/chat/threads/{id}/send/
        Admin sends a message to the applicant.
        Body: { "body": "..." }
        """
        thread = self.get_object()

        if thread.is_closed:
            return Response(
                error_response(
                    detail="Thread sudah ditutup. Buka kembali sebelum mengirim pesan.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = SendMessageSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail="Data tidak valid.", code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        msg = ChatMessage.objects.create(
            thread=thread,
            sender=request.user,
            body=serializer.validated_data["body"],
        )
        # Bump thread updated_at so it rises in the admin list
        ChatThread.objects.filter(pk=thread.pk).update(updated_at=timezone.now())

        # Real-time: broadcast to WebSocket clients, then push FCM
        broadcast_chat_message(msg)
        send_chat_push_notification.delay(msg.pk)

        return Response(
            success_response(
                data=ChatMessageSerializer(msg, context={"request": request}).data,
                detail="Pesan terkirim.",
            ),
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=["post"], url_path="close")
    def close(self, request, pk=None):
        """POST /api/chat/threads/{id}/close/ — admin closes the thread."""
        thread = self.get_object()
        if thread.is_closed:
            return Response(
                error_response(detail="Thread sudah ditutup.", code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )
        thread.is_closed = True
        thread.save(update_fields=["is_closed", "updated_at"])
        return Response(
            success_response(
                data=ChatThreadSerializer(thread, context={"request": request}).data,
                detail="Thread berhasil ditutup.",
            )
        )

    @action(detail=True, methods=["post"], url_path="reopen")
    def reopen(self, request, pk=None):
        """POST /api/chat/threads/{id}/reopen/ — admin reopens the thread."""
        thread = self.get_object()
        if not thread.is_closed:
            return Response(
                error_response(detail="Thread masih terbuka.", code=ApiCode.VALIDATION_ERROR),
                status=status.HTTP_400_BAD_REQUEST,
            )
        thread.is_closed = False
        thread.save(update_fields=["is_closed", "updated_at"])
        return Response(
            success_response(
                data=ChatThreadSerializer(thread, context={"request": request}).data,
                detail="Thread berhasil dibuka kembali.",
            )
        )


# ---------------------------------------------------------------------------
# Applicant-facing endpoints
# ---------------------------------------------------------------------------


class _ApplicantThreadMixin:
    """
    Shared helper: resolve the ChatThread belonging to the current applicant.
    Ownership is enforced here — applicant can only access their own thread.
    """

    permission_classes = [IsApplicant]

    def _resolve_thread(self, request, thread_id: int):
        """
        Returns (thread, None) on success.
        Returns (None, Response) if profile is missing or thread not found/unauthorized.
        """
        try:
            applicant_profile = request.user.applicant_profile
        except Exception:
            return None, Response(
                error_response(detail="Profil pelamar tidak ditemukan.", code=ApiCode.NOT_FOUND),
                status=status.HTTP_404_NOT_FOUND,
            )

        thread = (
            ChatThread.objects
            .filter(pk=thread_id, application__applicant=applicant_profile)
            .select_related("application__applicant__user", "application__job")
            .first()
        )
        if not thread:
            return None, Response(
                error_response(detail="Thread tidak ditemukan.", code=ApiCode.NOT_FOUND),
                status=status.HTTP_404_NOT_FOUND,
            )

        # Chat is only available once the application reaches DITERIMA or later.
        # For PRA_SELEKSI and INTERVIEW stages, use batch announcements instead.
        if thread.application.status not in _CHAT_ALLOWED_STATUSES:
            return None, Response(
                error_response(
                    detail=(
                        "Fitur chat belum tersedia pada tahap ini. "
                        "Gunakan pengumuman batch untuk komunikasi pada tahap Pra-Seleksi dan Interview."
                    ),
                    code=ApiCode.PERMISSION_DENIED,
                ),
                status=status.HTTP_403_FORBIDDEN,
            )

        return thread, None


class ApplicantThreadListView(_ApplicantThreadMixin, APIView):
    """
    GET /api/chat/applicant/threads/

    Returns all chat threads belonging to the current applicant, ordered by most
    recently updated. Each item includes the job title, last message preview, and
    the count of unread messages from admin/staff.

    Used by the mobile Chat inbox screen.
    """

    def get(self, request):
        try:
            applicant_profile = request.user.applicant_profile
        except Exception:
            return Response(
                error_response(
                    detail="Profil pelamar tidak ditemukan.",
                    code=ApiCode.NOT_FOUND,
                ),
                status=status.HTTP_404_NOT_FOUND,
            )

        threads = (
            ChatThread.objects
            .filter(
                application__applicant=applicant_profile,
                application__status__in=_CHAT_ALLOWED_STATUSES,
            )
            .select_related(
                "application__job",
                "application__applicant__user",
            )
            .prefetch_related("messages__sender")
            .order_by("-updated_at")
        )

        serializer = ApplicantChatThreadSerializer(
            threads, many=True, context={"request": request}
        )
        return Response(success_response(data=serializer.data))


class ApplicantChatMessagesView(_ApplicantThreadMixin, APIView):
    """
    GET  /api/chat/applicant/thread/{id}/messages/ — fetch messages
    POST /api/chat/applicant/thread/{id}/messages/ — send a message

    GET supports:
      ?since=<ISO 8601 datetime> for incremental polling.
      ?page=<int> for cursor-based pagination (newest first by default).
      ?page_size=<int> to control items per page (default 50, max 100).

    The mobile app should poll this endpoint every ~8s when the chat screen is
    open, and on FCM push notification wake.
    """

    PAGE_SIZE_DEFAULT = 50
    PAGE_SIZE_MAX = 100

    def get(self, request, thread_id: int):
        thread, err = self._resolve_thread(request, thread_id)
        if err:
            return err

        qs = thread.messages.select_related("sender").order_by("sent_at")

        since_raw = request.query_params.get("since")
        if since_raw:
            since_dt = parse_datetime(since_raw)
            if since_dt:
                qs = qs.filter(sent_at__gt=since_dt)

        # Pagination — return a window of messages so long threads don't send
        # thousands of rows on initial load.
        page_size = min(
            int(request.query_params.get("page_size", self.PAGE_SIZE_DEFAULT)),
            self.PAGE_SIZE_MAX,
        )
        page = max(int(request.query_params.get("page", 1)), 1)
        total = qs.count()
        start = max(total - page * page_size, 0)
        end = total - (page - 1) * page_size
        page_qs = qs[start:end]

        data = ChatMessageSerializer(page_qs, many=True, context={"request": request}).data
        return Response(
            success_response(
                data={
                    "messages": data,
                    "total": total,
                    "page": page,
                    "page_size": page_size,
                    "has_more": start > 0,
                }
            )
        )

    def post(self, request, thread_id: int):
        thread, err = self._resolve_thread(request, thread_id)
        if err:
            return err

        if thread.is_closed:
            return Response(
                error_response(
                    detail="Thread sudah ditutup oleh admin.",
                    code=ApiCode.VALIDATION_ERROR,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = SendMessageSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                error_response(
                    detail="Data tidak valid.", code=ApiCode.VALIDATION_ERROR,
                    errors=serializer.errors,
                ),
                status=status.HTTP_400_BAD_REQUEST,
            )

        msg = ChatMessage.objects.create(
            thread=thread,
            sender=request.user,
            body=serializer.validated_data["body"],
        )
        ChatThread.objects.filter(pk=thread.pk).update(updated_at=timezone.now())

        # Real-time: broadcast to WebSocket clients, then push FCM
        broadcast_chat_message(msg)
        send_chat_push_notification.delay(msg.pk)

        return Response(
            success_response(
                data=ChatMessageSerializer(msg, context={"request": request}).data,
                detail="Pesan terkirim.",
            ),
            status=status.HTTP_201_CREATED,
        )


class ApplicantMarkReadView(_ApplicantThreadMixin, APIView):
    """
    POST /api/chat/applicant/thread/{id}/read/
    Marks all unread messages (not sent by the applicant themselves) as read.
    Returns the count of messages that were marked.
    """

    def post(self, request, thread_id: int):
        thread, err = self._resolve_thread(request, thread_id)
        if err:
            return err

        updated = (
            thread.messages
            .filter(is_read=False)
            .exclude(sender=request.user)
            .update(is_read=True, read_at=timezone.now())
        )
        return Response(success_response(data={"marked_read": updated}))
