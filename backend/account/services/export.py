"""
Excel export utilities for ApplicantProfile (pelamar).

Design goals:
- Pure functions for Excel generation (no DB queries here).
- Reusable export logic that can be called from views or tasks.
- Handles large datasets efficiently using streaming.
- Follows the same patterns as scoring.py (services separation).
"""

from __future__ import annotations

from io import BytesIO
from typing import Any, Iterable
from datetime import datetime

from openpyxl import Workbook
from openpyxl.styles import Font, Alignment, PatternFill
from openpyxl.utils import get_column_letter


# Excel column headers (Indonesian labels matching frontend table)
EXPORT_COLUMNS = [
    ("Nama", "full_name"),
    ("Email", "email"),
    ("NIK", "nik"),
    ("No. HP", "contact_phone"),
    ("Tanggal Lahir", "birth_date"),
    ("Jenis Kelamin", "gender"),
    ("Alamat", "address"),
    ("Provinsi", "province_display"),
    ("Kota/Kabupaten", "district_display"),
    ("Kelurahan/Desa", "village_display"),
    ("Pendidikan", "education_level"),
    ("Status Verifikasi", "verification_status"),
    ("Skor", "score"),
    ("Status Akun", "is_active"),
    ("Email Terverifikasi", "email_verified"),
    ("Tanggal Bergabung", "created_at"),
]


def _get_nested_value(obj: Any, path: str, default: str = "-") -> str:
    """
    Safely get a nested attribute value and convert to string.
    
    Supports:
    - Dotted paths (e.g., "user.full_name")
    - Direct attributes
    - Returns default if value is None or empty
    """
    if not path:
        return default
    
    current: Any = obj
    for part in path.split("."):
        if current is None:
            return default
        if isinstance(current, dict):
            current = current.get(part)
        else:
            current = getattr(current, part, None)
    
    if current is None:
        return default
    if isinstance(current, bool):
        return "Ya" if current else "Tidak"
    if isinstance(current, datetime):
        return current.strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(current, (int, float)):
        return str(current)
    
    return str(current) if current else default


def _format_verification_status(status: str | None) -> str:
    """Format verification status for display."""
    status_map = {
        "DRAFT": "Draft",
        "SUBMITTED": "Dikirim",
        "ACCEPTED": "Diterima",
        "REJECTED": "Ditolak",
    }
    return status_map.get(status or "", status or "-")


def _format_gender(gender: str | None) -> str:
    """Format gender for display."""
    gender_map = {
        "M": "Laki-laki",
        "F": "Perempuan",
        "O": "Lainnya",
    }
    return gender_map.get(gender or "", gender or "-")


def _format_education_level(level: str | None) -> str:
    """Format education level for display."""
    level_map = {
        "SMP": "SMP",
        "SMA": "SMA",
        "SMK": "SMK",
        "MA": "MA",
        "D3": "D3",
        "S1": "S1",
    }
    return level_map.get(level or "", level or "-")


def _get_region_display(profile: Any, field: str) -> str:
    """
    Extract region display string from village_display or family_village_display.
    Also handles building from related objects if display is not available.
    """
    display_obj = getattr(profile, field, None)
    
    # Handle dict-like objects (from serializer)
    if isinstance(display_obj, dict):
        parts = []
        if display_obj.get("province"):
            parts.append(display_obj["province"])
        if display_obj.get("regency"):
            parts.append(display_obj["regency"])
        if display_obj.get("district"):
            parts.append(display_obj["district"])
        if display_obj.get("village"):
            parts.append(display_obj["village"])
        return ", ".join(parts) if parts else "-"
    
    # Handle object with attributes
    if display_obj:
        parts = []
        if hasattr(display_obj, "province") and display_obj.province:
            parts.append(str(display_obj.province))
        if hasattr(display_obj, "regency") and display_obj.regency:
            parts.append(str(display_obj.regency))
        if hasattr(display_obj, "district") and display_obj.district:
            parts.append(str(display_obj.district))
        if hasattr(display_obj, "village") and display_obj.village:
            parts.append(str(display_obj.village))
        if parts:
            return ", ".join(parts)
    
    # Fallback: build from related objects (if select_related was used)
    if field == "village_display":
        parts = []
        province = getattr(profile, "province", None)
        district = getattr(profile, "district", None)
        village = getattr(profile, "village", None)
        
        if province:
            parts.append(getattr(province, "name", str(province)))
        if district:
            parts.append(getattr(district, "name", str(district)))
        if village:
            parts.append(getattr(village, "name", str(village)))
        
        return ", ".join(parts) if parts else "-"
    
    return "-"


