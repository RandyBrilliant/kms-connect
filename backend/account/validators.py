"""
Custom validators for account models.

These validators can be reused across models and forms for consistent validation.
"""
from django.core.exceptions import ValidationError
from django.utils.translation import gettext_lazy as _
import re


def validate_nik(value: str) -> None:
    """
    Validate Indonesian NIK (Nomor Induk Kependudukan).
    
    Rules:
    - Must be exactly 16 digits
    - Must contain only numbers
    
    Args:
        value: NIK string to validate
        
    Raises:
        ValidationError: If NIK format is invalid
    """
    if not value:
        return  # Allow blank if field allows it
    
    # Remove any whitespace
    value = value.strip()
    
    # Check if contains only digits
    if not value.isdigit():
        raise ValidationError(
            _("NIK harus berisi angka saja."),
            code='nik_not_numeric'
        )
    
    # Check length
    if len(value) != 16:
        raise ValidationError(
            _("NIK harus tepat 16 digit."),
            code='nik_invalid_length'
        )


def validate_indonesian_phone(value: str) -> None:
    """
    Validate Indonesian phone number format.
    
    Accepts:
    - 08xxxxxxxxxx (10-13 digits starting with 08)
    - +628xxxxxxxxx (starts with +62)
    - 628xxxxxxxxx (starts with 62)
    - With or without spaces/dashes
    
    Args:
        value: Phone number string to validate
        
    Raises:
        ValidationError: If phone format is invalid
    """
    if not value:
        return  # Allow blank if field allows it
    
    # Remove common formatting characters
    cleaned = value.replace(' ', '').replace('-', '').replace('(', '').replace(')', '')
    
    # Remove country code prefix if present
    if cleaned.startswith('+62'):
        cleaned = '0' + cleaned[3:]
    elif cleaned.startswith('62'):
        cleaned = '0' + cleaned[2:]
    
    # Check if contains only digits after cleaning
    if not cleaned.isdigit():
        raise ValidationError(
            _("Nomor telepon harus berisi angka saja (boleh dengan +, -, spasi)."),
            code='phone_invalid_characters'
        )
    
    # Must start with 0
    if not cleaned.startswith('0'):
        raise ValidationError(
            _("Nomor telepon harus dimulai dengan 0 atau +62."),
            code='phone_invalid_prefix'
        )
    
    # Check length (Indonesian mobile: 10-13 digits)
    if len(cleaned) < 10 or len(cleaned) > 13:
        raise ValidationError(
            _("Nomor telepon harus 10-13 digit."),
            code='phone_invalid_length'
        )


def validate_passport_number(value: str) -> None:
    """
    Validate Indonesian passport number format.
    
    Format: 2 letters followed by 7 digits (e.g., AB1234567)
    
    Args:
        value: Passport number string to validate
        
    Raises:
        ValidationError: If passport format is invalid
    """
    if not value:
        return  # Allow blank if field allows it
    
    # Remove whitespace
    value = value.strip().upper()
    
    # Indonesian passport format: 2 letters + 7 digits
    pattern = r'^[A-Z]{2}\d{7}$'
    
    if not re.match(pattern, value):
        raise ValidationError(
            _("Nomor paspor harus 2 huruf diikuti 7 angka (contoh: AB1234567)."),
            code='passport_invalid_format'
        )


def validate_family_card_number(value: str) -> None:
    """
    Validate Indonesian KK (Kartu Keluarga) number.
    
    Format: 16 digits (same as NIK)
    
    Args:
        value: KK number string to validate
        
    Raises:
        ValidationError: If KK format is invalid
    """
    if not value:
        return  # Allow blank if field allows it
    
    value = value.strip()
    
    if not value.isdigit():
        raise ValidationError(
            _("Nomor Kartu Keluarga harus berisi angka saja."),
            code='kk_not_numeric'
        )
    
    if len(value) != 16:
        raise ValidationError(
            _("Nomor Kartu Keluarga harus tepat 16 digit."),
            code='kk_invalid_length'
        )


def validate_bpjs_number(value: str) -> None:
    """
    Validate BPJS Kesehatan number.
    
    Format: 13 digits
    
    Args:
        value: BPJS number string to validate
        
    Raises:
        ValidationError: If BPJS format is invalid
    """
    if not value:
        return  # Allow blank if field allows it
    
    value = value.strip()
    
    if not value.isdigit():
        raise ValidationError(
            _("Nomor BPJS harus berisi angka saja."),
            code='bpjs_not_numeric'
        )
    
    if len(value) != 13:
        raise ValidationError(
            _("Nomor BPJS harus tepat 13 digit."),
            code='bpjs_invalid_length'
        )


def validate_positive_number(value: int) -> None:
    """
    Validate that a number is positive (> 0).
    
    Args:
        value: Number to validate
        
    Raises:
        ValidationError: If number is not positive
    """
    if value is not None and value <= 0:
        raise ValidationError(
            _("Nilai harus lebih besar dari 0."),
            code='not_positive'
        )


