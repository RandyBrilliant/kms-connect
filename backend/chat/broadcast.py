"""
Utility to broadcast chat events to WebSocket channel groups.

Call ``broadcast_chat_message`` after creating a ChatMessage in any
REST view (admin or applicant). This pushes the message to all connected
WebSocket clients in the thread — giving instant delivery without polling.
"""

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from .serializers import ChatMessageSerializer


def broadcast_chat_message(message) -> None:
    """
    Broadcast a ChatMessage to all WebSocket clients connected to the thread.

    Args:
        message: ChatMessage model instance (must have .thread_id populated).
    """
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return  # Channels not configured (e.g. in tests)

    group_name = f"chat_thread_{message.thread_id}"
    serialized = ChatMessageSerializer(message).data

    async_to_sync(channel_layer.group_send)(
        group_name,
        {
            "type": "chat.message",
            "message": serialized,
        },
    )
