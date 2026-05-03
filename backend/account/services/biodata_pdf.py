"""
PDF generation service for BIODATA CALON PEKERJA MIGRAN INDONESIA (CPMI).

Strategy: use the official blank form as a full-page background image, then
overlay field values at calibrated coordinates.  The template image must be
placed at:

    backend/account/assets/biodata_template.png

All coordinate constants are expressed as FRACTIONS of the A4 page dimensions
(PAGE_W = 595.28 pt, PAGE_H = 841.89 pt) so they are independent of the
template image resolution.

  x = x_fraction * PAGE_W       (0.0 = left edge, 1.0 = right edge)
  y = (1 - y_fraction) * PAGE_H (0.0 = top of page, 1.0 = bottom)

To calibrate, flip DEBUG_GRID = True and open the generated PDF — red
crosshairs with labels will appear at every field position.  Adjust the
x/y fraction constants below until the crosshairs sit inside the correct
input boxes, then set DEBUG_GRID = False.
"""

import io
import os
from datetime import date

from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader

# ─── Debug flag ─────────────────────────────────────────────────────────────
DEBUG_GRID = False

# ─── Page dimensions ────────────────────────────────────────────────────────
PAGE_W, PAGE_H = A4  # 595.28 × 841.89 pt

# ─── Template image path ────────────────────────────────────────────────────
_SERVICES_DIR = os.path.dirname(os.path.abspath(__file__))
_ACCOUNT_DIR  = os.path.dirname(_SERVICES_DIR)
TEMPLATE_PATH = os.path.join(_ACCOUNT_DIR, "assets", "biodata_template.png")

# ─── Typography ─────────────────────────────────────────────────────────────
FONT_NAME = "Helvetica"
FONT_SIZE = 8.5
FONT_BOLD = "Helvetica-Bold"

# ─── Coordinate helper ───────────────────────────────────────────────────────
def _frac(x_frac: float, y_top_frac: float) -> tuple:
    """
    Convert page-fraction coordinates to ReportLab points.
    x_frac:       0.0 = left edge  → 1.0 = right edge
    y_top_frac:   0.0 = top of page → 1.0 = bottom of page
    """
    return (x_frac * PAGE_W, (1.0 - y_top_frac) * PAGE_H)

# ─── Field positions as fractions of A4 page ────────────────────────────────
#
# Fractions measured from the filled reference scan (794×1123 px, A4 at 96 dpi).
# Adjust any value to fine-tune; fractions work the same regardless of image size.
#
# Left edge of input boxes:  x ≈ 0.479  (after the label column)
# Right edge of input boxes: x ≈ 0.958

_FX_FIELD  = 0.479   # left start of input boxes
_FX_RIGHT  = 0.958   # right edge of input boxes

# Section I
_F_NAMA_PERUSAHAAN = _frac(0.479, 0.190)
_F_NAMA_CPMI       = _frac(0.479, 0.211)
_F_TTL             = _frac(0.479, 0.233)
_F_ALAMAT_KTP      = _frac(0.479, 0.257)
_F_KOTA_KTP        = _frac(0.479, 0.279)
_F_NOHP            = _frac(0.479, 0.300)
_F_EMAIL           = _frac(0.479, 0.323)

# Jumlah Saudara — value before "Orang" and value after "Anak ke"
_F_SAUDARA_VAL = _frac(0.479, 0.345)
_F_ANAK_VAL    = _frac(0.730, 0.345)

# Pengalaman Kerja (number prefix is pre-printed; text starts slightly right)
_F_PENGALAMAN_1 = _frac(0.497, 0.368)
_F_PENGALAMAN_2 = _frac(0.497, 0.390)

# Section II — parents / spouse
# "Umur" blank is between the pre-printed "Umur :" and "Tahun" labels.
# The blank sits at roughly x=64% of page width; adjust _FX_UMUR if needed.
_FX_UMUR   = 0.789
_F_AYAH_NAME = _frac(0.479, 0.414)
_F_AYAH_AGE  = _frac(_FX_UMUR, 0.414)   # age value in "Umur :" blank
_F_PKJ_AYAH  = _frac(0.479, 0.437)
_F_IBU_NAME  = _frac(0.479, 0.459)
_F_IBU_AGE   = _frac(_FX_UMUR, 0.459)   # age value in "Umur :" blank
_F_PKJ_IBU   = _frac(0.479, 0.481)
_F_ALAMAT_KEL = _frac(0.479, 0.504)
_F_KOTA_KEL   = _frac(0.479, 0.525)
_F_NOHP_KEL   = _frac(0.479, 0.547)

