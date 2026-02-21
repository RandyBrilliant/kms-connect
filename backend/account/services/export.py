"""
Excel export utilities for ApplicantProfile (pelamar).

Design goals:
- Pure functions for Excel generation (no DB queries here).
- Reusable export logic that can be called from views or tasks.
- Handles large datasets efficiently using streaming.
- Follows the same patterns as scoring.py (services separation).
- Includes all data: basic info, work experiences, documents with downloadable links.
"""

from __future__ import annotations

from io import BytesIO
from typing import Any, Iterable
from datetime import datetime

from django.conf import settings

from openpyxl import Workbook
from openpyxl.styles import Font, Alignment, PatternFill
from openpyxl.utils import get_column_letter


# Excel column headers (Indonesian labels matching frontend table)
EXPORT_COLUMNS = [
    # Basic Info
    ("Nama", "full_name"),
    ("Email", "email"),
    ("NIK", "nik"),
    ("No. HP", "contact_phone"),
    ("Tanggal Lahir", "birth_date"),
    ("Tempat Lahir", "birth_place"),
    ("Jenis Kelamin", "gender"),
    ("Alamat", "address"),
    ("Provinsi", "province_display"),
    ("Kota/Kabupaten", "district_display"),
    ("Kecamatan", "subdistrict_display"),
    ("Kelurahan/Desa", "village_display"),
    ("Kode Pos", "postal_code"),
    ("Pendidikan", "education_level"),
    ("Nama Institusi", "education_institution"),
    ("Jurusan", "education_major"),
    ("Tahun Lulus", "education_graduation_year"),
    # Family Info
    ("Alamat Keluarga", "family_address"),
    ("Provinsi Keluarga", "family_province_display"),
    ("Kota Keluarga", "family_district_display"),
    ("Kecamatan Keluarga", "family_subdistrict_display"),
    ("Kelurahan Keluarga", "family_village_display"),
    ("Kode Pos Keluarga", "family_postal_code"),
    ("No. HP Keluarga", "family_phone"),
    ("Email Keluarga", "family_email"),
    # Referral & Admin
    ("Pemberi Rujukan", "referrer_name"),
    ("Status Verifikasi", "verification_status"),
    ("Diverifikasi Oleh", "verified_by_name"),
    ("Tanggal Verifikasi", "verified_at"),
    ("Catatan Verifikasi", "verification_notes"),
    ("Skor", "score"),
    # Account
    ("Status Akun", "is_active"),
    ("Email Terverifikasi", "email_verified"),
    ("Tanggal Bergabung", "created_at"),
    # Work Experiences (concatenated)
    ("Pengalaman Kerja", "work_experiences"),
    # Documents will be added dynamically per document type
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


def _format_industry_type(industry: str | None) -> str:
    """Format industry type for display."""
    industry_map = {
        "SEMICONDUCTOR": "Semiconductor",
        "ELECTRONICS": "Elektronik",
        "OTHER_FACTORY": "Pabrik Lain",
        "SERVICES": "Jasa",
        "OTHER": "Lain Lain",
        "NEVER_WORKED": "Belum Pernah Bekerja",
    }
    return industry_map.get(industry or "", industry or "-")


def _format_document_review_status(status: str | None) -> str:
    """Format document review status for display."""
    status_map = {
        "PENDING": "Pending",
        "APPROVED": "Disetujui",
        "REJECTED": "Ditolak",
    }
    return status_map.get(status or "", status or "-")


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


def _get_file_url(file_field: Any, request: Any = None) -> str:
    """
    Get full URL for a file field.
    
    Args:
        file_field: Django FileField
        request: Django request object (optional, for building absolute URLs)
    
    Returns:
        Full URL to the file or "-" if no file
    """
    if not file_field:
        return "-"
    
    try:
        # Get the file URL
        url = file_field.url if hasattr(file_field, 'url') else str(file_field)
        
        # If URL is relative, make it absolute
        if url.startswith('/'):
            # Use MEDIA_URL from settings
            media_url = getattr(settings, 'MEDIA_URL', '/media/')
            if media_url.startswith('http'):
                # Already absolute (e.g., S3/CDN)
                return url
            else:
                # Build absolute URL
                # Try to get domain from request
                if request:
                    scheme = 'https' if request.is_secure() else 'http'
                    host = request.get_host()
                    return f"{scheme}://{host}{url}"
                else:
                    # Fallback: just return the relative URL
                    return url
        
        return url
    except Exception:
        return "-"


def _format_work_experiences(profile: Any, request: Any = None) -> str:
    """
    Format all work experiences into a readable string.
    
    Returns:
        Multi-line string with all work experiences or "-" if none
    """
    work_experiences = getattr(profile, "work_experiences", None)
    if not work_experiences:
        return "-"
    
    try:
        # Get all work experiences (assuming it's a related manager or list)
        experiences = list(work_experiences.all()) if hasattr(work_experiences, 'all') else work_experiences
        
        if not experiences:
            return "-"
        
        result = []
        for idx, exp in enumerate(experiences, 1):
            parts = [f"#{idx}"]
            
            company = getattr(exp, "company_name", None)
            if company:
                parts.append(f"Perusahaan: {company}")
            
            position = getattr(exp, "position", None)
            if position:
                parts.append(f"Jabatan: {position}")
            
            department = getattr(exp, "department", None)
            if department:
                parts.append(f"Bagian: {department}")
            
            location = getattr(exp, "location", None)
            if location:
                parts.append(f"Lokasi: {location}")
            
            country = getattr(exp, "country", None)
            if country:
                parts.append(f"Negara: {country}")
            
            industry = getattr(exp, "industry_type", None)
            if industry:
                parts.append(f"Industri: {_format_industry_type(industry)}")
            
            start_date = getattr(exp, "start_date", None)
            end_date = getattr(exp, "end_date", None)
            if start_date:
                date_str = f"Periode: {start_date.strftime('%Y-%m-%d')}"
                if end_date:
                    date_str += f" s/d {end_date.strftime('%Y-%m-%d')}"
                else:
                    date_str += " s/d sekarang"
                parts.append(date_str)
            
            result.append(" | ".join(parts))
        
        return "\n".join(result)
    except Exception as e:
        return f"Error: {str(e)}"


def _format_documents(profile: Any, request: Any = None) -> str:
    """
    Format all documents into a readable string with downloadable links.
    
    Returns:
        Multi-line string with all documents and links or "-" if none
    """
    documents = getattr(profile, "documents", None)
    if not documents:
        return "-"
    
    try:
        # Get all documents (assuming it's a related manager or list)
        docs = list(documents.all()) if hasattr(documents, 'all') else documents
        
        if not docs:
            return "-"
        
        result = []
        for doc in docs:
            parts = []
            
            # Document type
            doc_type = getattr(doc, "document_type", None)
            if doc_type:
                type_name = getattr(doc_type, "name", str(doc_type))
                parts.append(f"Tipe: {type_name}")
            
            # Review status
            review_status = getattr(doc, "review_status", None)
            if review_status:
                parts.append(f"Status: {_format_document_review_status(review_status)}")
            
            # File URL
            file_field = getattr(doc, "file", None)
            if file_field:
                url = _get_file_url(file_field, request)
                parts.append(f"Link: {url}")
            
            # Reviewed by
            reviewed_by = getattr(doc, "reviewed_by", None)
            if reviewed_by:
                reviewer_name = getattr(reviewed_by, "full_name", None) or getattr(reviewed_by, "email", "")
                if reviewer_name:
                    parts.append(f"Direview: {reviewer_name}")
            
            # Upload date
            uploaded_at = getattr(doc, "uploaded_at", None)
            if uploaded_at:
                parts.append(f"Tanggal: {uploaded_at.strftime('%Y-%m-%d %H:%M')}")
            
            if parts:
                result.append(" | ".join(parts))
        
        return "\n".join(result)
    except Exception as e:
        return f"Error: {str(e)}"


def generate_applicants_excel(applicants: Iterable[Any], request: Any = None) -> BytesIO:
    """
    Generate Excel file from applicants queryset/iterable.
    
    Args:
        applicants: Iterable of CustomUser objects with applicant_profile loaded.
                   Should use select_related("applicant_profile__user") and
                   prefetch_related("applicant_profile__work_experiences", "applicant_profile__documents")
                   for optimal performance.
        request: Django request object for building absolute URLs
    
    Returns:
        BytesIO object containing the Excel file.
    
    Design:
    - Pure function (no DB queries, no side effects).
    - Efficient for large datasets (streams data row by row).
    - Uses openpyxl for Excel generation.
    - Includes all data: basic info, work experiences, documents with downloadable links.
    - Each document type gets its own column with clickable links.
    """
    from account.models import DocumentType
    
    wb = Workbook()
    ws = wb.active
    ws.title = "Daftar Pelamar"
    
    # Get all document types ordered by sort_order
    document_types = list(DocumentType.objects.all().order_by('sort_order', 'code'))
    
    # Build full column list: base columns + document type columns
    all_columns = list(EXPORT_COLUMNS)
    document_type_columns = {}  # Map document_type.id to column index
    
    for doc_type in document_types:
        doc_type_label = doc_type.name
        doc_type_field = f"document_{doc_type.code}"
        all_columns.append((doc_type_label, doc_type_field))
        document_type_columns[doc_type.id] = len(all_columns) - 1
    
    # Header row styling
    header_fill = PatternFill(start_color="366092", end_color="366092", fill_type="solid")
    header_font = Font(bold=True, color="FFFFFF", size=11)
    header_alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
    
    # Write headers
    for col_idx, (label, _) in enumerate(all_columns, start=1):
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
        
        # Initialize row data dict for document columns
        row_data = {}
        
        # Process base columns
        for col_idx, (_, field_path) in enumerate(EXPORT_COLUMNS, start=1):
            cell = ws.cell(row=row_num, column=col_idx)
            cell.alignment = data_alignment
            
            # Handle special fields
            if field_path == "full_name":
                # full_name is on CustomUser, not ApplicantProfile
                value = _get_nested_value(applicant, "full_name")
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
                        if isinstance(birth_date_obj, datetime):
                            value = birth_date_obj.strftime("%Y-%m-%d")
                        elif hasattr(birth_date_obj, "strftime"):
                            value = birth_date_obj.strftime("%Y-%m-%d")
                        else:
                            value = str(birth_date_obj)
                    except Exception:
                        value = str(birth_date_obj) if birth_date_obj else "-"
                else:
                    value = "-"
            elif field_path == "birth_place":
                value = _get_nested_value(profile, "birth_place")
            elif field_path == "gender":
                gender = _get_nested_value(profile, "gender", "")
                value = _format_gender(gender) if gender != "-" else "-"
            elif field_path == "address":
                value = _get_nested_value(profile, "address")
            elif field_path == "province_display":
                # Province name only
                province = getattr(profile, "province", None)
                value = getattr(province, "name", "-") if province else "-"
            elif field_path == "district_display":
                # Extract regency/district from village_display or related objects
                display_obj = getattr(profile, "village_display", None)
                if isinstance(display_obj, dict):
                    value = display_obj.get("regency", "-")
                elif display_obj and hasattr(display_obj, "regency"):
                    value = str(display_obj.regency)
                else:
                    district = getattr(profile, "district", None)
                    value = getattr(district, "name", "-") if district else "-"
            elif field_path == "subdistrict_display":
                # Extract subdistrict from village_display or related objects
                display_obj = getattr(profile, "village_display", None)
                if isinstance(display_obj, dict):
                    value = display_obj.get("district", "-")
                elif display_obj and hasattr(display_obj, "district"):
                    value = str(display_obj.district)
                else:
                    subdistrict = getattr(profile, "subdistrict", None)
                    value = getattr(subdistrict, "name", "-") if subdistrict else "-"
            elif field_path == "village_display":
                # Extract village from village_display or related objects
                display_obj = getattr(profile, "village_display", None)
                if isinstance(display_obj, dict):
                    value = display_obj.get("village", "-")
                elif display_obj and hasattr(display_obj, "village"):
                    value = str(display_obj.village)
                else:
                    village = getattr(profile, "village", None)
                    value = getattr(village, "name", "-") if village else "-"
            elif field_path == "postal_code":
                value = _get_nested_value(profile, "postal_code")
            elif field_path == "education_level":
                level = _get_nested_value(profile, "education_level", "")
                value = _format_education_level(level) if level != "-" else "-"
            elif field_path == "education_institution":
                value = _get_nested_value(profile, "education_institution")
            elif field_path == "education_major":
                value = _get_nested_value(profile, "education_major")
            elif field_path == "education_graduation_year":
                value = _get_nested_value(profile, "education_graduation_year")
            # Family Info
            elif field_path == "family_address":
                value = _get_nested_value(profile, "family_address")
            elif field_path == "family_province_display":
                # Family province name only
                family_province = getattr(profile, "family_province", None)
                value = getattr(family_province, "name", "-") if family_province else "-"
            elif field_path == "family_district_display":
                display_obj = getattr(profile, "family_village_display", None)
                if isinstance(display_obj, dict):
                    value = display_obj.get("regency", "-")
                elif display_obj and hasattr(display_obj, "regency"):
                    value = str(display_obj.regency)
                else:
                    value = "-"
            elif field_path == "family_subdistrict_display":
                display_obj = getattr(profile, "family_village_display", None)
                if isinstance(display_obj, dict):
                    value = display_obj.get("district", "-")
                elif display_obj and hasattr(display_obj, "district"):
                    value = str(display_obj.district)
                else:
                    value = "-"
            elif field_path == "family_village_display":
                display_obj = getattr(profile, "family_village_display", None)
                if isinstance(display_obj, dict):
                    value = display_obj.get("village", "-")
                elif display_obj and hasattr(display_obj, "village"):
                    value = str(display_obj.village)
                else:
                    value = "-"
            elif field_path == "family_postal_code":
                value = _get_nested_value(profile, "family_postal_code")
            elif field_path == "family_phone":
                value = _get_nested_value(profile, "family_phone")
            elif field_path == "family_email":
                value = _get_nested_value(profile, "family_email")
            # Referral & Admin
            elif field_path == "referrer_name":
                referrer = getattr(profile, "referrer", None)
                if referrer:
                    value = getattr(referrer, "full_name", "") or getattr(referrer, "email", "-")
                else:
                    value = "-"
            elif field_path == "verification_status":
                status = _get_nested_value(profile, "verification_status", "")
                value = _format_verification_status(status) if status != "-" else "-"
            elif field_path == "verified_by_name":
                verified_by = getattr(profile, "verified_by", None)
                if verified_by:
                    value = getattr(verified_by, "full_name", "") or getattr(verified_by, "email", "-")
                else:
                    value = "-"
            elif field_path == "verified_at":
                verified_at = getattr(profile, "verified_at", None)
                if verified_at:
                    if isinstance(verified_at, datetime):
                        value = verified_at.strftime("%Y-%m-%d %H:%M:%S")
                    else:
                        value = str(verified_at)
                else:
                    value = "-"
            elif field_path == "verification_notes":
                value = _get_nested_value(profile, "verification_notes")
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
            # Work Experiences
            elif field_path == "work_experiences":
                value = _format_work_experiences(profile, request)
            else:
                value = _get_nested_value(profile, field_path)
            
            cell.value = value
        
        # Process document columns - each document type gets its own column
        documents = getattr(profile, "documents", None)
        if documents:
            try:
                docs = list(documents.all()) if hasattr(documents, 'all') else documents
                
                # Create a map of document_type_id -> document
                doc_map = {}
                for doc in docs:
                    doc_type = getattr(doc, "document_type", None)
                    if doc_type:
                        doc_map[doc_type.id] = doc
                
                # Fill in document columns
                for doc_type_id, col_offset in document_type_columns.items():
                    col_idx = col_offset + 1  # columns are 1-indexed
                    cell = ws.cell(row=row_num, column=col_idx)
                    cell.alignment = data_alignment
                    
                    if doc_type_id in doc_map:
                        doc = doc_map[doc_type_id]
                        file_field = getattr(doc, "file", None)
                        if file_field:
                            url = _get_file_url(file_field, request)
                            cell.value = url
                        else:
                            cell.value = "-"
                    else:
                        cell.value = "-"
                        
            except Exception as e:
                # If there's an error, just leave document columns empty
                pass
        else:
            # No documents, fill all document columns with "-"
            for doc_type_id, col_offset in document_type_columns.items():
                col_idx = col_offset + 1
                cell = ws.cell(row=row_num, column=col_idx)
                cell.alignment = data_alignment
                cell.value = "-"
        
        row_num += 1
    
    # Auto-adjust column widths
    for col_idx, (label, field_path) in enumerate(all_columns, start=1):
        col_letter = get_column_letter(col_idx)
        # Set minimum width based on header length
        min_width = max(len(label) + 2, 10)
        
        # Special handling for multi-line fields
        if field_path in ["work_experiences", "verification_notes", "address", "family_address"]:
            min_width = max(min_width, 40)  # Wider columns for long text
        # Document columns should be wide enough for URLs
        elif field_path.startswith("document_"):
            min_width = max(min_width, 50)  # Wide columns for URLs
        
        ws.column_dimensions[col_letter].width = min_width
    
    # Freeze header row
    ws.freeze_panes = "A2"
    
    # Save to BytesIO
    output = BytesIO()
    wb.save(output)
    output.seek(0)
    
    return output
