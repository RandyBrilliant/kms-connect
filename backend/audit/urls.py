from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import AuditEventViewSet

app_name = "audit"

router = DefaultRouter()
router.register(r"audit-events", AuditEventViewSet, basename="audit-event")

urlpatterns = [
    path("", include(router.urls)),
]
