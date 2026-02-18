from django.contrib import admin
from django.utils.translation import gettext_lazy as _

from .models import Province, Regency, District, Village


@admin.register(Province)
class ProvinceAdmin(admin.ModelAdmin):
    list_display = ("code", "name")
    search_fields = ("code", "name")
    ordering = ("name",)


@admin.register(Regency)
class RegencyAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "province")
    list_filter = ("province",)
    search_fields = ("code", "name")
    raw_id_fields = ("province",)
    ordering = ("province", "name")


@admin.register(District)
class DistrictAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "regency")
    list_filter = ("regency__province", "regency")
    search_fields = ("code", "name")
    raw_id_fields = ("regency",)
    ordering = ("regency", "name")


@admin.register(Village)
class VillageAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "district")
    list_filter = ("district__regency__province", "district__regency", "district")
    search_fields = ("code", "name")
    raw_id_fields = ("district",)
    ordering = ("district", "name")
