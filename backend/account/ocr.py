"""
OCR helpers for KMS-Connect.
- Google Cloud Vision: full text extraction (account.tasks.process_document_ocr).
- KTP text parsing: heuristik dari teks OCR ke dict (nik, name, birth_place, birth_date, address, gender).
"""
import re
from .models import KTP_OCR_KEYS


def parse_ktp_text(text: str) -> dict:
    """
    Parse teks OCR KTP (Indonesia) menjadi dict dengan kunci KTP_OCR_KEYS.
    Format KTP bervariasi; ini heuristik umum (NIK 16 digit, baris nama, tempat/tgl lahir, alamat).
    """
    if not text or not text.strip():
        return {k: "" for k in KTP_OCR_KEYS}

    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    full_text = " ".join(lines)
    result = {k: "" for k in KTP_OCR_KEYS}

    # NIK: 16 digit (biasanya berdiri sendiri atau setelah label "NIK")
    nik_match = re.search(r"\b(\d{16})\b", full_text)
    if nik_match:
        result["nik"] = nik_match.group(1)

    # Nama: sering di baris setelah "Nama" atau baris pertama yang panjang (bukan angka)
    for i, line in enumerate(lines):
        if re.match(r"^nama\s*[:.]?\s*", line, re.I):
            value = re.sub(r"^nama\s*[:.]?\s*", "", line, flags=re.I).strip()
            if value and not value.isdigit():
                result["name"] = value
            break
        if re.match(r"^nama\s*$", line, re.I) and i + 1 < len(lines):
            candidate = lines[i + 1].strip()
            if candidate and not candidate.isdigit() and len(candidate) > 2:
                result["name"] = candidate
                break
    if not result["name"] and lines:
        for line in lines[:5]:
            if len(line) > 4 and not line.isdigit() and not re.match(r"^\d", line):
                result["name"] = line.strip()
                break

    # Tempat lahir / Tanggal lahir
    for i, line in enumerate(lines):
        if re.search(r"tempat\s*[/.]?\s*tgl\.?\s*lahir|ttl|lahir", line, re.I):
            parts = re.split(r"[,/]|\s{2,}", line, maxsplit=2)
            for p in parts:
                p = p.strip()
                if p and not p.isdigit():
                    if not result["birth_place"]:
                        result["birth_place"] = p
                    elif not result["birth_date"] and re.search(r"\d", p):
                        result["birth_date"] = p
                        break
            if result["birth_date"]:
                break
        if re.match(r"^tempat\s*[:.]?\s*", line, re.I):
            result["birth_place"] = re.sub(r"^tempat\s*[:.]?\s*", "", line, flags=re.I).strip()
        if re.search(r"\d{1,2}[-/]\d{1,2}[-/]\d{2,4}", line):
            result["birth_date"] = line.strip()

    # Alamat
    for i, line in enumerate(lines):
        if re.match(r"^alamat\s*[:.]?\s*", line, re.I):
            result["address"] = re.sub(r"^alamat\s*[:.]?\s*", "", line, flags=re.I).strip()
            break
        if re.match(r"^alamat\s*$", line, re.I) and i + 1 < len(lines):
            result["address"] = lines[i + 1].strip()
            break
    if not result["address"]:
        for line in lines:
            if "kel/" in line.lower() or "rt/" in line.lower() or "desa" in line.lower() or "kec" in line.lower():
                result["address"] = line.strip()
                break

    # Jenis kelamin
    for line in lines:
        if re.search(r"jenis\s*kelamin|kelamin|j[ke]\s*[:.]?\s*", line, re.I):
            if re.search(r"\b(laki|laki-laki|pria|male|m)\b", line, re.I):
                result["gender"] = "M"
            elif re.search(r"\b(perempuan|wanita|female|f)\b", line, re.I):
                result["gender"] = "F"
            break

    return result
