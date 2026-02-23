"""
OCR helpers for KMS-Connect.
- Google Cloud Vision: full text extraction (account.tasks.process_document_ocr).
- KTP text parsing: extract NIK, nama, tempat lahir, tanggal lahir from OCR text.
"""
import re
import os
from django.conf import settings
from .models import KTP_OCR_KEYS


def extract_text_from_image(image_path: str) -> str:
    """
    Extract text from image using Google Cloud Vision API.

    Args:
        image_path: Path to the image file

    Returns:
        Extracted text from the image

    Raises:
        ImportError: If Google Cloud Vision library is not installed
        RuntimeError: If OCR processing fails
    """
    try:
        from google.cloud import vision
        from google.api_core.exceptions import GoogleAPIError
    except ImportError:
        raise ImportError(
            "Google Cloud Vision library tidak tersedia. "
            "Install dengan: pip install google-cloud-vision"
        )

    if not settings.GOOGLE_APPLICATION_CREDENTIALS and not os.environ.get(
        "GOOGLE_APPLICATION_CREDENTIALS"
    ):
        raise RuntimeError(
            "Google Cloud Vision credentials tidak dikonfigurasi. "
            "Set GOOGLE_APPLICATION_CREDENTIALS di .env atau environment."
        )

    with open(image_path, "rb") as image_file:
        content = image_file.read()

    client = vision.ImageAnnotatorClient()
    image = vision.Image(content=content)

    try:
        response = client.document_text_detection(image=image)

        if response.error.message:
            raise RuntimeError(f"Vision API error: {response.error.message}")

        text = (
            response.full_text_annotation.text
            if response.full_text_annotation
            else ""
        )
        return text.strip()

    except GoogleAPIError as e:
        raise RuntimeError(f"Google Cloud Vision API error: {str(e)}")


# ---------------------------------------------------------------------------
# KTP text parsing – focused on NIK, name, birth_place, birth_date
# ---------------------------------------------------------------------------

# Common label prefixes found on Indonesian KTP
_LABEL_NAMA = re.compile(r"^nama\s*[:.]?\s*", re.I)
_LABEL_TTL = re.compile(
    r"(?:tempat\s*[/.,]?\s*t(?:ang)?g(?:al|l)?\.?\s*lahir|t\.?t\.?l\.?)\s*[:.]?\s*",
    re.I,
)
_LABEL_TEMPAT = re.compile(r"^tempat\s*[:.]?\s*", re.I)
_DATE_PATTERN = re.compile(r"(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})")
_NIK_PATTERN = re.compile(r"\b(\d{16})\b")
# Words that indicate a KTP field label, not a person's name
_KTP_LABEL_WORDS = re.compile(
    r"^(?:tempat|tanggal|tgl|ttl|t\.t\.l|berlaku|hingga|s[/.]d|agama|"
    r"jenis|kelamin|status|perkawinan|pekerjaan|alamat|rt[/]?rw|kecamatan|"
    r"kelurahan|desa|golongan|darah|kewarganegaraan|provinsi|kabupaten|kota|"
    r"nik|nama|negara|republika)\b",
    re.I,
)


def _normalise_date(raw: str) -> str | None:
    """Try to normalise a date string to DD-MM-YYYY."""
    m = _DATE_PATTERN.search(raw)
    if not m:
        return None
    day, month, year = m.group(1), m.group(2), m.group(3)
    if len(year) == 2:
        year = f"19{year}" if int(year) > 30 else f"20{year}"
    return f"{int(day):02d}-{int(month):02d}-{year}"


def _clean_label(text: str, pattern: re.Pattern) -> str:
    """Remove a label prefix from *text* and return the stripped remainder."""
    return pattern.sub("", text).strip()


def parse_ktp_text(text: str) -> dict:
    """
    Parse Indonesian KTP OCR text into a dict keyed by *KTP_OCR_KEYS*.

    Optimised for four fields:
      * **nik** – 16-digit NIK
      * **name** – full name
      * **birth_place** – city / regency of birth
      * **birth_date** – date of birth (DD-MM-YYYY)
    """
    result: dict[str, str | None] = {k: None for k in KTP_OCR_KEYS}

    if not text or not text.strip():
        return result

    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    full_text = " ".join(lines)

    # ── NIK (16 consecutive digits) ──────────────────────────────────────
    nik_match = _NIK_PATTERN.search(full_text)
    if nik_match:
        result["nik"] = nik_match.group(1)

    # ── Nama ─────────────────────────────────────────────────────────────
    def _is_valid_name_candidate(text: str) -> bool:
        """Return True if *text* looks like a person's name, not a KTP label."""
        if not text or len(text) < 2:
            return False
        if text.isdigit():
            return False
        if re.match(r"^\d", text):  # starts with a digit (e.g. date or NIK fragment)
            return False
        if _KTP_LABEL_WORDS.match(text):
            return False
        return True

    for idx, line in enumerate(lines):
        if _LABEL_NAMA.match(line):
            value = _clean_label(line, _LABEL_NAMA)
            if _is_valid_name_candidate(value):
                result["name"] = value
            elif idx + 1 < len(lines):
                candidate = lines[idx + 1].strip()
                if _is_valid_name_candidate(candidate):
                    result["name"] = candidate
            break

    # Fallback: first non-numeric, non-label line in the top 7 lines
    if not result["name"]:
        for line in lines[:7]:
            stripped = line.strip()
            if len(stripped) > 3 and _is_valid_name_candidate(stripped):
                result["name"] = stripped
                break

    # ── Tempat / Tanggal Lahir ───────────────────────────────────────────
    for idx, line in enumerate(lines):
        # "Tempat/Tgl Lahir : KOTA , DD-MM-YYYY"
        if _LABEL_TTL.search(line):
            remainder = _LABEL_TTL.sub("", line).strip()
            # Split on comma or double-space to separate place and date
            parts = re.split(r"[,]|\s{2,}", remainder, maxsplit=1)
            if parts:
                place = re.sub(r"[\d\-/.\\ ]+$", "", parts[0]).strip()
                if place and not place.isdigit():
                    result["birth_place"] = place
            # Date may be in the remainder or the next line
            date_src = remainder
            if not _DATE_PATTERN.search(date_src) and idx + 1 < len(lines):
                date_src = lines[idx + 1]
            result["birth_date"] = _normalise_date(date_src)
            break

        # Standalone "Tempat : Xyz" line
        if _LABEL_TEMPAT.match(line):
            result["birth_place"] = _clean_label(line, _LABEL_TEMPAT)

    # Date fallback: first line containing a date-like pattern
    if not result["birth_date"]:
        for line in lines:
            normalised = _normalise_date(line)
            if normalised:
                result["birth_date"] = normalised
                break

    return result
