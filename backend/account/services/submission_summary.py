from __future__ import annotations

from typing import Iterable


PROFILE_FIELD_LABELS: dict[str, str] = {
    "user.full_name": "Nama Lengkap",
    "nik": "NIK",
    "birth_date": "Tanggal Lahir",
    "gender": "Jenis Kelamin",
    "address": "Alamat",
    "postal_code": "Kode Pos",
    "contact_phone": "No. HP / WA",
    "province_id": "Provinsi (alamat KTP)",
    "district_id": "Kota / Kabupaten (alamat KTP)",
    "village_id": "Kelurahan / Desa (alamat KTP)",
    "education_level": "Pendidikan Terakhir",
    "marital_status": "Status Perkawinan",
    "registration_date": "Tanggal Pendaftaran",
    "destination_country": "Negara Tujuan",
    "sibling_count": "Jumlah Saudara",
    "birth_order": "Anak ke-",
    "religion": "Agama",
    "education_major": "Jurusan Pendidikan",
    "data_declaration_confirmed": "Pernyataan Data Benar",
    "height_cm": "Tinggi Badan (cm)",
    "weight_kg": "Berat Badan (kg)",
    "wears_glasses": "Memakai Kacamata",
    "writing_hand": "Tangan yang Digunakan untuk Menulis",
    "shoe_size": "Ukuran Sepatu",
    "shirt_size": "Ukuran Baju",
    "family_postal_code": "Kode Pos Keluarga",
    "passport_number": "Nomor Paspor",
    "passport_issue_date": "Tanggal Terbit Paspor",
    "passport_issue_place": "Tempat Terbit Paspor",
    "passport_expiry_date": "Tanggal Kadaluarsa Paspor",
    "referrer_id": "Informasi Rujukan (Perujuk)",
    "parent_info": "Data Orang Tua (Ayah/Ibu)",
    "heir_info": "Data Ahli Waris",
}

DOC_CODE_LABELS: dict[str, str] = {
    "ktp": "KTP",
    "kartu-keluarga": "Kartu Keluarga",
    "ijasah": "Ijazah",
    "kartu-bpjs": "Kartu BPJS Kesehatan",
    "paspor": "Paspor",
    "pas-foto": "Pas Foto",
}


def _truncate_list(items: list[str], *, limit: int) -> str:
    if not items:
        return ""
    if len(items) <= limit:
        return ", ".join(items)
    head = ", ".join(items[:limit])
    remaining = len(items) - limit
    return f"{head}, dan {remaining} lainnya"


def _humanize_missing_profile_items(missing_profile: Iterable[str], *, limit: int) -> str:
    labels: list[str] = []
    for key in missing_profile:
        labels.append(PROFILE_FIELD_LABELS.get(key, key.replace("_", " ").replace(".", " ").title()))
    return _truncate_list(labels, limit=limit)


def _humanize_missing_docs_items(missing_doc_codes: Iterable[str], *, limit: int) -> str:
    labels: list[str] = []
    for code in missing_doc_codes:
        labels.append(DOC_CODE_LABELS.get(code, code.replace("-", " ").title()))
    return _truncate_list(labels, limit=limit)


def build_submission_summary_context(
    *,
    applicant_name: str,
    missing_profile: list[str],
    missing_docs: list[str],
    biodata_limit: int = 6,
    docs_limit: int = 6,
) -> dict[str, str | int]:
    total_missing = len(missing_profile) + len(missing_docs)
    biodata_summary = _humanize_missing_profile_items(missing_profile, limit=biodata_limit)
    docs_summary = _humanize_missing_docs_items(missing_docs, limit=docs_limit)

    return {
        "applicant_name": applicant_name,
        "biodata_summary": biodata_summary,
        "docs_summary": docs_summary,
        "total_missing": total_missing,
    }

