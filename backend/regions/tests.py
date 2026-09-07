"""B5: region lists require a parent id so villages cannot dump the whole table."""

from django.core.cache import cache
from django.test import TestCase, override_settings
from django.urls import reverse
from rest_framework.test import APIClient

from regions.models import District, Province, Regency, Village

# cache_page would otherwise hide list behaviour across tests.
_dummy_cache = override_settings(
    CACHES={"default": {"BACKEND": "django.core.cache.backends.dummy.DummyCache"}}
)


@_dummy_cache
class RegionListGuardTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.province = Province.objects.create(code="12", name="SUMATERA UTARA")
        self.regency = Regency.objects.create(
            province=self.province, code="1271", name="KOTA MEDAN"
        )
        self.district = District.objects.create(
            regency=self.regency, code="127101", name="MEDAN KOTA"
        )
        self.village = Village.objects.create(
            district=self.district, code="12710101", name="KESAWAN"
        )

    def test_villages_without_district_id_are_rejected(self):
        response = self.client.get(reverse("regions:village-list"))
        self.assertEqual(response.status_code, 400)
        self.assertIn("district_id", response.json().get("errors", {}))

    def test_villages_with_district_id_are_listed(self):
        response = self.client.get(
            reverse("regions:village-list"), {"district_id": self.district.pk}
        )
        self.assertEqual(response.status_code, 200)
        rows = response.json()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["id"], self.village.pk)

    def test_village_retrieve_does_not_need_a_filter(self):
        response = self.client.get(
            reverse("regions:village-detail", kwargs={"pk": self.village.pk})
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["id"], self.village.pk)

    def test_districts_without_regency_id_are_rejected(self):
        response = self.client.get(reverse("regions:district-list"))
        self.assertEqual(response.status_code, 400)
        self.assertIn("regency_id", response.json().get("errors", {}))

    def test_regencies_without_province_id_still_list(self):
        """Mobile birth-place picker loads every kabupaten/kota (~500 rows)."""
        response = self.client.get(reverse("regions:regency-list"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()), 1)

    def test_provinces_list(self):
        response = self.client.get(reverse("regions:province-list"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()), 1)
