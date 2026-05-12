"""
PDF generation service for:
  TANDA TERIMA PENGEMBALIAN BIAYA TRANSPORTASI CPMI (INBOND COST)

Strategy: use the official blank form as a full-page background image, then
overlay field values at calibrated coordinates.  The template image must be
placed at:

    backend/account/assets/inbond_template.png

All coordinate constants are expressed as FRACTIONS of the A4 page dimensions
(PAGE_W = 595.28 pt, PAGE_H = 841.89 pt) so they are independent of the
template image resolution.

  x = x_fraction * PAGE_W       (0.0 = left edge, 1.0 = right edge)
  y = (1 - y_fraction) * PAGE_H (0.0 = top of page, 1.0 = bottom)

To calibrate, flip DEBUG_GRID = True — red crosshairs will appear at every
field position.  Adjust the fractions until the text lands inside the correct
boxes, then set DEBUG_GRID = False.

This endpoint is admin-only.
"""

import io
import os
import struct
from datetime import date
from decimal import Decimal

from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader

# ─── Debug flag ─────────────────────────────────────────────────────────────
DEBUG_GRID = False

# ─── Page dimensions ────────────────────────────────────────────────────────
PAGE_W, PAGE_H = A4   # 595.28 × 841.89 pt

# ─── Template image path ────────────────────────────────────────────────────
_SERVICES_DIR = os.path.dirname(os.path.abspath(__file__))
_ACCOUNT_DIR  = os.path.dirname(_SERVICES_DIR)
TEMPLATE_PATH = os.path.join(_ACCOUNT_DIR, "assets", "inbond_template.png")

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

# ─── Field positions (fractions of A4 page) ─────────────────────────────────
#
# Measured against the reference scan of the blank Inbond Cost form.
# The label column ends at ~x=0.36; value text starts just after the colon.
# Right edge of the form lines: x ≈ 0.960
#
# IDENTITY SECTION — values sit after ":" on each row
_FX_VALUE  = 0.360   # x start of value text (after label + colon)
_FX_RIGHT  = 0.960   # right edge of lines

_F_NAMA_CPMI  = _frac(0.365, 0.264)   # "Nama CPMI"
_F_NO_ID      = _frac(0.365, 0.281)   # "Nomor Identitas (KTP/Paspor)"
_F_TTL        = _frac(0.365, 0.298)   # "Tempat / Tgl. Lahir"
_F_KOTA_ASAL  = _frac(0.365, 0.316)   # "Daerah asal Kota / Kabupaten"
_F_NO_REK     = _frac(0.365, 0.334)   # "No. Rekening"
_F_BANK       = _frac(0.365, 0.353)   # "Bank"
_F_PERUSAHAAN = _frac(0.365, 0.379)   # "Perusahaan yang dituju"

# TABLE — "Tanggal Proses" column  (x ≈ 0.500, rows start at y ≈ 0.530)
# Each data row is approximately 0.0295 of page height apart.
_FX_TGL = 0.370   # x for date values in the table
_FX_RP = 0.510    # "Jumlah uang dikembalikan" column (approx.)
_FX_KET = 0.77   # Keterangan column (approx.)
_FY_ROW_1 = 0.460   # y_top_frac for row 1 (Medical)
_ROW_STEP = 0.025  # vertical step per row

# Printed form: rows 1–7 = proses utama; 8–9 kosong di template; TOTAL di bawah.
INBOUND_PDF_ROW_SPECS: list[tuple[int, tuple[str, ...]]] = [
    (1, ("MEDICAL",)),
    (2, ("BUAT_ID_PEKERJA",)),
    (3, ("BUAT_PASPOR",)),
    (4, ("FWCMS", "PSIKOLOGI_TEST")),
    (5, ("PAP_BP3MI",)),
    (6, ("PDO_KILANG",)),
    (7, ("PERSIAPAN_KEBERANGKATAN",)),
]