# Section III — Keterangan (below the family section)
_F_KETERANGAN_1 = _frac(0.479, 0.579)
_F_KETERANGAN_2 = _frac(0.479, 0.599)

# Name max width for the left part of the Ayah/Ibu row (stops before "Umur :")
_FX_UMUR_LABEL = 0.620   # "Umur :" pre-printed label starts here

# Photo box — top-left corner of the 3×4 placeholder (top-right of form)
# Adjust _FX_PHOTO / _FY_PHOTO to move; PHOTO_W_PT / PHOTO_H_PT for size.
_FX_PHOTO  = 0.790
_FY_PHOTO  = 0.076   # y_top_frac
PHOTO_W_PT = 92.0
PHOTO_H_PT = 115.0   # 3:4 ratio


def _fmt_date(d) -> str:
    if d is None:
        return ""
    if isinstance(d, date):
        return d.strftime("%d/%m/%Y")
    return str(d)


def _str(value, fallback="") -> str:
    """Safe string conversion; returns fallback for None/empty."""
    if value is None:
        return fallback
    s = str(value).strip()
    return s if s else fallback


def _work_exp_summary(exp) -> str:
    """One-line summary of a WorkExperience instance."""
    parts = []
    if exp.company_name:
        parts.append(_str(exp.company_name))
    if exp.position:
        parts.append(_str(exp.position))
    period = ""
    if exp.start_date:
        period = _fmt_date(exp.start_date)
    if exp.end_date:
        period += f" – {_fmt_date(exp.end_date)}"
    elif exp.still_employed:
        period += " – sekarang"
    if period:
        parts.append(f"({period})")
    return "  ·  ".join(parts)


def _read_field_file_bytes(field_file) -> bytes | None:
    """
    Read raw bytes from a Django FieldFile, working for both storage backends:

    • Local FileSystemStorage (development): resolves field_file.path to an
      absolute disk path and uses plain Python open() — no storage-layer
      abstraction, reliably reads the file.

    • Remote storage (DigitalOcean Spaces / S3 in production): field_file.path
      raises NotImplementedError, so we fall back to the Django storage API
      (field_file.open / read / close).
    """
    # ── Local storage: use the absolute filesystem path directly ────────────
    try:
        abs_path = field_file.path   # NotImplementedError on S3/Spaces
        with open(abs_path, "rb") as f:
            return f.read()
    except NotImplementedError:
        pass   # remote storage — try the storage API below
    except OSError:
        return None   # path resolved but file missing on disk

    # ── Remote storage (S3 / DigitalOcean Spaces) ───────────────────────────
    try:
        field_file.open("rb")
        data = field_file.read()
        field_file.close()
        return data
    except Exception:
        return None


def _draw_debug_grid(c: canvas.Canvas, fields: dict):
    """Draw small red crosses at every field position for calibration."""
    c.setStrokeColorRGB(1, 0, 0)
    c.setFillColorRGB(1, 0, 0)
    c.setFont("Helvetica", 5.5)
    for label, (x, y) in fields.items():
        c.line(x - 4, y, x + 4, y)
        c.line(x, y - 4, x, y + 4)
        c.drawString(x + 5, y + 1, label)
    c.setFillColorRGB(0, 0, 0)
    c.setStrokeColorRGB(0, 0, 0)