def validate_age_range(value: int, min_age: int = 18, max_age: int = 45) -> None:
    """
    Validate that age is within acceptable range for TKI applicants.
    
    Args:
        value: Age in years
        min_age: Minimum acceptable age (default: 18)
        max_age: Maximum acceptable age (default: 45)
        
    Raises:
        ValidationError: If age is outside acceptable range
    """
    if value is None:
        return
    
    if value < min_age:
        raise ValidationError(
            _("Umur minimal %(min_age)s tahun.") % {'min_age': min_age},
            code='age_too_young'
        )
    
    if value > max_age:
        raise ValidationError(
            _("Umur maksimal %(max_age)s tahun.") % {'max_age': max_age},
            code='age_too_old'
        )


def validate_height(value: int) -> None:
    """
    Validate height is within reasonable range.
    
    Args:
        value: Height in centimeters
        
    Raises:
        ValidationError: If height is unrealistic
    """
    if value is None:
        return
    
    if value < 140 or value > 220:
        raise ValidationError(
            _("Tinggi badan harus antara 140-220 cm."),
            code='height_invalid'
        )


def validate_weight(value: int) -> None:
    """
    Validate weight is within reasonable range.
    
    Args:
        value: Weight in kilograms
        
    Raises:
        ValidationError: If weight is unrealistic
    """
    if value is None:
        return
    
    if value < 35 or value > 200:
        raise ValidationError(
            _("Berat badan harus antara 35-200 kg."),
            code='weight_invalid'
        )


def validate_email_domain(value: str, allowed_domains: list = None) -> None:
    """
    Validate email domain is in allowed list (if specified).
    
    Args:
        value: Email address
        allowed_domains: List of allowed domains (e.g., ['company.com', 'example.org'])
        
    Raises:
        ValidationError: If domain is not allowed
    """
    if not value or not allowed_domains:
        return
    
    domain = value.split('@')[-1].lower()
    
    if domain not in [d.lower() for d in allowed_domains]:
        raise ValidationError(
            _("Email harus menggunakan domain: %(domains)s") % {
                'domains': ', '.join(allowed_domains)
            },
            code='email_domain_not_allowed'
        )


def validate_birth_date(value) -> None:
    """
    Validate birth date is reasonable for TKI applicant.
    
    - Not in the future
    - Results in age between 18-65
    
    Args:
        value: Birth date
        
    Raises:
        ValidationError: If birth date is invalid
    """
    if not value:
        return
    
    from datetime import date
    
    today = date.today()
    
    # Can't be born in the future
    if value > today:
        raise ValidationError(
            _("Tanggal lahir tidak boleh di masa depan."),
            code='birth_date_future'
        )
    
    # Calculate age
    age = today.year - value.year - ((today.month, today.day) < (value.month, value.day))
    
    # Check reasonable age range
    if age < 17:
        raise ValidationError(
            _("Umur minimal 17 tahun (untuk pendaftaran)."),
            code='too_young'
        )
    
    if age > 65:
        raise ValidationError(
            _("Umur maksimal 65 tahun."),
            code='too_old'
        )


def validate_date_not_future(value) -> None:
    """
    Validate that a date is not in the future.
    
    Args:
        value: Date to validate
        
    Raises:
        ValidationError: If date is in the future
    """
    if not value:
        return
    
    from datetime import date
    
    if value > date.today():
        raise ValidationError(
            _("Tanggal tidak boleh di masa depan."),
            code='date_future'
        )


def validate_work_experience_dates(start_date, end_date, still_employed: bool) -> None:
    """
    Validate work experience date range.
    
    Args:
        start_date: Employment start date
        end_date: Employment end date
        still_employed: Whether still working there
        
    Raises:
        ValidationError: If dates are invalid
    """
    if not start_date:
        return
    
    from datetime import date
    
    # Start date can't be in future
    if start_date > date.today():
        raise ValidationError(
            {'start_date': _("Tanggal mulai tidak boleh di masa depan.")},
            code='start_date_future'
        )
    
    # If has end date, validate it
    if end_date and not still_employed:
        # End date can't be before start date
        if end_date < start_date:
            raise ValidationError(
                {'end_date': _("Tanggal selesai harus setelah tanggal mulai.")},
                code='end_before_start'
            )
        
        # End date shouldn't be more than 1 year in future (for planned end dates)
        max_future_end = date.today().replace(year=date.today().year + 1)
        if end_date > max_future_end:
            raise ValidationError(
                {'end_date': _("Tanggal selesai terlalu jauh di masa depan.")},
                code='end_date_too_far'
            )
    
    # If still employed, end_date should be None
    if still_employed and end_date:
        raise ValidationError(
            {'end_date': _("Tanggal selesai harus kosong jika masih bekerja.")},
            code='end_date_with_still_employed'
        )
