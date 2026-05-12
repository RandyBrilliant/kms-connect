"""
PDF overlay for SURAT PENGANTAR TES PSIKOLOGI CPMI.

Place the scanned blank form image at **one** of:

    backend/account/assets/pengantar_psikologi_template.jpg
    backend/account/assets/pengantar_psikologi_template.jpeg
    backend/account/assets/pengantar_psikologi_template.png

The template is drawn **letterboxed** inside A4 (see ``pengantar_referral_layout``)
so row coordinates match the scan. Set DEBUG_GRID = True to tune positions.
"""

from __future__ import annotations

import io
import os
from datetime import date

from django.utils import timezone
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

from account.services.pengantar_referral_layout import (
    LX,
    PAGE_H,
    PAGE_W,
    R1,
    R2,
    R3,
    R4,
    R5,
    R6,
    R7,
    R_MEDAN,
    RX,
    RX_UMUR,
    draw_referral_template_letterboxed,
    draw_wrapped_lines,
    xy_in_box,
)

DEBUG_GRID = False

_SERVICES_DIR = os.path.dirname(os.path.abspath(__file__))
_ACCOUNT_DIR = os.path.dirname(_SERVICES_DIR)
_ASSETS_DIR = os.path.join(_ACCOUNT_DIR, "assets")

_FONT = "Helvetica"
_FONT_SIZE = 8.8
_FONT_BOLD = "Helvetica-Bold"


def resolve_psychology_referral_template_path() -> str:
    for name in (
        "pengantar_psikologi_template.jpg",
        "pengantar_psikologi_template.jpeg",
        "pengantar_psikologi_template.png",
    ):
        p = os.path.join(_ASSETS_DIR, name)
        if os.path.isfile(p):
            return p
    return ""


def _fmt_date(d) -> str:
    if d is None:
        return ""
    if isinstance(d, date):
        return d.strftime("%d/%m/%Y")
    return str(d)


def _str(value, fallback: str = "") -> str:
    if value is None:
        return fallback
    s = str(value).strip()
    return s if s else fallback


def _age_years(birth: date | None) -> str:
    if birth is None:
        return ""
    today = timezone.localdate()
    years = today.year - birth.year - (
        (today.month, today.day) < (birth.month, birth.day)
    )
    return str(max(0, years))


def _kilang_from_application(app) -> str:
    """Worksite / kilang label from the active lamaran."""
    if not app:
        return ""
    job = getattr(app, "job", None)
    if not job:
        return ""
    title = (getattr(job, "title", None) or "").strip()
    company = getattr(job, "company", None)
    cname = (getattr(company, "name", None) or "").strip() if company else ""
    if title and cname:
        return f"{title} — {cname}"
    return title or cname


def _sr_display(profile) -> str:
    """SR line: prefer SIP (surat ijin penempatan); fallback no JO."""
    sip = _str(getattr(profile, "no_sip", None))
    if sip:
        return sip
    return _str(getattr(profile, "no_jo", None))


_FX_RIGHT = 0.94


def _draw_debug_grid(
    c: canvas.Canvas,
    ox: float,
    oy: float,
    bw: float,
    bh: float,
    fields: dict[str, tuple[float, float]],
) -> None:
    c.setStrokeColorRGB(1, 0, 0)
    c.setFillColorRGB(1, 0, 0)
    c.setFont("Helvetica", 5.5)
    for label, (xf, ytf) in fields.items():
        x, y = xy_in_box(ox, oy, bw, bh, xf, ytf)
        c.line(x - 4, y, x + 4, y)
        c.line(x, y - 4, x, y + 4)
        c.drawString(x + 5, y + 1, label)
    c.setFillColorRGB(0, 0, 0)
    c.setStrokeColorRGB(0, 0, 0)


