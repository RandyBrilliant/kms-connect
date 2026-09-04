"""
PDF generation for the official CPMI CV (daftar riwayat hidup).

The blank form is drawn as a full-page background (native 540×780 pt), then
applicant values and pas foto are overlaid at AcroForm field coordinates.
"""

from __future__ import annotations

import io
import os
from datetime import date

from django.utils import timezone
from PIL import Image
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfgen import canvas

from account.services.biodata_pdf import _read_field_file_bytes

DEBUG_GRID = False

# Native page size of cv_template.pdf (not A4).
PAGE_W = 540.0
PAGE_H = 780.0

_SERVICES_DIR = os.path.dirname(os.path.abspath(__file__))
_ACCOUNT_DIR = os.path.dirname(_SERVICES_DIR)
_ASSETS_DIR = os.path.join(_ACCOUNT_DIR, "assets")
TEMPLATE_PATH = os.path.join(_ASSETS_DIR, "cv_template.png")

FONT_NAME = "Helvetica"
FONT_BOLD = "Helvetica-Bold"

# AcroForm widget rects: (x1, y1, x2, y2) with origin at bottom-left.
_R_SR = (36.5, 744.89, 187.5, 764.89)
_R_NAMA = (80.0, 711.75, 335.25, 741.75)
_R_TTL = (116.75, 688.61, 315.75, 708.61)
_R_SEKOLAH = (87.88, 622.64, 309.38, 642.64)
_R_JURUSAN = (64.25, 606.14, 309.75, 621.75)

_R_WORK = (
    (49.10, 537.12, 300.99, 557.12),
    (48.61, 516.75, 301.49, 533.87),
    (49.35, 488.13, 301.24, 508.13),
    (49.10, 469.07, 300.99, 485.88),
    (48.86, 442.34, 300.25, 462.34),
    (48.61, 421.89, 299.50, 440.37),
)

_R_PASPOR_YA = (240.0, 339.14, 255.0, 354.14)
_R_PASPOR_TIDAK = (275.25, 339.14, 290.25, 354.14)
_R_AJUKAN_PASPOR_YA = (240.0, 314.14, 255.0, 329.14)
_R_AJUKAN_PASPOR_TIDAK = (275.25, 314.14, 290.25, 329.14)
_R_SAUDARA_MEDAN_YA = (240.0, 270.14, 255.0, 285.14)
_R_SAUDARA_MEDAN_TIDAK = (275.25, 270.14, 290.25, 285.14)
_R_ALAMAT_SAUDARA = (41.22, 224.21, 299.50, 240.10)
_R_TINGGAL_SAUDARA_YA = (240.0, 186.14, 255.0, 201.14)
_R_TINGGAL_SAUDARA_TIDAK = (275.25, 186.14, 290.25, 201.14)

_R_TELP = (356.62, 480.59, 507.62, 500.59)
_R_EMAIL = (356.62, 442.34, 507.62, 462.34)
_R_ALAMAT_KTP = (
    (356.62, 409.97, 523.01, 428.57),
    (356.62, 391.09, 522.52, 408.70),
    (356.62, 371.23, 522.52, 389.83),
)
_R_ALAMAT_SEKARANG = (
    (356.13, 338.44, 521.03, 359.14),
    (356.13, 315.60, 521.53, 336.62),
)
_R_KEMAMPUAN = (
    (340.72, 250.53, 514.07, 265.66),
    (340.72, 233.64, 514.07, 247.28),
    (340.72, 215.76, 515.07, 230.39),
)
_R_BAHASA = (
    (340.72, 155.66, 514.07, 174.27),
    (340.73, 135.79, 514.07, 152.91),
)
_R_TGL = (447.52, 10.72, 518.54, 25.03)

# Inner area of the tall green rounded photo frame (x, y_bottom, w, h).
_PHOTO = (344.0, 535.0, 158.0, 180.0)
_PHOTO_RADIUS = 20.0


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


