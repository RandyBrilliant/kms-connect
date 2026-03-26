"""
OCR helpers for KMS-Connect.
- Google Cloud Vision: full text extraction with bounding box support.
- KTP text parsing: extract NIK, nama, tempat lahir, tanggal lahir from OCR text.

Optimized using spatial/coordinate-based extraction inspired by:
https://medium.com/@imrenagi/ekstraksi-informasi-e-ktp-dengan-google-cloud-function-dan-cloud-vision-api
"""
import re
import os
from typing import NamedTuple
from django.conf import settings
from .models import KTP_OCR_KEYS


class TextBlock(NamedTuple):
    """Represents a text block with its bounding box coordinates."""

    text: str
    x_min: float
    y_min: float
    x_max: float
    y_max: float

    @property
    def center_y(self) -> float:
        return (self.y_min + self.y_max) / 2

    @property
    def center_x(self) -> float:
        return (self.x_min + self.x_max) / 2

    @property
    def height(self) -> float:
        return self.y_max - self.y_min

    @property
    def width(self) -> float:
        return self.x_max - self.x_min


def _get_bounding_box(vertices) -> tuple[float, float, float, float]:
    """Extract bounding box coordinates from vertices."""
    xs = [v.x for v in vertices]
    ys = [v.y for v in vertices]
    return min(xs), min(ys), max(xs), max(ys)


def _extract_text_blocks(response) -> list[TextBlock]:
    """
    Extract text blocks with bounding boxes from Vision API response.

    Groups words into logical blocks based on spatial proximity.
    """
    blocks = []

    if not response.full_text_annotation:
        return blocks

    for page in response.full_text_annotation.pages:
        for block in page.blocks:
            for paragraph in block.paragraphs:
                words_in_para = []
                para_vertices = []

                for word in paragraph.words:
                    word_text = "".join([s.text for s in word.symbols])
                    words_in_para.append(word_text)

                    if word.bounding_box and word.bounding_box.vertices:
                        para_vertices.extend(word.bounding_box.vertices)

                if words_in_para and para_vertices:
                    text = " ".join(words_in_para)
                    x_min, y_min, x_max, y_max = _get_bounding_box(para_vertices)
                    blocks.append(TextBlock(text, x_min, y_min, x_max, y_max))

    # Sort blocks by vertical position (top to bottom), then horizontal (left to right)
    blocks.sort(key=lambda b: (b.y_min, b.x_min))
    return blocks


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
    result = extract_text_with_blocks(image_path)
    return result["text"]


def extract_text_with_blocks(image_path: str) -> dict:
    """
    Extract text from image with bounding box information.

    Args:
        image_path: Path to the image file

    Returns:
        Dict with 'text' (full text) and 'blocks' (list of TextBlock with coordinates)

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

        blocks = _extract_text_blocks(response)

        return {"text": text.strip(), "blocks": blocks, "response": response}

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

# Words/phrases that indicate a KTP field label, not a person's name
# Uses word boundary at start but allows partial matches at end
_KTP_LABEL_WORDS = re.compile(
    r"^(?:tempat|tanggal|tgl|ttl|t\.t\.l|berlaku|hingga|s[/.]d|agama|"
    r"jenis|kelamin|status|perkawinan|pekerjaan|alamat|rt[/]?rw|kecamatan|"
    r"kelurahan|desa|golongan|darah|kewarganegaraan|provinsi|kabupaten|kota|"
    r"nik|nama|negara|republika|lahir|gol|warga)",
    re.I,
)

# Additional patterns that look like KTP labels or fragments
_KTP_LABEL_FRAGMENTS = re.compile(
    r"(?:tempat\s*[/.,]?\s*tan|tgl\s*lahir|tanggal\s*lahir|"
    r"jenis\s*kelamin|status\s*perk|gol\s*darah|"
    r"rt\s*/\s*rw|berlaku\s*hingga|kewarga\s*negaraan)",
    re.I,
)

# KTP layout constants (approximate normalized positions on standard KTP)
# These define relative Y positions (0-1 scale) for each field on KTP
_KTP_LAYOUT = {
    "nik": {"y_range": (0.15, 0.35), "label": "NIK"},
    "name": {"y_range": (0.25, 0.45), "label": "Nama"},
    "birth": {"y_range": (0.35, 0.55), "label": "Tempat/Tgl Lahir"},
}


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


def _is_valid_name_candidate(text: str) -> bool:
    """Return True if *text* looks like a person's name, not a KTP label."""
    if not text or len(text) < 2:
        return False
    if text.isdigit():
        return False
    if re.match(r"^\d", text):  # starts with a digit (e.g. date or NIK fragment)
        return False
    # Check if text starts with a known KTP label word
    if _KTP_LABEL_WORDS.match(text):
        return False
    # Check for label fragments like "TEMPAT TAN", "TGL LAHIR", etc.
    if _KTP_LABEL_FRAGMENTS.search(text):
        return False
    # Check for common label patterns (colon usually indicates a label)
    if re.match(r"^[A-Z\s]{2,}\s*:", text, re.I):
        return False
    # Indonesian names typically don't contain these patterns
    if re.search(r"\b(RT|RW|NIK|KTP|SIM|NPWP)\b", text, re.I):
        return False
    return True