def _tbl_xy(x_frac: float, row: int) -> tuple:
    """(x, y) for a column at PDF table row (1-indexed)."""
    return _frac(x_frac, _FY_ROW_1 + (row - 1) * _ROW_STEP)


def _tbl_tgl(row: int) -> tuple:
    """Return (x, y) for the 'Tanggal Proses' cell of table row (1-indexed)."""
    return _tbl_xy(_FX_TGL, row)

# SIGNATURE SECTION
_F_SIG_TTD   = _frac(0.260, 0.895)   # "Tanda Tangan :" blank
_F_SIG_NAMA  = _frac(0.210, 0.837)   # "Nama CPMI :"
_F_SIG_TGL   = _frac(0.280, 0.857)   # "Tanggal Pengembalian :"


# ─── Helpers ─────────────────────────────────────────────────────────────────

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


def _fmt_rp_id(amount) -> str:
    """Indonesian-style thousands with dot separator."""
    if amount is None:
        return ""
    try:
        d = amount if isinstance(amount, Decimal) else Decimal(str(amount))
        v = int(d.quantize(Decimal("1")))
        return f"Rp{v:,}".replace(",", ".")
    except Exception:
        return ""


def _inbound_rows_by_code(profile) -> dict:
    out = {}
    for row in profile.inbound_transport_stage_costs.all():
        out[row.stage_code] = row
    return out


def _merged_transport_cells(
    by_code: dict,
    stage_codes: tuple[str, ...],
    dates_by_code: dict,
) -> tuple[str, str, str]:
    """Return (tanggal_display, rp_display, keterangan) for one printed table row."""
    total = Decimal("0")
    have_amount = False
    tgls: list[str] = []
    kets: list[str] = []
    for code in stage_codes:
        r = by_code.get(code)
        if r:
            if r.amount is not None:
                total += r.amount
                have_amount = True
            k = (r.keterangan or "").strip()
            if k:
                kets.append(k)
        d = dates_by_code.get(code)
        if d:
            tgls.append(_fmt_date(d))
    tgl_s = " / ".join(tgls) if tgls else ""
    rp_s = _fmt_rp_id(total) if have_amount else ""
    ket_s = " — ".join(kets) if kets else ""
    return tgl_s, rp_s, ket_s


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


# ─── Main generator ──────────────────────────────────────────────────────────