def _mentions_medan(*parts: str) -> bool:
    return any("MEDAN" in (p or "").upper() for p in parts if p)


def _place_name(obj) -> str:
    if obj is None:
        return ""
    return _str(getattr(obj, "name", ""))


def _wrap(text: str, max_width: float, font: str, size: float, max_lines: int) -> list[str]:
    text = _str(text)
    if not text:
        return []
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = f"{current} {word}".strip()
        if pdfmetrics.stringWidth(trial, font, size) <= max_width or not current:
            current = trial
            continue
        lines.append(current)
        current = word
        if len(lines) == max_lines:
            current = ""
            break
    if current and len(lines) < max_lines:
        lines.append(current)
    if lines and pdfmetrics.stringWidth(lines[-1], font, size) > max_width:
        last = lines[-1]
        while last and pdfmetrics.stringWidth(last + "…", font, size) > max_width:
            last = last[:-1]
        lines[-1] = f"{last.rstrip()}…" if last else "…"
    return lines[:max_lines]


def _draw_fitted(
    c: canvas.Canvas,
    rect: tuple[float, float, float, float],
    text: str,
    *,
    font: str = FONT_NAME,
    size: float = 8.0,
    max_lines: int = 1,
) -> None:
    text = _str(text)
    if not text:
        return
    x1, y1, x2, y2 = rect
    pad = 2.5
    max_width = max(4.0, x2 - x1 - pad * 2)
    box_h = y2 - y1
    fit_size = size
    while fit_size > 5.5 and pdfmetrics.stringWidth(text, font, fit_size) > max_width and max_lines == 1:
        fit_size -= 0.4
    lines = _wrap(text, max_width, font, fit_size, max_lines)
    if not lines:
        return
    line_h = fit_size + 1.2
    total_h = line_h * len(lines) - 1.2
    y = y1 + (box_h - total_h) / 2.0
    c.setFillColorRGB(0, 0, 0)
    c.setFont(font, fit_size)
    for i, line in enumerate(lines):
        c.drawString(x1 + pad, y + (len(lines) - 1 - i) * line_h, line)


def _draw_check(c: canvas.Canvas, rect: tuple[float, float, float, float]) -> None:
    x1, y1, x2, y2 = rect
    c.setFillColorRGB(0, 0, 0)
    c.setFont(FONT_BOLD, 9)
    c.drawCentredString((x1 + x2) / 2.0, y1 + 2.5, "X")


def _work_pair(exp) -> tuple[str, str]:
    company = _str(exp.company_name)
    position = _str(exp.position)
    line1 = " — ".join(p for p in (company, position) if p)
    loc_parts = [_str(exp.location)]
    country = getattr(exp, "country", None)
    if country:
        loc_parts.append(_str(getattr(country, "name", None) or country))
    loc = ", ".join(p for p in loc_parts if p)
    period = ""
    if exp.start_date:
        period = _fmt_date(exp.start_date)
    if exp.end_date:
        period = f"{period} – {_fmt_date(exp.end_date)}" if period else _fmt_date(exp.end_date)
    elif exp.still_employed:
        period = f"{period} – sekarang" if period else "sekarang"
    line2 = " · ".join(p for p in (loc, period) if p)
    return line1, line2


def _ktp_text(profile) -> str:
    parts = [
        _str(profile.address),
        _place_name(getattr(profile, "village", None)),
        _place_name(getattr(profile, "district", None)),
        _place_name(getattr(profile, "province", None)),
        _str(getattr(profile, "postal_code", "")),
    ]
    # Keep address first; drop duplicates while preserving order.
    seen: set[str] = set()
    ordered: list[str] = []
    for part in parts:
        key = part.upper()
        if not part or key in seen:
            continue
        seen.add(key)
        ordered.append(part)
    return ", ".join(ordered)