def _find_blocks_near_label(
    blocks: list[TextBlock], label_pattern: re.Pattern, y_tolerance: float = 30
) -> list[TextBlock]:
    """
    Find text blocks that appear to the right of or below a label.

    Uses spatial positioning to find value blocks associated with a label.
    """
    label_block = None
    for block in blocks:
        if label_pattern.search(block.text):
            label_block = block
            break

    if not label_block:
        return []

    nearby_blocks = []
    for block in blocks:
        if block == label_block:
            continue
        # Block is to the right of label (same row)
        same_row = abs(block.center_y - label_block.center_y) < y_tolerance
        to_right = block.x_min > label_block.x_max - 20
        # Block is directly below the label
        below = (
            block.y_min > label_block.y_min
            and block.y_min < label_block.y_max + y_tolerance * 2
        )
        if same_row and to_right:
            nearby_blocks.append(block)
        elif below and abs(block.center_x - label_block.center_x) < 200:
            nearby_blocks.append(block)

    return nearby_blocks


def _normalize_y_positions(blocks: list[TextBlock]) -> list[TextBlock]:
    """Normalize Y coordinates to 0-1 scale based on image bounds."""
    if not blocks:
        return blocks

    y_min = min(b.y_min for b in blocks)
    y_max = max(b.y_max for b in blocks)
    height = y_max - y_min if y_max > y_min else 1

    normalized = []
    for b in blocks:
        norm_y_min = (b.y_min - y_min) / height
        norm_y_max = (b.y_max - y_min) / height
        normalized.append(
            TextBlock(b.text, b.x_min, norm_y_min, b.x_max, norm_y_max)
        )
    return normalized


