"""
Shared layout for Surat Pengantar (Medical / Psikologi) PDF overlays.

The scan is typically **not** the same aspect ratio as A4 (e.g. 2550×3300 vs
595×842 pt). Drawing it stretched to full A4 shifts every row relative to
fraction-of-page coordinates. We **letterbox** the image inside A4 and map
fractions (0–1) to that content box instead.
"""

from __future__ import annotations

from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase.pdfmetrics import stringWidth
from reportlab.pdfgen import canvas

PAGE_W, PAGE_H = A4


def draw_referral_template_letterboxed(
    c: canvas.Canvas,
    tpl_path: str,
) -> tuple[float, float, float, float]:
    """
    Draw the JPEG/PNG template preserving aspect ratio inside the page.

    Returns ``(ox, oy, box_w, box_h)`` — overlay coordinates must use
    :func:`xy_in_box` with the same tuple.
    """
    ir = ImageReader(tpl_path)
    iw, ih = ir.getSize()
    if not iw or not ih:
        return 0.0, 0.0, PAGE_W, PAGE_H

    ar_img = float(iw) / float(ih)
    ar_page = PAGE_W / PAGE_H

    if ar_img >= ar_page:
        box_w = PAGE_W
        box_h = PAGE_W / ar_img
        ox = 0.0
        oy = (PAGE_H - box_h) / 2.0
    else:
        box_h = PAGE_H
        box_w = PAGE_H * ar_img
        ox = (PAGE_W - box_w) / 2.0
        oy = 0.0

    c.drawImage(ir, ox, oy, width=box_w, height=box_h, mask="auto")
    return ox, oy, box_w, box_h


def xy_in_box(
    ox: float,
    oy: float,
    box_w: float,
    box_h: float,
    x_frac: float,
    y_top_frac: float,
) -> tuple[float, float]:
    """
    ``(x_frac, y_top_frac)`` are relative to the **template content box**
    (0=left, 1=right; y_top_frac 0=top of image, 1=bottom).
    """
    x = ox + x_frac * box_w
    y = oy + (1.0 - y_top_frac) * box_h
    return x, y


def _break_oversized_word(
    word: str,
    max_width: float,
    font_name: str,
    font_size: float,
) -> list[str]:
    """Split a single token into segments that each fit ``max_width``."""
    if not word:
        return []
    chunks: list[str] = []
    buf = ""
    for ch in word:
        trial = buf + ch
        if stringWidth(trial, font_name, font_size) <= max_width:
            buf = trial
        else:
            if buf:
                chunks.append(buf)
            buf = ch
            if stringWidth(buf, font_name, font_size) > max_width:
                chunks.append(buf)
                buf = ""
    if buf:
        chunks.append(buf)
    return chunks


def wrap_text_lines(
    text: str,
    max_width: float,
    font_name: str,
    font_size: float,
    *,
    max_lines: int = 3,
) -> list[str]:
    """
    Word-wrap ``text`` into lines that fit ``max_width`` (points).

    Returns at most ``max_lines`` lines; overflow is truncated with ``...``.
    """
    text = (text or "").strip()
    if not text or max_width <= 0:
        return []

    words = text.split()
    raw_lines: list[str] = []
    current: list[str] = []

    def line_width(parts: list[str]) -> float:
        return stringWidth(" ".join(parts), font_name, font_size) if parts else 0.0

    for word in words:
        cand = current + [word]
        if line_width(cand) <= max_width:
            current = cand
            continue
        if current:
            raw_lines.append(" ".join(current))
            current = []
        if line_width([word]) <= max_width:
            current = [word]
            continue
        raw_lines.extend(_break_oversized_word(word, max_width, font_name, font_size))

    if current:
        raw_lines.append(" ".join(current))

    if not raw_lines:
        return []

    if len(raw_lines) <= max_lines:
        return raw_lines

    head = raw_lines[: max_lines - 1]
    remainder = " ".join(raw_lines[max_lines - 1 :])
    if stringWidth(remainder, font_name, font_size) <= max_width:
        return head + [remainder]

    ell = remainder
    suffix = "..."
    while ell and stringWidth(ell + suffix, font_name, font_size) > max_width:
        ell = ell[:-1]
    if not ell:
        ell = remainder[:1] if remainder else ""
    last = ell + suffix if remainder != ell else ell
    return head + [last]


def draw_wrapped_lines(
    c: canvas.Canvas,
    x: float,
    y_first_baseline: float,
    text: str,
    max_width: float,
    font_name: str,
    font_size: float,
    *,
    max_lines: int = 3,
    line_height: float | None = None,
) -> None:
    """
    Draw ``text`` in up to ``max_lines`` lines, first line baseline at
    ``y_first_baseline``, each following line lower on the page.
    """
    lines = wrap_text_lines(
        text, max_width, font_name, font_size, max_lines=max_lines
    )
    if not lines:
        return
    lh = line_height if line_height is not None else font_size * 1.02
    c.setFont(font_name, font_size)
    y = y_first_baseline
    for line in lines:
        c.drawString(x, y, line)
        y -= lh


# ─── Calibrated for pengantar_psikologi_template.jpg (2550×3300) letterboxed ─
# Left column value start (after labels); right column; Umur sits right of TTL.

LX = 0.28
RX = 0.75
RX_UMUR = 0.78

# Row bands (y_top_frac), top → bottom — tuned so text sits on dotted lines.
R1 = 0.305
R2 = 0.325
R3 = 0.345
R4 = 0.365
R5 = 0.385
R6 = 0.405
R7 = 0.425
R_MEDAN = 0.46

