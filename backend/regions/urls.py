from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

app_name = "regions"

router = DefaultRouter()
router.register(r"provinces", views.ProvinceViewSet, basename="province")
router.register(r"regencies", views.RegencyViewSet, basename="regency")
router.register(r"districts", views.DistrictViewSet, basename="district")
router.register(r"villages", views.VillageViewSet, basename="village")

urlpatterns = [
    path("", include(router.urls)),
]