def parse_ktp_with_blocks(blocks: list[TextBlock]) -> dict:
    """
    Parse KTP data using spatial/coordinate-based extraction.

    This method uses bounding box positions to find field values,
    which is more reliable than pure regex on OCR text.
    """
    result: dict[str, str | None] = {k: None for k in KTP_OCR_KEYS}

    if not blocks:
        return result

    # Normalize Y positions for layout-based extraction
    norm_blocks = _normalize_y_positions(blocks)
    full_text = " ".join(b.text for b in blocks)

    # ── NIK extraction using spatial position ──
    # NIK is usually in the upper portion of KTP, look for 16-digit number
    nik_range = _KTP_LAYOUT["nik"]["y_range"]
    for block in norm_blocks:
        if nik_range[0] <= block.center_y <= nik_range[1]:
            nik_match = _NIK_PATTERN.search(block.text)
            if nik_match:
                result["nik"] = nik_match.group(1)
                break

    # Fallback: search entire text
    if not result["nik"]:
        nik_match = _NIK_PATTERN.search(full_text)
        if nik_match:
            result["nik"] = nik_match.group(1)

    # ── Name extraction using spatial position ──
    name_label_pattern = re.compile(r"\bnama\b", re.I)
    name_range = _KTP_LAYOUT["name"]["y_range"]

    # Find the "Nama" label block first
    nama_label_block = None
    for block in blocks:
        if name_label_pattern.search(block.text):
            # Make sure this is the label, not part of other text
            text_upper = block.text.upper().strip()
            if text_upper.startswith("NAMA") or text_upper == "NAMA":
                nama_label_block = block
                break

    if nama_label_block:
        # Look for text blocks to the RIGHT of the Nama label (same row)
        # or the first valid block BELOW it
        candidates = []
        for block in blocks:
            if block == nama_label_block:
                continue
            # Same row, to the right
            same_row = abs(block.center_y - nama_label_block.center_y) < 25
            to_right = block.x_min > nama_label_block.x_max - 10
            # Just below
            below = (
                block.y_min > nama_label_block.y_min
                and block.y_min < nama_label_block.y_max + 40
            )
            if same_row and to_right:
                candidates.append((0, block))  # Priority 0: same row
            elif below:
                candidates.append((1, block))  # Priority 1: below

        # Sort by priority, then by position
        candidates.sort(key=lambda x: (x[0], x[1].y_min, x[1].x_min))

        for _, block in candidates:
            cleaned = _clean_label(block.text, _LABEL_NAMA)
            if _is_valid_name_candidate(cleaned):
                result["name"] = cleaned
                break

    # Fallback: look for name in expected Y range
    if not result["name"]:
        for block in norm_blocks:
            if name_range[0] <= block.center_y <= name_range[1]:
                # Skip if this looks like a label
                text_upper = block.text.upper().strip()
                if text_upper.startswith(("NAMA", "NIK", "TEMPAT", "TANGGAL", "TGL")):
                    # Try to extract value after the label
                    cleaned = _clean_label(block.text, _LABEL_NAMA)
                    if cleaned and _is_valid_name_candidate(cleaned):
                        result["name"] = cleaned
                        break
                    continue
                if _is_valid_name_candidate(block.text):
                    result["name"] = block.text
                    break

    # ── Birth place and date extraction ──
    birth_label_pattern = re.compile(
        r"(?:tempat\s*[/.,]?\s*t(?:ang)?g(?:al|l)?\.?\s*lahir|t\.?t\.?l\.?)", re.I
    )
    birth_range = _KTP_LAYOUT["birth"]["y_range"]

    # Try to find blocks near the TTL label
    birth_blocks = _find_blocks_near_label(blocks, birth_label_pattern)

    for block in birth_blocks:
        text = block.text
        # Remove the label if present
        text = _LABEL_TTL.sub("", text).strip()

        if not text:
            continue

        # Try to split place and date
        # Common patterns: "KOTA, DD-MM-YYYY" or "KOTA DD-MM-YYYY"
        parts = re.split(r"[,]|\s{2,}", text, maxsplit=1)

        if parts:
            # Extract birth place (remove trailing date fragments)
            place = re.sub(r"[\d\-/.\\ ]+$", "", parts[0]).strip()
            if place and not place.isdigit() and not result["birth_place"]:
                result["birth_place"] = place

        # Extract date
        date = _normalise_date(text)
        if date and not result["birth_date"]:
            result["birth_date"] = date

    # Fallback: look in expected Y range
    if not result["birth_place"] or not result["birth_date"]:
        for block in norm_blocks:
            if birth_range[0] <= block.center_y <= birth_range[1]:
                text = _LABEL_TTL.sub("", block.text).strip()

                if not result["birth_place"]:
                    parts = re.split(r"[,]|\s{2,}", text, maxsplit=1)
                    if parts:
                        place = re.sub(r"[\d\-/.\\ ]+$", "", parts[0]).strip()
                        if place and not place.isdigit():
                            result["birth_place"] = place

                if not result["birth_date"]:
                    date = _normalise_date(text)
                    if date:
                        result["birth_date"] = date

    return result


