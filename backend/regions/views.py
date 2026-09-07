"""
Public read-only API for Indonesian regions (dropdowns / search).

No auth required so applicants can load Provinsi → Kabupaten/Kota → Kecamatan → Kelurahan
during registration. List endpoints that sit under a parent require that parent
id — a bare GET /api/villages/ would otherwise dump ~80,000 rows.
"""

from django.utils.decorators import method_decorator
from django.views.decorators.cache import cache_page
from rest_framework import viewsets
from rest_framework.exceptions import ValidationError
from rest_framework.filters import SearchFilter
from rest_framework.permissions import AllowAny

from .models import Province, Regency, District, Village
from .serializers import (
    ProvinceSerializer,
    RegencySerializer,
    DistrictSerializer,
    VillageSerializer,
    VillageDetailSerializer,
)
from .throttles import GeoRateThrottle

# Data is essentially static (Kemendagri import). 24h is fine; a re-import
# is a deploy-time event, not something that must be visible immediately.
REGION_LIST_CACHE_SECONDS = 60 * 60 * 24


def _require_int_query(request, name: str) -> int:
    raw = (request.query_params.get(name) or "").strip()
    if not raw:
        raise ValidationError(
            {
                name: (
                    "Wajib diisi. Tidak dapat menampilkan seluruh data; "
                    "pilih wilayah induk terlebih dahulu."
                )
            }
        )
    try:
        value = int(raw)
    except (TypeError, ValueError):
        raise ValidationError({name: "Tidak valid."})
    if value <= 0:
        raise ValidationError({name: "Tidak valid."})
    return value


class _PublicRegionViewSet(viewsets.ReadOnlyModelViewSet):
    filter_backends = [SearchFilter]
    pagination_class = None
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = [GeoRateThrottle]


@method_decorator(cache_page(REGION_LIST_CACHE_SECONDS), name="list")
class ProvinceViewSet(_PublicRegionViewSet):
    """List all provinces. ~38 rows; no parent filter."""

    queryset = Province.objects.all().order_by("name")
    serializer_class = ProvinceSerializer
    search_fields = ["name", "code"]


@method_decorator(cache_page(REGION_LIST_CACHE_SECONDS), name="list")
class RegencyViewSet(_PublicRegionViewSet):
    """
    List regencies.

    province_id is optional: the mobile birth-place picker needs the full
    kabupaten/kota list (~500 rows). Villages are the dangerous table, not this.
    """

    serializer_class = RegencySerializer
    search_fields = ["name", "code"]

    def get_queryset(self):
        qs = Regency.objects.all().select_related("province").order_by("name")
        raw = (self.request.query_params.get("province_id") or "").strip()
        if not raw:
            return qs
        try:
            return qs.filter(province_id=int(raw))
        except (TypeError, ValueError):
            raise ValidationError({"province_id": "Tidak valid."})


@method_decorator(cache_page(REGION_LIST_CACHE_SECONDS), name="list")
class DistrictViewSet(_PublicRegionViewSet):
    """List districts. regency_id is required on list."""

    serializer_class = DistrictSerializer
    search_fields = ["name", "code"]

    def list(self, request, *args, **kwargs):
        _require_int_query(request, "regency_id")
        return super().list(request, *args, **kwargs)

    def get_queryset(self):
        qs = District.objects.all().select_related("regency").order_by("name")
        raw = (self.request.query_params.get("regency_id") or "").strip()
        if raw:
            try:
                qs = qs.filter(regency_id=int(raw))
            except (TypeError, ValueError):
                raise ValidationError({"regency_id": "Tidak valid."})
        return qs


@method_decorator(cache_page(REGION_LIST_CACHE_SECONDS), name="list")
class VillageViewSet(_PublicRegionViewSet):
    """List villages. district_id is required on list (~80k rows unfiltered)."""

    serializer_class = VillageSerializer
    search_fields = ["name", "code"]

    def list(self, request, *args, **kwargs):
        _require_int_query(request, "district_id")
        return super().list(request, *args, **kwargs)

    def get_queryset(self):
        qs = Village.objects.all().select_related("district").order_by("name")
        raw = (self.request.query_params.get("district_id") or "").strip()
        if raw:
            try:
                qs = qs.filter(district_id=int(raw))
            except (TypeError, ValueError):
                raise ValidationError({"district_id": "Tidak valid."})
        return qs

    def get_serializer_class(self):
        if self.action == "retrieve":
            return VillageDetailSerializer
        return VillageSerializer
