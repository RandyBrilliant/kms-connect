"""
Spesifikasi dokumen TKI: format (PDF/JPG), ukuran maks, dan validasi.

Fase INITIAL (diunggah saat pendaftaran):
  1. KTP
  2. Ijazah
  3. Kartu Keluarga
  4. Kartu BPJS Kesehatan
  5. Paspor
  6. Photo TKI
  7. Daftar Riwayat Hidup / CV (opsional, PDF)
  8. Sertifikat Keterampilan (opsional)

Fase POST_INTERVIEW (diunggah setelah lulus interview):
  1. Surat Izin Keluarga (Form Biru)
  2. Surat Keterangan Pemberi Izin
  3. KTP Orangtua / Wali
  4. Surat Kesehatan
  5. Surat Keterangan Status Perkawinan
  6. Buku Nikah (opsional – bagi yang sudah menikah)
  7. Perjanjian Penempatan
"""
from django.core.exceptions import ValidationError
from django.utils.translation import gettext_lazy as _


# Bytes
MAX_PDF_BYTES = 2 * 1024 * 1024        # 2 MB
MAX_IMAGE_BYTES = 500 * 1024           # 500 KB (target after compression)
MAX_IMAGE_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB (allowed upload, will be compressed)

# Allowed extensions (lowercase)
PDF_EXTENSIONS = (".pdf",)
IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png")  # PNG often from phones; we normalize to JPG on optimize

# Document type code -> spec
DOCUMENT_SPECS = {
    # ── INITIAL ──────────────────────────────────────────────────────────────
    "ktp":                    {"format": "image", "extensions": IMAGE_EXTENSIONS, "max_bytes": MAX_IMAGE_BYTES},
    "ijasah":                 {"format": "image", "extensions": IMAGE_EXTENSIONS, "max_bytes": MAX_IMAGE_BYTES},
    "kartu-keluarga":         {"format": "image", "extensions": IMAGE_EXTENSIONS, "max_bytes": MAX_IMAGE_BYTES},
    "kartu-bpjs":             {"format": "image", "extensions": IMAGE_EXTENSIONS, "max_bytes": MAX_IMAGE_BYTES},
    "paspor":                 {"format": "image", "extensions": IMAGE_EXTENSIONS, "max_bytes": MAX_IMAGE_BYTES},
    "pas-foto":              {"format": "image", "extensions": IMAGE_EXTENSIONS, "max_bytes": MAX_IMAGE_BYTES},
    "cv":                    {"format": "pdf",   "extensions": PDF_EXTENSIONS,   "max_bytes": MAX_PDF_BYTES},
    "sertifikat-keterampilan":{"format": "pdf",   "extensions": PDF_EXTENSIONS,   "max_bytes": MAX_PDF_BYTES},
    # ── POST_INTERVIEW ───────────────────────────────────────────────────────
    "ijin-keluarga":                  {"format": "pdf", "extensions": PDF_EXTENSIONS, "max_bytes": MAX_PDF_BYTES},
    "surat-keterangan-pemberi-ijin":  {"format": "pdf", "extensions": PDF_EXTENSIONS, "max_bytes": MAX_PDF_BYTES},
    "ktp-orangtua-wali":              {"format": "image", "extensions": IMAGE_EXTENSIONS, "max_bytes": MAX_IMAGE_BYTES},
    "surat-kesehatan":                {"format": "pdf", "extensions": PDF_EXTENSIONS, "max_bytes": MAX_PDF_BYTES},
    "surat-keterangan-status-perkawinan": {"format": "pdf", "extensions": PDF_EXTENSIONS, "max_bytes": MAX_PDF_BYTES},
    "buku-nikah":                     {"format": "image", "extensions": IMAGE_EXTENSIONS, "max_bytes": MAX_IMAGE_BYTES},
    "perjanjian-penempatan":          {"format": "pdf", "extensions": PDF_EXTENSIONS, "max_bytes": MAX_PDF_BYTES},
}


def get_spec_for_code(code: str) -> dict | None:
    """Return spec for document type code, or None if unknown."""
    if not code:
        return None
    return DOCUMENT_SPECS.get((code or "").strip().lower())


