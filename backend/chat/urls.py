"""
Chat app URL configuration.

Admin endpoints are router-based (ChatThreadViewSet).
Applicant endpoints are explicit path-based (scoped to their own thread).
"""
from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

app_name = "chat"

router = DefaultRouter()
router.register(r"threads", views.ChatThreadViewSet, basename="thread")

urlpatterns = [
    # Admin: list/detail/send/close/reopen — via router + custom @action URLs
    path("", include(router.urls)),

    # Applicant: scoped to their own application's thread
    path(
        "applicant/thread/<int:thread_id>/messages/",
        views.ApplicantChatMessagesView.as_view(),
        name="applicant-messages",
    ),
    path(
        "applicant/thread/<int:thread_id>/read/",
        views.ApplicantMarkReadView.as_view(),
        name="applicant-mark-read",
    ),
]