def generate_biodata_pdf(profile) -> bytes:
    """
    Generate a one-page Biodata CPMI PDF for the given ApplicantProfile instance.
    Returns raw PDF bytes.
    """
    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)

    # ── 1. Background template image ─────────────────────────────────────────
    if os.path.exists(TEMPLATE_PATH):
        c.drawImage(
            TEMPLATE_PATH,
            0, 0,
            width=PAGE_W,
            height=PAGE_H,
            preserveAspectRatio=False,
        )
    else:
        c.setFont(FONT_BOLD, 8)
        c.setFillColorRGB(0.7, 0, 0)
        c.drawString(35, PAGE_H - 30,
                     "Template tidak ditemukan: account/assets/biodata_template.png")
        c.setFillColorRGB(0, 0, 0)

    # ── 2. Collect data ───────────────────────────────────────────────────────
    user        = profile.user
    full_name   = _str(user.full_name)
    email       = _str(user.email.upper())
    phone       = _str(profile.contact_phone)
    address     = _str(profile.address)

    birth_place = _str(
        (profile.birth_place_text or "").strip()
        or (profile.birth_place.name if profile.birth_place else "")
    )
    birth_date  = _fmt_date(profile.birth_date)
    ttl = ", ".join(p for p in [birth_place, birth_date] if p)

    ktp_parts = [
        _str(profile.village.name   if profile.village   else ""),
        _str(profile.district.name  if profile.district  else ""),
        _str(profile.province.name  if profile.province  else ""),
    ]
    ktp_location = ", ".join(p for p in ktp_parts if p)

    saudara = _str(profile.sibling_count, "-")
    anak_ke = _str(profile.birth_order, "-")

    work_exps    = list(profile.work_experiences.order_by("start_date")[:2])
    pengalaman_1 = _work_exp_summary(work_exps[0]) if len(work_exps) > 0 else ""
    pengalaman_2 = _work_exp_summary(work_exps[1]) if len(work_exps) > 1 else ""

    # Ayah / Suami row
    marital = _str(profile.marital_status)
    if marital in ("MENIKAH", "CERAI HIDUP", "CERAI MATI") and profile.spouse_name:
        ayah_name = _str(profile.spouse_name)
        ayah_age  = _str(profile.spouse_age, "")
        ayah_pkj  = _str(profile.spouse_occupation)
        if getattr(profile, "spouse_almarhum", False):
            g = _str(getattr(profile, "gender", "") or "")
            if ayah_name:
                if g == "M":
                    ayah_name = f"{ayah_name} (Almarhumah)"
                elif g == "F":
                    ayah_name = f"{ayah_name} (Almarhum)"
                else:
                    ayah_name = f"{ayah_name} (Almarhum/Almarhumah)"
            else:
                if g == "M":
                    ayah_name = "Almarhumah"
                elif g == "F":
                    ayah_name = "Almarhum"
                else:
                    ayah_name = "Almarhum/Almarhumah"
    else:
        ayah_name = _str(profile.father_name)
        ayah_age  = _str(profile.father_age, "")
        ayah_pkj  = _str(profile.father_occupation)
        if getattr(profile, "father_almarhum", False):
            if ayah_name:
                ayah_name = f"{ayah_name} (Almarhum)"
            else:
                ayah_name = "Almarhum"

    ibu_name = _str(profile.mother_name)
    ibu_age  = _str(profile.mother_age, "")
    ibu_pkj  = _str(profile.mother_occupation)
    if getattr(profile, "mother_almarhum", False):
        if ibu_name:
            ibu_name = f"{ibu_name} (Almarhumah)"
        else:
            ibu_name = "Almarhumah"

    family_parts = [
        _str(profile.family_village.name   if profile.family_village   else ""),
        _str(profile.family_district.name  if profile.family_district  else ""),
        _str(profile.family_province.name  if profile.family_province  else ""),
    ]
    family_addr     = _str(profile.family_address)
    family_location = ", ".join(p for p in family_parts if p)
    family_phone    = _str(profile.father_phone or profile.mother_phone)

    notes      = _str(getattr(profile, "notes", ""))
    note_line1 = notes[:90]      if notes           else ""
    note_line2 = notes[90:180]   if len(notes) > 90 else ""

    # ── 3. Draw helper ────────────────────────────────────────────────────────
    c.setFont(FONT_NAME, FONT_SIZE)
    c.setFillColorRGB(0, 0, 0)

    right = _FX_RIGHT * PAGE_W   # right edge of input boxes in points

    def draw(xy, text, max_w=None):
        """Draw text at (x, y) tuple, optionally truncating to max_w points."""
        if not text:
            return
        x, y = xy
        if max_w:
            while text and c.stringWidth(text, FONT_NAME, FONT_SIZE) > max_w:
                text = text[:-1]
        c.drawString(x, y, text)

    # ── 4. Draw all fields ────────────────────────────────────────────────────

    # Section I
    draw(_F_NAMA_CPMI,  full_name,    max_w=right - _F_NAMA_CPMI[0])
    draw(_F_TTL,        ttl,          max_w=right - _F_TTL[0])
    draw(_F_ALAMAT_KTP, address,      max_w=right - _F_ALAMAT_KTP[0])
    draw(_F_KOTA_KTP,   ktp_location, max_w=right - _F_KOTA_KTP[0])
    draw(_F_NOHP,       phone,        max_w=right - _F_NOHP[0])
    draw(_F_EMAIL,      email,        max_w=right - _F_EMAIL[0])

    # "X  Orang   Anak ke  Y" — values sit inside the pre-printed boxes
    draw(_F_SAUDARA_VAL, saudara)
    draw(_F_ANAK_VAL,    anak_ke)

    draw(_F_PENGALAMAN_1, pengalaman_1, max_w=right - _F_PENGALAMAN_1[0])
    draw(_F_PENGALAMAN_2, pengalaman_2, max_w=right - _F_PENGALAMAN_2[0])

    # Section II — cap name width so it doesn't spill into the "Umur :" label
    name_max = (_FX_UMUR_LABEL * PAGE_W) - _F_AYAH_NAME[0] - 6
    draw(_F_AYAH_NAME, ayah_name, max_w=name_max)
    draw(_F_AYAH_AGE,  ayah_age)
    draw(_F_PKJ_AYAH,  ayah_pkj,  max_w=right - _F_PKJ_AYAH[0])

    draw(_F_IBU_NAME,  ibu_name,  max_w=name_max)
    draw(_F_IBU_AGE,   ibu_age)
    draw(_F_PKJ_IBU,   ibu_pkj,   max_w=right - _F_PKJ_IBU[0])

    draw(_F_ALAMAT_KEL,  family_addr,     max_w=right - _F_ALAMAT_KEL[0])
    draw(_F_KOTA_KEL,    family_location, max_w=right - _F_KOTA_KEL[0])
    draw(_F_NOHP_KEL,    family_phone,    max_w=right - _F_NOHP_KEL[0])

    # Section III
    draw(_F_KETERANGAN_1, note_line1, max_w=right - _F_KETERANGAN_1[0])
    draw(_F_KETERANGAN_2, note_line2, max_w=right - _F_KETERANGAN_2[0])

    # ── 5. Photo ──────────────────────────────────────────────────────────────
    if profile.photo and profile.photo.name:
        photo_data = _read_field_file_bytes(profile.photo)
        if photo_data:
            photo_bytes    = io.BytesIO(photo_data)
            photo_x        = _FX_PHOTO * PAGE_W
            photo_y_bottom = (1.0 - _FY_PHOTO) * PAGE_H - PHOTO_H_PT
            c.drawImage(
                ImageReader(photo_bytes),
                photo_x,
                photo_y_bottom,
                width=PHOTO_W_PT,
                height=PHOTO_H_PT,
                preserveAspectRatio=True,
                anchor="nw",
            )

    # ── 6. Debug grid ─────────────────────────────────────────────────────────
    if DEBUG_GRID:
        _draw_debug_grid(c, {
            "nama_cpmi":       _F_NAMA_CPMI,
            "ttl":             _F_TTL,
            "alamat_ktp":      _F_ALAMAT_KTP,
            "kota_ktp":        _F_KOTA_KTP,
            "nohp":            _F_NOHP,
            "email":           _F_EMAIL,
            "saudara":         _F_SAUDARA_VAL,
            "anak_ke":         _F_ANAK_VAL,
            "pengalaman_1":    _F_PENGALAMAN_1,
            "pengalaman_2":    _F_PENGALAMAN_2,
            "ayah_name":       _F_AYAH_NAME,
            "ayah_age":        _F_AYAH_AGE,
            "pkj_ayah":        _F_PKJ_AYAH,
            "ibu_name":        _F_IBU_NAME,
            "ibu_age":         _F_IBU_AGE,
            "pkj_ibu":         _F_PKJ_IBU,
            "alamat_kel":      _F_ALAMAT_KEL,
            "kota_kel":        _F_KOTA_KEL,
            "nohp_kel":        _F_NOHP_KEL,
            "keterangan_1":    _F_KETERANGAN_1,
            "keterangan_2":    _F_KETERANGAN_2,
            "photo_tl":        _frac(_FX_PHOTO, _FY_PHOTO),
        })

    c.save()
    buf.seek(0)
    return buf.read()