def _skills(profile, work_exps) -> list[str]:
    skills: list[str] = []
    major = _str(profile.education_major)
    if major:
        skills.append(major)
    for exp in work_exps:
        for part in (_str(exp.department), _str(exp.position)):
            if part and part.upper() not in {s.upper() for s in skills}:
                skills.append(part)
        if len(skills) >= 3:
            break
    return skills[:3]


def _photo_cover(data: bytes, width_pt: float, height_pt: float) -> io.BytesIO:
    """Center-crop the pas foto to fill the template well."""
    src = Image.open(io.BytesIO(data)).convert("RGB")
    tw = max(32, int(width_pt * 3))
    th = max(32, int(height_pt * 3))
    scale = max(tw / src.width, th / src.height)
    new_w = max(tw, int(src.width * scale))
    new_h = max(th, int(src.height * scale))
    resized = src.resize((new_w, new_h), Image.Resampling.LANCZOS)
    left = (new_w - tw) // 2
    top = (new_h - th) // 2
    cropped = resized.crop((left, top, left + tw, top + th))
    out = io.BytesIO()
    cropped.save(out, format="JPEG", quality=90)
    out.seek(0)
    return out


def _photo_bytes(profile) -> bytes | None:
    if profile.photo and profile.photo.name:
        data = _read_field_file_bytes(profile.photo)
        if data:
            return data
    documents = getattr(profile, "_prefetched_objects_cache", {}).get("documents")
    if documents is None:
        documents = profile.documents.select_related("document_type").all()
    for doc in documents:
        code = getattr(getattr(doc, "document_type", None), "code", "")
        if code == "pas-foto" and doc.file and doc.file.name:
            data = _read_field_file_bytes(doc.file)
            if data:
                return data
    return None


def _draw_debug(c: canvas.Canvas) -> None:
    c.setStrokeColorRGB(1, 0, 0)
    c.setFillColorRGB(1, 0, 0)
    c.setFont(FONT_NAME, 5)
    rects = {
        "sr": _R_SR,
        "nama": _R_NAMA,
        "ttl": _R_TTL,
        "sekolah": _R_SEKOLAH,
        "jurusan": _R_JURUSAN,
        "telp": _R_TELP,
        "email": _R_EMAIL,
        "tgl": _R_TGL,
        "alamat_saudara": _R_ALAMAT_SAUDARA,
    }
    for i, r in enumerate(_R_WORK, start=1):
        rects[f"work{i}"] = r
    for i, r in enumerate(_R_ALAMAT_KTP, start=1):
        rects[f"ktp{i}"] = r
    for i, r in enumerate(_R_ALAMAT_SEKARANG, start=1):
        rects[f"now{i}"] = r
    for i, r in enumerate(_R_KEMAMPUAN, start=1):
        rects[f"skill{i}"] = r
    for i, r in enumerate(_R_BAHASA, start=1):
        rects[f"lang{i}"] = r
    for label, (x1, y1, x2, y2) in rects.items():
        c.rect(x1, y1, x2 - x1, y2 - y1, stroke=1, fill=0)
        c.drawString(x1, y2 + 1, label)
    x, y, w, h = _PHOTO
    c.setStrokeColorRGB(0, 0, 1)
    c.rect(x, y, w, h, stroke=1, fill=0)
    c.setStrokeColorRGB(0, 0, 0)
    c.setFillColorRGB(0, 0, 0)


