"""
Spesifikasi dokumen TKI: format (PDF/JPG), ukuran maks, dan validasi.

PDF ≤ 2MB:
  1. Ijasah
  2. Sertifikat keterampilan (jika ada)
  3. Ijin Keluarga
  4. Surat Keterangan Pemberi Ijin
  5. Surat Kesehatan
  6. Surat Keterangan Status Perkawinan
  7. Perjanjian Penempatan

JPG ≤ 500KB:
  1. Photo TKI
  2. KTP
  3. Kartu Keluarga
  4. Kartu BPJS
  5. Paspor
"""
from django.core.exceptions import ValidationError
from django.utils.translation import gettext_lazy as _


# Bytes
MAX_PDF_BYTES = 2 * 1024 * 1024   # 2 MB
MAX_IMAGE_BYTES = 500 * 1024      # 500 KB

# Allowed extensions (lowercase)
PDF_EXTENSIONS = (".pdf",)
IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png")  # PNG often from phones; we normalize to JPG on optimize

# Document type code -> spec
DOCUMENT_SPECS = {
    # PDF, max 2MB
    "ijasah": {"format": "pdf", "extensions": PDF_EXTENSIONS, "max_bytes": MAX_PDF_BYTES},
    "sertifikat-keterampilan": {"format": "pdf", "extensions": PDF_EXTENSIONS, "max_bytes": MAX_PDF_BYTES},
    "ijin-keluarga": {"format": "pdf", "extensions": PDF_EXTENSIONS, "max_bytes": MAX_PDF_BYTES},
    "surat-keterangan-pemberi-ijin": {"format": "pdf", "extensions": PDF_EXTENSIONS, "max_bytes": MAX_PDF_BYTES},
    "surat-kesehatan": {"format": "pdf", "extensions": PDF_EXTENSIONS, "max_bytes": MAX_PDF_BYTES},
    "surat-keterangan-status-perkawinan": {"format": "pdf", "extensions": PDF_EXTENSIONS, "max_bytes": MAX_PDF_BYTES},
    "perjanjian-penempatan": {"format": "pdf", "extensions": PDF_EXTENSIONS, "max_bytes": MAX_PDF_BYTES},
    # Image (JPG), max 500KB
    "photo-tki": {"format": "image", "extensions": IMAGE_EXTENSIONS, "max_bytes": MAX_IMAGE_BYTES},
    "ktp": {"format": "image", "extensions": IMAGE_EXTENSIONS, "max_bytes": MAX_IMAGE_BYTES},
    "kartu-keluarga": {"format": "image", "extensions": IMAGE_EXTENSIONS, "max_bytes": MAX_IMAGE_BYTES},
    "kartu-bpjs": {"format": "image", "extensions": IMAGE_EXTENSIONS, "max_bytes": MAX_IMAGE_BYTES},
    "paspor": {"format": "image", "extensions": IMAGE_EXTENSIONS, "max_bytes": MAX_IMAGE_BYTES},
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

    if file.size > spec["max_bytes"]:
        max_mb = spec["max_bytes"] / (1024 * 1024)
        max_kb = spec["max_bytes"] / 1024
        if spec["format"] == "pdf":
            msg = _("Ukuran berkas melebihi %(max)s MB. Harap kompres PDF lalu unggah lagi.") % {"max": max_mb}
        else:
            msg = _("Ukuran berkas melebihi %(max)s KB. Gambar akan dikompres otomatis atau unggah ulang dengan ukuran lebih kecil.") % {"max": int(max_kb)}
        raise ValidationError(msg, code="file_too_large")


def get_max_size_for_code(doc_type_code: str) -> int | None:
    """Return max size in bytes for document type, or None."""
    spec = get_spec_for_code(doc_type_code)
    return spec["max_bytes"] if spec else None


def is_image_type(doc_type_code: str) -> bool:
    """True if this document type expects an image (JPG)."""
    spec = get_spec_for_code(doc_type_code)
    return spec is not None and spec.get("format") == "image"