def parse_ktp_text(text: str, blocks: list[TextBlock] | None = None) -> dict:
    """
    Parse Indonesian KTP OCR text into a dict keyed by *KTP_OCR_KEYS*.

    Optimised for four fields:
      * **nik** – 16-digit NIK
      * **name** – full name
      * **birth_place** – city / regency of birth
      * **birth_date** – date of birth (DD-MM-YYYY)

    If blocks (with bounding boxes) are provided, uses spatial extraction
    for better accuracy. Otherwise falls back to text-only parsing.
    """
    # If we have blocks with coordinates, use spatial extraction
    if blocks:
        result = parse_ktp_with_blocks(blocks)
        # If spatial extraction got all fields, return it
        if all(result.get(k) for k in KTP_OCR_KEYS):
            return result
        # Otherwise, try to fill missing fields with text-based extraction
        text_result = _parse_ktp_text_only(text)
        for key in KTP_OCR_KEYS:
            if not result.get(key) and text_result.get(key):
                result[key] = text_result[key]
        return result

    return _parse_ktp_text_only(text)


def _parse_ktp_text_only(text: str) -> dict:
    """
    Parse KTP using text-only extraction (original method).

    This is the fallback when bounding box data is not available.
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


# ---------------------------------------------------------------------------
# Birth place matching to Regency database
# ---------------------------------------------------------------------------


def _normalize_place_name(name: str) -> str:
    """Normalize a place name for matching."""
    return (
        name.upper()
        .strip()
        .replace(".", "")
        .replace(",", "")
        .replace("  ", " ")
    )


def _strip_regency_prefix(name: str) -> str:
    """Strip KABUPATEN/KOTA prefix from a place name."""
    import re
    name = _normalize_place_name(name)
    name = re.sub(r"^KAB\.?\s*", "", name)
    name = re.sub(r"^KABUPATEN\s+", "", name)
    name = re.sub(r"^KT\.?\s*", "", name)
    name = re.sub(r"^KOTA\s+", "", name)
    return name.strip()


def match_birth_place_to_regency(birth_place: str | None) -> dict | None:
    """
    Match OCR birth_place string to a Regency in the database.

    Returns dict with regency info if found:
      {"id": <int>, "code": <str>, "name": <str>, "province": <str>}
    Returns None if no match found.

    Uses multi-stage matching:
    1. Exact match after normalization
    2. Prefix-stripped match (removes KAB/KABUPATEN/KOTA)
    3. Contains match
    """
    if not birth_place or not birth_place.strip():
        return None

    try:
        from regions.models import Regency
    except ImportError:
        return None

    query = _normalize_place_name(birth_place)
    if not query:
        return None

    # Stage 1: Exact match
    for regency in Regency.objects.select_related("province").all():
        if _normalize_place_name(regency.name) == query:
            return {
                "id": regency.id,
                "code": regency.code,
                "name": regency.name,
                "province": regency.province.name,
            }

    # Stage 2: Prefix-stripped exact match
    query_stripped = _strip_regency_prefix(query)
    if query_stripped:
        for regency in Regency.objects.select_related("province").all():
            if _strip_regency_prefix(regency.name) == query_stripped:
                return {
                    "id": regency.id,
                    "code": regency.code,
                    "name": regency.name,
                    "province": regency.province.name,
                }

    # Stage 3: Contains match (query in regency name or vice versa)
    for regency in Regency.objects.select_related("province").all():
        regency_norm = _normalize_place_name(regency.name)
        if query in regency_norm or regency_norm in query:
            return {
                "id": regency.id,
                "code": regency.code,
                "name": regency.name,
                "province": regency.province.name,
            }

    # Stage 4: Stripped contains match
    if len(query_stripped) >= 3:
        for regency in Regency.objects.select_related("province").all():
            regency_stripped = _strip_regency_prefix(regency.name)
            if query_stripped in regency_stripped or regency_stripped in query_stripped:
                return {
                    "id": regency.id,
                    "code": regency.code,
                    "name": regency.name,
                    "province": regency.province.name,
                }

    return None


def parse_ktp_text_with_regency_match(
    text: str, blocks: list[TextBlock] | None = None
) -> dict:
    """
    Parse KTP text and also attempt to match birth_place to a Regency.

    Returns standard KTP_OCR_KEYS plus optional 'birth_place_regency' with matched regency info.
    """
    result = parse_ktp_text(text, blocks)

    # Try to match birth_place to a regency
    if result.get("birth_place"):
        regency_match = match_birth_place_to_regency(result["birth_place"])
        if regency_match:
            result["birth_place_regency"] = regency_match

    return result