def generate_pengantar_psikologi_pdf(profile) -> bytes:
    """
    Build one-page PDF with template background + overlaid applicant data.

    Data sources:
      - Tanggal tes: ``tgl_fwcm_psikotes`` (jadwal FWCMS/psikotes).
      - No. REG PMI: ``register_number``.
      - No ID SISKOTKLN: ``no_id_sisko``.
      - Kilang: judul lowongan + perusahaan dari lamaran DITERIMA (jika ada).
      - Nama, NIK, TTL, umur, nama bapak: profil.
      - SR: ``no_sip`` lalu ``no_jo``.
      - Medan, tanggal: hari ini (zona waktu aktif Django).
    """
    from account.services.inbound_transport_costs import (
        primary_diterima_job_application_for_profile,
    )

    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)

    tpl = resolve_psychology_referral_template_path()
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
            "pengantar_psikologi_template.jpg (atau .jpeg / .png)",
        )
        c.setFillColorRGB(0, 0, 0)

    def pos(xf: float, ytf: float) -> tuple[float, float]:
        return xy_in_box(ox, oy, bw, bh, xf, ytf)

    user = profile.user
    app = primary_diterima_job_application_for_profile(profile)

    tanggal_tes = _fmt_date(getattr(profile, "tgl_fwcm_psikotes", None))
    reg_pmi = _str(getattr(profile, "register_number", None))
    sisko = _str(getattr(profile, "no_id_sisko", None))
    kilang = _kilang_from_application(app)
    nama = _str(user.full_name)
    nik = _str(profile.nik)
    ttl = _fmt_date(profile.birth_date)
    umur = _age_years(profile.birth_date)
    bapak = _str(profile.father_name)
    sr = _sr_display(profile)
    medan_tgl = _fmt_date(timezone.localdate())

    c.setFont(_FONT, _FONT_SIZE)
    c.setFillColorRGB(0, 0, 0)
    right = ox + _FX_RIGHT * bw

    def draw(xy: tuple[float, float], text: str, max_w: float | None = None) -> None:
        if not text:
            return
        x, y = xy
        s = text
        if max_w:
            while s and c.stringWidth(s, _FONT, _FONT_SIZE) > max_w:
                s = s[:-1]
        c.drawString(x, y, s)

    p_tgl = pos(LX, R1)
    p_reg = pos(RX, R1)
    p_sisko = pos(LX, R2)
    p_kilang = pos(RX, R2)
    p_nama = pos(LX, R3)
    p_nik = pos(LX, R4)
    p_ttl = pos(LX, R5)
    p_umur = pos(RX_UMUR, R5)
    p_bapak = pos(LX, R6)
    p_sr = pos(LX, R7)
    p_medan = pos(RX, R_MEDAN)

    mw = right - p_nama[0]
    kilang_max_w = max(8.0, right - p_kilang[0] - 4.0)

    draw(p_tgl, tanggal_tes, max_w=0.22 * bw)
    draw(p_reg, reg_pmi, max_w=0.34 * bw)
    draw(p_sisko, sisko, max_w=0.22 * bw)
    draw_wrapped_lines(
        c,
        p_kilang[0],
        p_kilang[1],
        kilang,
        kilang_max_w,
        _FONT,
        _FONT_SIZE,
        max_lines=3,
        line_height=_FONT_SIZE * 1.02,
    )
    draw(p_nama, nama, max_w=mw)
    draw(p_nik, nik, max_w=mw)
    draw(p_ttl, ttl, max_w=0.36 * bw)
    draw(p_umur, umur, max_w=0.10 * bw)
    draw(p_bapak, bapak, max_w=mw)
    draw(p_sr, sr, max_w=mw)
    draw(p_medan, medan_tgl, max_w=0.28 * bw)

    if DEBUG_GRID:
        _draw_debug_grid(
            c,
            ox,
            oy,
            bw,
            bh,
            {
                "tgl_tes": (LX, R1),
                "reg": (RX, R1),
                "sisko": (LX, R2),
                "kilang": (RX, R2),
                "nama": (LX, R3),
                "nik": (LX, R4),
                "ttl": (LX, R5),
                "umur": (RX_UMUR, R5),
                "bapak": (LX, R6),
                "sr": (LX, R7),
                "medan": (RX, R_MEDAN),
            },
        )

    c.save()
    buf.seek(0)
    return buf.read()