def generate_applicants_excel(applicants: Iterable[Any]) -> BytesIO:
    """
    Generate Excel file from applicants queryset/iterable.
    
    Args:
        applicants: Iterable of CustomUser objects with applicant_profile loaded.
                   Should use select_related("applicant_profile__user") and
                   prefetch_related for optimal performance.
    
    Returns:
        BytesIO object containing the Excel file.
    
    Design:
    - Pure function (no DB queries, no side effects).
    - Efficient for large datasets (streams data row by row).
    - Uses openpyxl for Excel generation.
    """
    wb = Workbook()
    ws = wb.active
    ws.title = "Daftar Pelamar"
    
    # Header row styling
    header_fill = PatternFill(start_color="366092", end_color="366092", fill_type="solid")
    header_font = Font(bold=True, color="FFFFFF", size=11)
    header_alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
    
    # Write headers
    for col_idx, (label, _) in enumerate(EXPORT_COLUMNS, start=1):
        cell = ws.cell(row=1, column=col_idx, value=label)
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = header_alignment
    
    # Data row styling
    data_alignment = Alignment(vertical="top", wrap_text=True)
    
    # Write data rows
    row_num = 2
    for applicant in applicants:
        profile = getattr(applicant, "applicant_profile", None)
        if not profile:
            continue
        
        user = getattr(applicant, "user", applicant) if hasattr(applicant, "user") else applicant
        
        for col_idx, (_, field_path) in enumerate(EXPORT_COLUMNS, start=1):
            cell = ws.cell(row=row_num, column=col_idx)
            cell.alignment = data_alignment
            
            # Handle special fields
            if field_path == "full_name":
                value = _get_nested_value(profile, "full_name") or _get_nested_value(user, "full_name")
            elif field_path == "email":
                value = _get_nested_value(applicant, "email")
            elif field_path == "nik":
                value = _get_nested_value(profile, "nik")
            elif field_path == "contact_phone":
                value = _get_nested_value(profile, "contact_phone")
            elif field_path == "birth_date":
                birth_date_obj = getattr(profile, "birth_date", None)
                if birth_date_obj:
                    try:
                        # Handle date/datetime objects
                        if isinstance(birth_date_obj, datetime):
                            value = birth_date_obj.strftime("%Y-%m-%d")
                        elif hasattr(birth_date_obj, "strftime"):
                            value = birth_date_obj.strftime("%Y-%m-%d")
                        else:
                            # Try string conversion
                            value = str(birth_date_obj)
                    except Exception:
                        value = str(birth_date_obj) if birth_date_obj else "-"
                else:
                    value = "-"
            elif field_path == "gender":
                gender = _get_nested_value(profile, "gender", "")
                value = _format_gender(gender) if gender != "-" else "-"
            elif field_path == "address":
                value = _get_nested_value(profile, "address")
            elif field_path == "province_display":
                # Full region hierarchy
                value = _get_region_display(profile, "village_display")
            elif field_path == "district_display":
                # Extract regency/district from village_display or related objects
                display_obj = getattr(profile, "village_display", None)
                if isinstance(display_obj, dict):
                    value = display_obj.get("regency", "-")
                elif display_obj and hasattr(display_obj, "regency"):
                    value = str(display_obj.regency)
                else:
                    # Fallback to district FK
                    district = getattr(profile, "district", None)
                    value = getattr(district, "name", "-") if district else "-"
            elif field_path == "village_display":
                # Extract village from village_display or related objects
                display_obj = getattr(profile, "village_display", None)
                if isinstance(display_obj, dict):
                    value = display_obj.get("village", "-")
                elif display_obj and hasattr(display_obj, "village"):
                    value = str(display_obj.village)
                else:
                    # Fallback to village FK
                    village = getattr(profile, "village", None)
                    value = getattr(village, "name", "-") if village else "-"
            elif field_path == "education_level":
                level = _get_nested_value(profile, "education_level", "")
                value = _format_education_level(level) if level != "-" else "-"
            elif field_path == "verification_status":
                status = _get_nested_value(profile, "verification_status", "")
                value = _format_verification_status(status) if status != "-" else "-"
            elif field_path == "score":
                score = _get_nested_value(profile, "score", "")
                if score and score != "-":
                    try:
                        score_val = float(score)
                        value = str(int(score_val)) if score_val == int(score_val) else str(score_val)
                    except (ValueError, TypeError):
                        value = score
                else:
                    value = "-"
            elif field_path == "is_active":
                value = "Aktif" if getattr(applicant, "is_active", False) else "Nonaktif"
            elif field_path == "email_verified":
                value = "Ya" if getattr(applicant, "email_verified", False) else "Tidak"
            elif field_path == "created_at":
                created = getattr(profile, "created_at", None) or getattr(applicant, "date_joined", None)
                if created:
                    if isinstance(created, datetime):
                        value = created.strftime("%Y-%m-%d %H:%M:%S")
                    else:
                        value = str(created)
                else:
                    value = "-"
            else:
                value = _get_nested_value(profile, field_path)
            
            cell.value = value
        
        row_num += 1
    
    # Auto-adjust column widths
    for col_idx, (label, _) in enumerate(EXPORT_COLUMNS, start=1):
        col_letter = get_column_letter(col_idx)
        # Set minimum width based on header length
        min_width = max(len(label) + 2, 10)
        ws.column_dimensions[col_letter].width = min_width
    
    # Freeze header row
    ws.freeze_panes = "A2"
    
    # Save to BytesIO
    output = BytesIO()
    wb.save(output)
    output.seek(0)
    
    return output
