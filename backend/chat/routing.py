"""
WebSocket URL routing for the chat app.

Path: ws(s)://<host>/ws/chat/<thread_id>/?token=<JWT>
"""

from django.urls import re_path

from . import consumers

websocket_urlpatterns = [
    re_path(
        r"ws/chat/(?P<thread_id>\d+)/$",
        consumers.ChatConsumer.as_asgi(),
    ),
]