def generate_cv_pdf(profile) -> bytes:
    """Return a one-page filled CV PDF for the given ApplicantProfile."""
    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=(PAGE_W, PAGE_H))

    if os.path.exists(TEMPLATE_PATH):
        c.drawImage(
            TEMPLATE_PATH,
            0,
            0,
            width=PAGE_W,
            height=PAGE_H,
            preserveAspectRatio=False,
            mask="auto",
        )

    user = profile.user
    full_name = _str(user.full_name).upper()
    email = _str(user.email)
    phone = _str(profile.contact_phone)
    birth_place = _str(
        (getattr(profile, "birth_place_text", None) or "").strip()
        or _place_name(getattr(profile, "birth_place", None))
    )
    ttl = ", ".join(p for p in (birth_place, _fmt_date(profile.birth_date)) if p)
    school = _str(profile.get_education_level_display() if profile.education_level else "")
    major = _str(profile.education_major)

    work_exps = list(profile.work_experiences.all()[:3])
    ktp_text = _ktp_text(profile)
    ktp_lines = _wrap(ktp_text, _R_ALAMAT_KTP[0][2] - _R_ALAMAT_KTP[0][0] - 5, FONT_NAME, 7.2, 3)

    from_medan = _mentions_medan(_place_name(getattr(profile, "district", None)))
    family_bits = (
        _str(profile.family_address),
        _place_name(getattr(profile, "family_village", None)),
        _place_name(getattr(profile, "family_district", None)),
        _place_name(getattr(profile, "family_province", None)),
    )
    family_in_medan = _mentions_medan(*family_bits)
    saudara_addr = ", ".join(p for p in family_bits if p) if family_in_medan else ""

    _draw_fitted(c, _R_SR, _str(profile.register_number), font=FONT_BOLD, size=8)
    _draw_fitted(c, _R_NAMA, full_name, font=FONT_BOLD, size=11)
    _draw_fitted(c, _R_TTL, ttl.upper() if ttl else "", size=8)
    _draw_fitted(c, _R_SEKOLAH, school, size=8)
    _draw_fitted(c, _R_JURUSAN, major.upper() if major else "", size=8)

    for i, exp in enumerate(work_exps):
        line1, line2 = _work_pair(exp)
        _draw_fitted(c, _R_WORK[i * 2], line1, size=7.5)
        _draw_fitted(c, _R_WORK[i * 2 + 1], line2, size=7.0)

    if profile.has_passport is True:
        _draw_check(c, _R_PASPOR_YA)
        _draw_check(c, _R_AJUKAN_PASPOR_YA)
    elif profile.has_passport is False:
        _draw_check(c, _R_PASPOR_TIDAK)

    if not from_medan:
        if family_in_medan:
            _draw_check(c, _R_SAUDARA_MEDAN_YA)
            _draw_fitted(c, _R_ALAMAT_SAUDARA, saudara_addr, size=7.0)
        elif any(family_bits):
            _draw_check(c, _R_SAUDARA_MEDAN_TIDAK)

    _draw_fitted(c, _R_TELP, phone, size=7.5)
    _draw_fitted(c, _R_EMAIL, email, size=7.0)
    for rect, line in zip(_R_ALAMAT_KTP, ktp_lines):
        _draw_fitted(c, rect, line, size=7.0)
    # Current address is not stored separately; reuse KTP when present.
    for rect, line in zip(_R_ALAMAT_SEKARANG, ktp_lines[:2]):
        _draw_fitted(c, rect, line, size=7.0)

    for rect, skill in zip(_R_KEMAMPUAN, _skills(profile, work_exps)):
        _draw_fitted(c, rect, skill, size=7.0)

    _draw_fitted(c, _R_BAHASA[0], "INDONESIA", size=7.0)
    _draw_fitted(c, _R_TGL, _fmt_date(timezone.localdate()), size=7.5)

    photo_data = _photo_bytes(profile)
    if photo_data:
        px, py, pw, ph = _PHOTO
        c.saveState()
        clip = c.beginPath()
        clip.roundRect(px, py, pw, ph, _PHOTO_RADIUS)
        c.clipPath(clip, stroke=0, fill=0)
        c.drawImage(
            ImageReader(_photo_cover(photo_data, pw, ph)),
            px,
            py,
            width=pw,
            height=ph,
            preserveAspectRatio=False,
            mask="auto",
        )
        c.restoreState()

    if DEBUG_GRID:
        _draw_debug(c)

    c.save()
    buf.seek(0)
    return buf.read()
