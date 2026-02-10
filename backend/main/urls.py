"""
Main app API URLs.
Admin-side CRUD:
- News
- LowonganKerja
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

app_name = "main"

router = DefaultRouter()
router.register(r"news", views.NewsViewSet, basename="news")
router.register(r"jobs", views.LowonganKerjaViewSet, basename="job")

urlpatterns = [
    path("", include(router.urls)),
]