def generate_inbond_pdf(profile) -> bytes:
    """
    Generate the Tanda Terima Pengembalian Biaya Transportasi CPMI PDF
    by overlaying field values onto the blank form template image.
    Returns raw PDF bytes.
    """
    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)

    # ── 1. Background template image ─────────────────────────────────────
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
                     "Template tidak ditemukan: account/assets/inbond_template.png")
        c.setFillColorRGB(0, 0, 0)

    # ── 2. Collect data ───────────────────────────────────────────────────
    user      = profile.user
    full_name = _str(user.full_name)

    nik      = _str(profile.nik)
    passport = _str(profile.passport_number)
    id_number = nik or passport

    birth_place = _str(
        (profile.birth_place_text or "").strip()
        or (profile.birth_place.name if profile.birth_place else "")
    )
    birth_date  = _fmt_date(profile.birth_date)
    ttl = ", ".join(p for p in [birth_place, birth_date] if p)

    kota_asal = _str(profile.district.name if profile.district else "")
    no_rek    = _str(profile.no_rek)
    bank      = _str(profile.bank)

    # Destination company — use the most recent approved/accepted application
    perusahaan = ""
    try:
        app = (
            profile.job_applications
            .filter(status__in=("APPROVED", "ACCEPTED", "PLACED"))
            .select_related("job__company")
            .order_by("-created_at")
            .first()
        )
        if app and app.job and app.job.company:
            perusahaan = _str(app.job.company.name)
    except Exception:
        pass

    tgl_kembali = _fmt_date(getattr(profile, "tanggal_pengembalian", None))

    from account.services.inbound_transport_costs import (
        step_confirmation_dates_by_stage_for_profile,
    )

    dates_by_stage = step_confirmation_dates_by_stage_for_profile(profile)

    by_stage = _inbound_rows_by_code(profile)
    grand_total = sum(
        (r.amount for r in by_stage.values() if r.amount is not None),
        start=Decimal("0"),
    )

    # ── 3. Draw helper ────────────────────────────────────────────────────
    c.setFont(FONT_NAME, FONT_SIZE)
    c.setFillColorRGB(0, 0, 0)
    right = _FX_RIGHT * PAGE_W

    def draw(xy, text, max_w=None):
        if not text:
            return
        x, y = xy
        if max_w:
            while text and c.stringWidth(text, FONT_NAME, FONT_SIZE) > max_w:
                text = text[:-1]
        c.drawString(x, y, text)

    # ── 4. Identity fields ────────────────────────────────────────────────
    draw(_F_NAMA_CPMI,  full_name,  max_w=right - _F_NAMA_CPMI[0])
    draw(_F_NO_ID,      id_number,  max_w=right - _F_NO_ID[0])
    draw(_F_TTL,        ttl,        max_w=right - _F_TTL[0])
    draw(_F_KOTA_ASAL,  kota_asal,  max_w=right - _F_KOTA_ASAL[0])
    draw(_F_NO_REK,     no_rek,     max_w=right - _F_NO_REK[0])
    draw(_F_BANK,       bank,       max_w=right - _F_BANK[0])
    draw(_F_PERUSAHAAN, perusahaan, max_w=right - _F_PERUSAHAAN[0])

    # ── 5. Table — Tanggal Proses, Jumlah (Rp), Keterangan ───────────────
    for pdf_row, stage_codes in INBOUND_PDF_ROW_SPECS:
        tgl_s, rp_s, ket_s = _merged_transport_cells(
            by_stage, stage_codes, dates_by_stage
        )
        y_key = _FY_ROW_1 + (pdf_row - 1) * _ROW_STEP
        max_w_rp = (_FX_RIGHT - _FX_RP) * PAGE_W
        max_w_ket = (_FX_RIGHT - _FX_KET) * PAGE_W
        draw(_frac(_FX_TGL, y_key), tgl_s, max_w=(_FX_RIGHT - _FX_TGL) * PAGE_W)
        draw(_frac(_FX_RP, y_key), rp_s, max_w=max_w_rp)
        draw(_frac(_FX_KET, y_key), ket_s, max_w=max_w_ket)

    # Total row (pre-printed on template below row 9)
    total_rp = _fmt_rp_id(grand_total) if grand_total != 0 else ""
    _FY_TOTAL = _FY_ROW_1 + 8.75 * _ROW_STEP
    draw(_frac(_FX_RP, _FY_TOTAL), total_rp, max_w=(_FX_RIGHT - _FX_RP) * PAGE_W)

    # ── 6. Signature section ──────────────────────────────────────────────
    draw(_F_SIG_NAMA, full_name,  max_w=right * 0.5)
    draw(_F_SIG_TGL,  tgl_kembali)

    # ── 7. Debug grid ─────────────────────────────────────────────────────
    if DEBUG_GRID:
        _draw_debug_grid(c, {
            "nama_cpmi":  _F_NAMA_CPMI,
            "no_id":      _F_NO_ID,
            "ttl":        _F_TTL,
            "kota_asal":  _F_KOTA_ASAL,
            "no_rek":     _F_NO_REK,
            "bank":       _F_BANK,
            "perusahaan": _F_PERUSAHAAN,
            "rp_row4":    _frac(_FX_RP, _FY_ROW_1 + 3 * _ROW_STEP),
            "sig_nama":   _F_SIG_NAMA,
            "sig_tgl":    _F_SIG_TGL,
        })

    c.save()
    buf.seek(0)
    return buf.read()
