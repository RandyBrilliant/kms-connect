"""
PDF overlay for BUKTI PENYERAHAN DOKUMEN CPMI (KMS-011 v3, Lampiran 1).

Three scanned pages, each drawn **letterboxed** inside A4 (see
``pengantar_referral_layout``):

    backend/account/assets/bukti_penyerahan_template_p1.jpg  — Bukti Penyerahan Dokumen
    backend/account/assets/bukti_penyerahan_template_p2.jpg  — Surat Pernyataan
    backend/account/assets/bukti_penyerahan_template_p3.jpg  — Quisioner RBA / OTL

Only identity fields are pre-filled. Checkboxes (Asli / F.Copy, YA / TIDAK),
ongkos transport and signatures are left for the CPMI / staff to complete.
Set DEBUG_GRID to calibrate field positions.
"""

from __future__ import annotations

import io
import os

from django.utils import timezone
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

from account.services.pengantar_medical_pdf import (
    _fmt_date,
    _kilang_from_application,
    _str,
)
from account.services.pengantar_referral_layout import (
    PAGE_H,
    PAGE_W,
    draw_referral_template_letterboxed,
    xy_in_box,
)

DEBUG_GRID = False

_SERVICES_DIR = os.path.dirname(os.path.abspath(__file__))
_ACCOUNT_DIR = os.path.dirname(_SERVICES_DIR)
_ASSETS_DIR = os.path.join(_ACCOUNT_DIR, "assets")

_FONT = "Helvetica"
_FONT_SIZE = 10
_FONT_BOLD = "Helvetica-Bold"
_MIN_FONT_SIZE = 6.5

# (x_frac, y_top_frac, right_x_frac) — baseline of the value, relative to the
# letterboxed template image. right_x_frac bounds the text (shrink-to-fit).
_P1_FIELDS = {
    "tanggal": (0.315, 0.110, 0.745),
    "nama": (0.315, 0.134, 0.745),
    "nik": (0.315, 0.158, 0.745),
    "kilang": (0.315, 0.181, 0.745),
    "nama_cpmi_ttd": (0.648, 0.912, 0.880),
}
_P2_FIELDS = {
    "nama": (0.368, 0.243, 0.854),
    "ttl": (0.368, 0.269, 0.854),
    "nik": (0.368, 0.296, 0.854),
    "alamat": (0.368, 0.322, 0.940),
    "kabupaten": (0.368, 0.348, 0.854),
    "staff": (0.368, 0.374, 0.854),
    "staff_nama": (0.155, 0.891, 0.345),
    "staff_tanggal": (0.170, 0.907, 0.345),
    "cpmi_nama": (0.605, 0.891, 0.900),
    "cpmi_tanggal": (0.620, 0.907, 0.900),
}
_P3_FIELDS = {
    "nama": (0.232, 0.109, 0.488),
    "tanggal": (0.232, 0.132, 0.488),
    "nik": (0.672, 0.132, 0.888),
    "pekerja_nama": (0.228, 0.954, 0.484),
}


def resolve_bukti_penyerahan_template_paths() -> list[str]:
    """Page templates in order; missing pages are returned as ``""``."""
    paths = []
    for page in (1, 2, 3):
        p = os.path.join(_ASSETS_DIR, f"bukti_penyerahan_template_p{page}.jpg")
        paths.append(p if os.path.isfile(p) else "")
    return paths


def _birth_place(profile) -> str:
    return _str(
        (profile.birth_place_text or "").strip()
        or (profile.birth_place.name if profile.birth_place else "")
    )


def _ttl(profile) -> str:
    return ", ".join(
        p for p in (_birth_place(profile), _fmt_date(profile.birth_date)) if p
    )


def _staff_name(profile) -> str:
    referrer = getattr(profile, "referrer", None)
    if not referrer:
        return ""
    return _str(referrer.full_name) or _str(referrer.email)