def validate_document_file(file, doc_type_code: str) -> None:
    """
    Validate file extension and size for the given document type.
    Raises ValidationError if invalid.
    
    For images: allows up to MAX_IMAGE_UPLOAD_BYTES (10MB) - compression handled separately.
    For PDFs: strict MAX_PDF_BYTES limit.
    
    Panggil dari ApplicantDocument.clean() (admin/form) atau dari API serializer sebelum save.
    """
    spec = get_spec_for_code(doc_type_code)
    if not spec:
        # Unknown type: allow but you can restrict in API
        return

    ext = "." + (file.name.rsplit(".", 1)[-1].lower() if "." in file.name else "")
    if ext not in spec["extensions"]:
        allowed = ", ".join(spec["extensions"])
        raise ValidationError(
            _("Format berkas tidak sesuai. Untuk %(name)s gunakan: %(allowed)s.") % {"name": doc_type_code, "allowed": allowed},
            code="invalid_format",
        )

    # For images: allow larger uploads (will be compressed automatically)
    # For PDFs: strict size limit
    if spec["format"] == "image":
        if file.size > MAX_IMAGE_UPLOAD_BYTES:
            max_mb = MAX_IMAGE_UPLOAD_BYTES / (1024 * 1024)
            raise ValidationError(
                _("Ukuran gambar terlalu besar (maks %(max)s MB). Harap gunakan gambar yang lebih kecil.") % {"max": int(max_mb)},
                code="file_too_large",
            )
    else:
        # PDF
        if file.size > spec["max_bytes"]:
            max_mb = spec["max_bytes"] / (1024 * 1024)
            raise ValidationError(
                _("Ukuran berkas melebihi %(max)s MB. Harap kompres PDF lalu unggah lagi.") % {"max": max_mb},
                code="file_too_large",
            )


def get_max_size_for_code(doc_type_code: str) -> int | None:
    """Return max size in bytes for document type, or None."""
    spec = get_spec_for_code(doc_type_code)
    return spec["max_bytes"] if spec else None


def is_image_type(doc_type_code: str) -> bool:
    """True if this document type expects an image (JPG)."""
    spec = get_spec_for_code(doc_type_code)
    return spec is not None and spec.get("format") == "image"


def compress_image_file(file, target_bytes: int = MAX_IMAGE_BYTES):
    """
    Compress an image file to target size (default 500KB).
    Returns a new ContentFile with the compressed image, or the original file if already small enough.
    
    This is a synchronous function for use during upload, before saving to storage.
    
    Args:
        file: Django UploadedFile or similar file object
        target_bytes: Target file size in bytes (default: MAX_IMAGE_BYTES = 500KB)
    
    Returns:
        ContentFile with compressed JPEG, or original file if no compression needed
    """
    from io import BytesIO
    from django.core.files.base import ContentFile
    
    # Check if compression is needed
    file.seek(0)
    original_size = file.size if hasattr(file, 'size') else len(file.read())
    file.seek(0)
    
    if original_size <= target_bytes:
        return file  # No compression needed
    
    try:
        from PIL import Image
    except ImportError:
        return file  # Pillow not available, return original
    
    try:
        im = Image.open(file)
        im = im.convert("RGB")  # Ensure RGB for JPEG
    except Exception:
        file.seek(0)
        return file  # Can't process, return original
    
    # Resize if dimensions are very large (memory & size optimization)
    max_side = 2048
    w, h = im.size
    if w > max_side or h > max_side:
        im.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)
    
    # Progressive JPEG compression with decreasing quality
    buf = BytesIO()
    for quality in (85, 75, 65, 55, 45):
        buf = BytesIO()
        im.save(buf, "JPEG", quality=quality, optimize=True)
        if buf.tell() <= target_bytes:
            break
    else:
        # Still too large: progressively reduce dimensions
        current_max = max_side
        while buf.tell() > target_bytes and current_max > 320:
            current_max = int(current_max * 0.75)
            im_resized = im.copy()
            im_resized.thumbnail((current_max, current_max), Image.Resampling.LANCZOS)
            buf = BytesIO()
            im_resized.save(buf, "JPEG", quality=55, optimize=True)
    
    buf.seek(0)
    
    # Generate new filename with .jpg extension
    original_name = getattr(file, 'name', 'image.jpg')
    if not original_name.lower().endswith((".jpg", ".jpeg")):
        name = (original_name.rsplit(".", 1)[0] if "." in original_name else original_name) + ".jpg"
    else:
        name = original_name
    
    compressed_file = ContentFile(buf.read(), name=name)
    return compressed_file
