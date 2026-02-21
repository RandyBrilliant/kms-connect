"""
Indonesian administrative divisions (Wilayah Administratif Indonesia).

Hierarchy: Province → Regency (Kabupaten/Kota) → District (Kecamatan) → Village (Kelurahan/Desa).
Data can be imported from optimized CSV files via management command:
  python manage.py load_indonesia_regions [--clear]

CSV files in backend/data/: provinsi.csv, kota.csv, kecamatan.csv, kelurahan.csv
Used for applicant address dropdowns (search by provinsi, kabupaten, kecamatan, kelurahan).
"""

from django.db import models
from django.utils.translation import gettext_lazy as _


class Province(models.Model):
    """Provinsi. Code matches official id (e.g. 12 = Sumatera Utara)."""

    code = models.CharField(
        _("kode"),
        max_length=10,
        unique=True,
        db_index=True,
        help_text=_("Kode provinsi (dari data Kemendagri/ibnux)."),
    )
    name = models.CharField(
        _("nama"),
        max_length=255,
        help_text=_("Nama provinsi (contoh: SUMATERA UTARA)."),
    )

    class Meta:
        ordering = ["name"]
        verbose_name = _("provinsi")
        verbose_name_plural = _("daftar provinsi")

    def __str__(self) -> str:
        return self.name


class Regency(models.Model):
    """Kabupaten atau Kota. Code matches official id (e.g. 1201, 1271)."""

    province = models.ForeignKey(
        Province,
        on_delete=models.CASCADE,
        related_name="regencies",
        verbose_name=_("provinsi"),
    )
    code = models.CharField(
        _("kode"),
        max_length=10,
        unique=True,
        db_index=True,
        help_text=_("Kode kabupaten/kota (dari data Kemendagri/ibnux)."),
    )
    name = models.CharField(
        _("nama"),
        max_length=255,
        help_text=_("Nama kabupaten/kota (contoh: KAB. ASAHAN, KOTA MEDAN)."),
    )

    class Meta:
        ordering = ["province", "name"]
        verbose_name = _("kabupaten / kota")
        verbose_name_plural = _("daftar kabupaten / kota")
        indexes = [
            models.Index(fields=["province"]),
        ]

    def __str__(self) -> str:
        return f"{self.name} ({self.province.name})"


class District(models.Model):
    """Kecamatan. Code matches official id (e.g. 1201010)."""

    regency = models.ForeignKey(
        Regency,
        on_delete=models.CASCADE,
        related_name="districts",
        verbose_name=_("kabupaten / kota"),
    )
    code = models.CharField(
        _("kode"),
        max_length=10,
        unique=True,
        db_index=True,
        help_text=_("Kode kecamatan (dari data Kemendagri/ibnux)."),
    )
    name = models.CharField(
        _("nama"),
        max_length=255,
        help_text=_("Nama kecamatan."),
    )

    class Meta:
        ordering = ["regency", "name"]
        verbose_name = _("kecamatan")
        verbose_name_plural = _("daftar kecamatan")
        indexes = [
            models.Index(fields=["regency"]),
        ]

    def __str__(self) -> str:
        return f"{self.name} ({self.regency.name})"


class Village(models.Model):
    """Kelurahan atau Desa. Code matches official id (e.g. 1201010001)."""

    district = models.ForeignKey(
        District,
        on_delete=models.CASCADE,
        related_name="villages",
        verbose_name=_("kecamatan"),
    )
    code = models.CharField(
        _("kode"),
        max_length=10,
        unique=True,
        db_index=True,
        help_text=_("Kode kelurahan/desa (dari data Kemendagri/ibnux)."),
    )
    name = models.CharField(
        _("nama"),
        max_length=255,
        help_text=_("Nama kelurahan/desa."),
    )

    class Meta:
        ordering = ["district", "name"]
        verbose_name = _("kelurahan / desa")
        verbose_name_plural = _("daftar kelurahan / desa")
        indexes = [
            models.Index(fields=["district"]),
        ]

    def __str__(self) -> str:
        return f"{self.name} ({self.district.name})"