def _draw_fit(
    c: canvas.Canvas,
    x: float,
    y: float,
    text: str,
    max_w: float,
) -> None:
    """Draw on one line, shrinking the font down to _MIN_FONT_SIZE, then truncating."""
    if not text:
        return
    size = _FONT_SIZE
    while size > _MIN_FONT_SIZE and c.stringWidth(text, _FONT, size) > max_w:
        size -= 0.25
    s = text
    while s and c.stringWidth(s, _FONT, size) > max_w:
        s = s[:-1]
    c.setFont(_FONT, size)
    c.drawString(x, y, s)


def _draw_page(
    c: canvas.Canvas,
    tpl: str,
    fields: dict[str, tuple[float, float, float]],
    values: dict[str, str],
    page_no: int,
) -> None:
    if tpl:
        ox, oy, bw, bh = draw_referral_template_letterboxed(c, tpl)
    else:
        ox, oy, bw, bh = 0.0, 0.0, PAGE_W, PAGE_H
        c.setFont(_FONT_BOLD, 9)
        c.setFillColorRGB(0.7, 0, 0)
        c.drawString(
            35,
            PAGE_H - 40,
            "Template tidak ditemukan: letakkan berkas di account/assets/"
            f"bukti_penyerahan_template_p{page_no}.jpg",
        )

    c.setFillColorRGB(0, 0, 0)
    for key, (xf, ytf, right_f) in fields.items():
        x, y = xy_in_box(ox, oy, bw, bh, xf, ytf)
        _draw_fit(c, x, y, values.get(key, ""), (right_f - xf) * bw)

    if DEBUG_GRID:
        c.setStrokeColorRGB(1, 0, 0)
        c.setFillColorRGB(1, 0, 0)
        c.setFont("Helvetica", 5.5)
        for label, (xf, ytf, right_f) in fields.items():
            x, y = xy_in_box(ox, oy, bw, bh, xf, ytf)
            rx, _ = xy_in_box(ox, oy, bw, bh, right_f, ytf)
            c.line(x, y, rx, y)
            c.line(x, y - 4, x, y + 4)
            c.drawString(x + 2, y + 6, label)
        c.setFillColorRGB(0, 0, 0)
        c.setStrokeColorRGB(0, 0, 0)

    c.showPage()


def generate_bukti_penyerahan_pdf(profile) -> bytes:
    """Bukti Penyerahan Dokumen + Surat Pernyataan + Quisioner RBA/OTL (3 pages)."""
    from account.services.inbound_transport_costs import (
        primary_diterima_job_application_for_profile,
    )

    user = profile.user
    app = primary_diterima_job_application_for_profile(profile)

    nama = _str(user.full_name)
    nik = _str(profile.nik)
    tanggal = _fmt_date(timezone.localdate())
    staff = _staff_name(profile)

    p1, p2, p3 = resolve_bukti_penyerahan_template_paths()

    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)
    c.setTitle(f"Bukti Penyerahan Dokumen - {nama}")

    _draw_page(
        c,
        p1,
        _P1_FIELDS,
        {
            "tanggal": tanggal,
            "nama": nama,
            "nik": nik,
            "kilang": _kilang_from_application(app),
            "nama_cpmi_ttd": nama,
        },
        1,
    )
    _draw_page(
        c,
        p2,
        _P2_FIELDS,
        {
            "nama": nama,
            "ttl": _ttl(profile),
            "nik": nik,
            "alamat": " ".join((profile.address or "").split()),
            "kabupaten": _str(profile.district.name if profile.district else ""),
            "staff": staff,
            "staff_nama": staff,
            "staff_tanggal": tanggal,
            "cpmi_nama": nama,
            "cpmi_tanggal": tanggal,
        },
        2,
    )
    _draw_page(
        c,
        p3,
        _P3_FIELDS,
        {
            "nama": nama,
            "tanggal": tanggal,
            "nik": nik,
            "pekerja_nama": nama,
        },
        3,
    )

    c.save()
    buf.seek(0)
    return buf.read()
