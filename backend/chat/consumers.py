"""
WebSocket consumer for real-time chat.

Protocol:
  ws(s)://<host>/ws/chat/<thread_id>/?token=<JWT>

Authentication:
  JWT access token passed as query param.  Validated on connect using
  the same SimpleJWT backend as the REST API.

Inbound messages from client (JSON):
  • {"type": "typing"}            — broadcast typing indicator to others in thread
  • {"type": "mark_read"}         — mark all unread messages as read

Outbound messages to client (JSON, via channel group):
  • {"type": "chat.message", "message": {<ChatMessageSerializer data>}}
  • {"type": "chat.typing", "user_id": <int>, "user_name": <str>}
  • {"type": "chat.read", "user_id": <int>, "read_at": <ISO>}

Channel group name: ``chat_thread_{thread_id}``
"""

import json
import logging

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from django.utils import timezone
from rest_framework_simplejwt.tokens import AccessToken

from account.models import CustomUser

from .models import ChatMessage, ChatThread

logger = logging.getLogger(__name__)


class ChatConsumer(AsyncJsonWebsocketConsumer):
    """
    Async WebSocket consumer for a single ChatThread.

    Lifecycle:
    1. ``connect`` — authenticate via JWT, verify thread access, join group.
    2. ``receive_json`` — handle typing / mark_read from client.
    3. ``disconnect`` — leave group.

    Server-side code (views / signals) broadcasts ``chat.message`` events
    into the group; this consumer relays them to the WebSocket client.
    """

    # ── Connection lifecycle ────────────────────────────────────────────

    async def connect(self):
        self.thread_id = self.scope["url_route"]["kwargs"]["thread_id"]
        self.group_name = f"chat_thread_{self.thread_id}"
        self.user = None

        # Authenticate via JWT query param
        query_string = self.scope.get("query_string", b"").decode("utf-8")
        token = self._parse_query_param(query_string, "token")

        if not token:
            await self.close(code=4001)
            return

        user = await self._authenticate(token)
        if user is None:
            await self.close(code=4001)
            return

        # Verify user has access to this thread
        has_access = await self._check_thread_access(user, int(self.thread_id))
        if not has_access:
            await self.close(code=4003)
            return

        self.user = user

        # Join channel group
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

        logger.info(
            "WS connected: user=%s thread=%s", user.pk, self.thread_id
        )

    async def disconnect(self, close_code):
        if hasattr(self, "group_name"):
            await self.channel_layer.group_discard(
                self.group_name, self.channel_name
            )
        logger.info(
            "WS disconnected: user=%s thread=%s code=%s",
            getattr(self, "user", None) and self.user.pk,
            getattr(self, "thread_id", "?"),
            close_code,
        )

    # ── Inbound (client → server) ──────────────────────────────────────

    async def receive_json(self, content, **kwargs):
        msg_type = content.get("type")

        if msg_type == "typing":
            await self.channel_layer.group_send(
                self.group_name,
                {
                    "type": "chat.typing",
                    "user_id": self.user.pk,
                    "user_name": self.user.full_name or self.user.email,
                },
            )

        elif msg_type == "mark_read":
            count = await self._mark_messages_read()
            if count > 0:
                await self.channel_layer.group_send(
                    self.group_name,
                    {
                        "type": "chat.read",
                        "user_id": self.user.pk,
                        "read_at": timezone.now().isoformat(),
                    },
                )

    # ── Outbound handlers (group → client) ─────────────────────────────

    async def chat_message(self, event):
        """Relay a new chat message to the WebSocket client."""
        await self.send_json(
            {
                "type": "chat.message",
                "message": event["message"],
            }
        )

    async def chat_typing(self, event):
        """Relay typing indicator — skip if the typer is this client."""
        if event.get("user_id") == (self.user and self.user.pk):
            return
        await self.send_json(
            {
                "type": "chat.typing",
                "user_id": event["user_id"],
                "user_name": event.get("user_name", ""),
            }
        )

    async def chat_read(self, event):
        """Relay read receipt to all clients."""
        await self.send_json(
            {
                "type": "chat.read",
                "user_id": event["user_id"],
                "read_at": event.get("read_at", ""),
            }
        )

    # ── Helpers ─────────────────────────────────────────────────────────

    @staticmethod
    def _parse_query_param(query_string: str, key: str) -> str | None:
        """Parse a query parameter from a raw query string."""
        for part in query_string.split("&"):
            if "=" in part:
                k, v = part.split("=", 1)
                if k == key:
                    return v
        return None

    @database_sync_to_async
    def _authenticate(self, raw_token: str) -> CustomUser | None:
        """Validate JWT and return the corresponding user or None."""
        try:
            validated = AccessToken(raw_token)
            user_id = validated["user_id"]
            return CustomUser.objects.get(pk=user_id, is_active=True)
        except Exception:
            logger.debug("WS auth failed for token: %s…", raw_token[:10])
            return None

    @database_sync_to_async
    def _check_thread_access(self, user: CustomUser, thread_id: int) -> bool:
        """
        Verify user can access this thread:
        - Admin/Staff: can access any thread
        - Applicant: can only access their own thread
        """
        try:
            thread = ChatThread.objects.select_related(
                "application__applicant__user"
            ).get(pk=thread_id)
        except ChatThread.DoesNotExist:
            return False

        if user.role in ("MASTER_ADMIN", "ADMIN", "STAFF"):
            return True

        # Applicant must own the application
        try:
            return thread.application.applicant.user_id == user.pk
        except Exception:
            return False

    @database_sync_to_async
    def _mark_messages_read(self) -> int:
        """Mark all unread messages (not from this user) as read."""
        return (
            ChatMessage.objects.filter(
                thread_id=self.thread_id,
                is_read=False,
            )
            .exclude(sender=self.user)
            .update(is_read=True, read_at=timezone.now())
        )
