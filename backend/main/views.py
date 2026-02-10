"""
API views untuk main app (admin-side CRUD untuk News dan LowonganKerja).
"""

from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import viewsets
from rest_framework.filters import SearchFilter, OrderingFilter

from account.permissions import IsBackofficeAdmin

from .models import News, LowonganKerja
from .serializers import NewsSerializer, LowonganKerjaSerializer


class NewsViewSet(viewsets.ModelViewSet):
    """
    CRUD berita untuk admin/backoffice.
    Tidak ada delete fisik di requirement awal; namun untuk konten berita,
    hard delete sering kali diperbolehkan. Jika ingin soft-delete, bisa
    diganti nanti dengan status ARCHIVED saja.
    """

    http_method_names = ["get", "post", "put", "patch", "delete", "head", "options"]
    serializer_class = NewsSerializer
    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["status", "is_pinned"]
    search_fields = ["title", "summary", "content"]
    ordering_fields = ["published_at", "created_at", "updated_at", "title"]
    ordering = ["-published_at", "-created_at"]

    def get_queryset(self):
        return News.objects.all()


class LowonganKerjaViewSet(viewsets.ModelViewSet):
    """
    CRUD lowongan kerja untuk admin/backoffice.
    Admin mengelola lowongan yang nantinya dapat dilihat publik/pelamar.
    """

    http_method_names = ["get", "post", "put", "patch", "delete", "head", "options"]
    serializer_class = LowonganKerjaSerializer
    permission_classes = [IsBackofficeAdmin]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ["status", "employment_type", "company", "location_country"]
    search_fields = ["title", "description", "requirements", "company__company_name"]
    ordering_fields = ["posted_at", "deadline", "created_at", "updated_at", "title"]
    ordering = ["-posted_at", "-created_at"]

    def get_queryset(self):
        return (
            LowonganKerja.objects.select_related("company", "created_by")
        )

