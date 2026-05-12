"""
Sub-tahapan yang punya biaya transport inbound (admin + PDF Inbond).

Subset dari alur Diterima di ``main.models.JobApplication`` — **tanpa**
``MASUK_BERKAS_ASLI`` (tidak ada pengembalian transport untuk langkah itu).
"""

from __future__ import annotations

# (code, label) — urutan tabel biaya / PDF (tanpa Masuk Berkas Asli)
INBOUND_TRANSPORT_STAGES: tuple[tuple[str, str], ...] = (
    ("MEDICAL", "Medical"),
    ("BUAT_ID_PEKERJA", "Buat ID Pekerja"),
    ("BUAT_PASPOR", "Buat Paspor"),
    ("FWCMS", "FWCMS"),
    ("PSIKOLOGI_TEST", "Psikologi Test"),
    ("PAP_BP3MI", "PAP BP3MI"),
    ("PDO_KILANG", "PDO Kilang"),
    ("PERSIAPAN_KEBERANGKATAN", "Persiapan Keberangkatan"),
)

INBOUND_TRANSPORT_STAGE_CODES: tuple[str, ...] = tuple(c for c, _ in INBOUND_TRANSPORT_STAGES)
INBOUND_TRANSPORT_STAGE_CHOICES: tuple[tuple[str, str], ...] = tuple(INBOUND_TRANSPORT_STAGES)

INBOUND_TRANSPORT_STAGE_CODE_MAX_LENGTH = max(len(c) for c in INBOUND_TRANSPORT_STAGE_CODES)
