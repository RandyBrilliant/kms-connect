"""
Public read-only API for Indonesian regions (dropdowns / search).

No auth required so applicants can load Provinsi → Kabupaten/Kota → Kecamatan → Kelurahan.
"""

from rest_framework import viewsets
from rest_framework.filters import SearchFilter

from .models import Province, Regency, District, Village
from .serializers import (
    ProvinceSerializer,
    RegencySerializer,
    DistrictSerializer,
    VillageSerializer,
    VillageDetailSerializer,
)


class ProvinceViewSet(viewsets.ReadOnlyModelViewSet):
    """List all provinces. No filter needed."""

    queryset = Province.objects.all().order_by("name")
    serializer_class = ProvinceSerializer
    filter_backends = [SearchFilter]
    search_fields = ["name", "code"]
    pagination_class = None  # Return all for dropdowns


class RegencyViewSet(viewsets.ReadOnlyModelViewSet):
    """List regencies; filter by province_id for cascading dropdown."""

    serializer_class = RegencySerializer
    filter_backends = [SearchFilter]
    search_fields = ["name", "code"]
    pagination_class = None  # Return all for dropdowns (birth_place, address cascade)

    def get_queryset(self):
        qs = Regency.objects.all().select_related("province").order_by("name")
        province_id = self.request.query_params.get("province_id")
        if province_id:
            qs = qs.filter(province_id=province_id)
        return qs


class DistrictViewSet(viewsets.ReadOnlyModelViewSet):
    """List districts; filter by regency_id for cascading dropdown."""

    serializer_class = DistrictSerializer
    filter_backends = [SearchFilter]
    search_fields = ["name", "code"]
    pagination_class = None  # Return all for dropdown cascade

    def get_queryset(self):
        qs = District.objects.all().select_related("regency").order_by("name")
        regency_id = self.request.query_params.get("regency_id")
        if regency_id:
            qs = qs.filter(regency_id=regency_id)
        return qs


class VillageViewSet(viewsets.ReadOnlyModelViewSet):
    """List villages; filter by district_id for cascading dropdown."""

    serializer_class = VillageSerializer
    filter_backends = [SearchFilter]
    search_fields = ["name", "code"]
    pagination_class = None  # Return all for dropdown cascade

    def get_queryset(self):
        qs = Village.objects.all().select_related("district").order_by("name")
        district_id = self.request.query_params.get("district_id")
        if district_id:
            qs = qs.filter(district_id=district_id)
        return qs

    def get_serializer_class(self):
        if self.action == "retrieve":
            return VillageDetailSerializer
        return VillageSerializer
