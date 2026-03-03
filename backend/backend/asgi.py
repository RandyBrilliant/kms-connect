"""
ASGI config for backend project.

Supports both HTTP and WebSocket protocols:
  - HTTP  → standard Django ASGI handler
  - WS    → Django Channels consumer routing (chat)

For more information on this file, see
https://docs.djangoproject.com/en/6.0/howto/deployment/asgi/
"""

import os

from channels.routing import ProtocolTypeRouter, URLRouter
from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "backend.settings")

# Django ASGI application must be initialised before importing routing
# so that Django apps registry is populated.
django_asgi_app = get_asgi_application()

from chat.routing import websocket_urlpatterns  # noqa: E402

application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,
        "websocket": URLRouter(websocket_urlpatterns),
    }
)
