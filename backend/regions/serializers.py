from rest_framework import serializers

from .models import Province, Regency, District, Village


class ProvinceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Province
        fields = ["id", "code", "name"]


class RegencySerializer(serializers.ModelSerializer):
    class Meta:
        model = Regency
        fields = ["id", "code", "name", "province"]


class DistrictSerializer(serializers.ModelSerializer):
    class Meta:
        model = District
        fields = ["id", "code", "name", "regency"]


class VillageSerializer(serializers.ModelSerializer):
    class Meta:
        model = Village
        fields = ["id", "code", "name", "district"]


class VillageDetailSerializer(serializers.ModelSerializer):
    """Village with full hierarchy for display (province, regency, district, village)."""

    district_name = serializers.CharField(source="district.name", read_only=True)
    regency_name = serializers.CharField(source="district.regency.name", read_only=True)
    province_name = serializers.CharField(
        source="district.regency.province.name", read_only=True
    )

    class Meta:
        model = Village
        fields = [
            "id",
            "code",
            "name",
            "district",
            "district_name",
            "regency_name",
            "province_name",
        ]
