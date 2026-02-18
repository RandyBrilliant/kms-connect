"""
Admin for account models: CustomUser, role-based profiles, and document types.
Aligned with account models: full_name on CustomUser, regions FK, WorkExperience.country.
"""

from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils.translation import gettext_lazy as _

from .models import (
    CustomUser,
    StaffProfile,
    ApplicantProfile,
    WorkExperience,
    CompanyProfile,
    DocumentType,
    ApplicantDocument,
)


@admin.register(CustomUser)
class CustomUserAdmin(BaseUserAdmin):
    list_display = ("email", "full_name", "role", "referral_code", "email_verified", "is_active", "date_joined")
    list_filter = ("role", "is_active", "email_verified")
    search_fields = ("email", "full_name", "referral_code")
    ordering = ("-date_joined",)
    readonly_fields = ("date_joined", "last_login", "updated_at", "email_verified_at")

    fieldsets = (
        (None, {"fields": ("email", "password")}),
        (_("Profil"), {"fields": ("full_name",)}),
        (_("Peran & status"), {"fields": ("role", "is_active", "is_staff", "is_superuser")}),
        (_("Kode Rujukan"), {"fields": ("referral_code",)}),
        (_("Verifikasi email"), {"fields": ("email_verified", "email_verified_at")}),
        (_("OAuth"), {"fields": ("google_id",)}),
        (_("Tanggal penting"), {"fields": ("date_joined", "last_login", "updated_at")}),
    )

    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("email", "full_name", "role", "password1", "password2"),
            },
        ),
    )


@admin.register(StaffProfile)
class StaffProfileAdmin(admin.ModelAdmin):
    list_display = ("user", "contact_phone", "created_at")
    list_filter = ("created_at",)
    search_fields = ("user__full_name", "user__email", "contact_phone")
    raw_id_fields = ("user",)
    readonly_fields = ("created_at", "updated_at")


class WorkExperienceInline(admin.TabularInline):
    model = WorkExperience
    extra = 0
    ordering = ("sort_order", "-end_date", "-start_date")
    readonly_fields = ("created_at", "updated_at")


class ApplicantDocumentInline(admin.TabularInline):
    model = ApplicantDocument
    extra = 0
    readonly_fields = ("uploaded_at",)
    autocomplete_fields = ("document_type",)


@admin.register(ApplicantProfile)
class ApplicantProfileAdmin(admin.ModelAdmin):
    list_display = (
        "user",
        "nik",
        "verification_status",
        "get_referrer_display",
        "contact_phone",
        "birth_date",
        "verified_at",
        "created_at",
    )
    list_filter = ("gender", "verification_status", "destination_country", "province", "religion", "education_level", "created_at")
    search_fields = ("user__full_name", "user__email", "nik", "contact_phone")
    raw_id_fields = ("user", "referrer", "verified_by")
    autocomplete_fields = ("province", "district", "village", "family_province", "family_district", "family_village")
    readonly_fields = ("created_at", "updated_at")
    inlines = [WorkExperienceInline, ApplicantDocumentInline]

    fieldsets = (
        (_("Pengguna & perujuk"), {"fields": ("user", "referrer")}),
        (
            _("Pendaftaran & tujuan"),
            {
                "fields": ("registration_date", "destination_country"),
                "description": _("Form: tanggal pendaftaran, negara yang dituju."),
            },
        ),
        (
            _("I. Data CPMI (Biodata)"),
            {
                "fields": (
                    "birth_place",
                    "birth_date",
                    "address",
                    "district",
                    "province",
                    "village",
                    "contact_phone",
                    "sibling_count",
                    "birth_order",
                ),
            },
        ),
        (
            _("II. Orangtua / Keluarga"),
            {
                "fields": (
                    "father_name",
                    "father_age",
                    "father_occupation",
                    "mother_name",
                    "mother_age",
                    "mother_occupation",
                    "spouse_name",
                    "spouse_age",
                    "spouse_occupation",
                    "family_address",
                    "family_district",
                    "family_province",
                    "family_village",
                    "family_contact_phone",
                ),
                "description": _("Ayah, Ibu, dan Suami/Istri (isi sesuai yang berlaku)."),
            },
        ),
        (
            _("Pernyataan CPMI"),
            {
                "fields": ("data_declaration_confirmed", "zero_cost_understood"),
                "description": _("Data benar? Paham zero cost?"),
            },
        ),
        (
            _("Identitas & data lainnya"),
            {
                "fields": (
                    "nik",
                    "gender",
                    "religion",
                    "education_level",
                    "education_major",
                    "height_cm",
                    "weight_kg",
                    "wears_glasses",
                    "writing_hand",
                    "marital_status",
                    "has_passport",
                    "passport_number",
                    "passport_expiry_date",
                    "family_card_number",
                    "diploma_number",
                    "bpjs_number",
                    "shoe_size",
                    "shirt_size",
                    "photo",
                    "notes",
                ),
            },
        ),
        (
            _("Verifikasi / seleksi"),
            {
                "fields": (
                    "verification_status",
                    "submitted_at",
                    "verified_at",
                    "verified_by",
                    "verification_notes",
                ),
                "description": _(
                    "Admin memverifikasi biodata dan dokumen. Status ditampilkan ke pelamar."
                ),
            },
        ),
        (_("Waktu"), {"fields": ("created_at", "updated_at")}),
    )


@admin.register(WorkExperience)
class WorkExperienceAdmin(admin.ModelAdmin):
    list_display = (
        "applicant_profile",
        "company_name",
        "location",
        "country",
        "industry_type",
        "position",
        "department",
        "start_date",
        "end_date",
        "still_employed",
        "sort_order",
    )
    list_filter = ("country", "industry_type", "still_employed", "created_at")
    search_fields = ("company_name", "position", "applicant_profile__user__full_name")
    raw_id_fields = ("applicant_profile",)
    readonly_fields = ("created_at", "updated_at")
    ordering = ("applicant_profile", "sort_order", "-end_date", "-start_date")


@admin.register(DocumentType)
class DocumentTypeAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "is_required", "sort_order", "description")
    list_filter = ("is_required",)
    search_fields = ("code", "name")
    ordering = ("sort_order", "code")


@admin.register(ApplicantDocument)
class ApplicantDocumentAdmin(admin.ModelAdmin):
    list_display = (
        "applicant_profile",
        "document_type",
        "uploaded_at",
        "ocr_processed_at",
        "has_ocr_data",
    )
    list_filter = ("document_type", "uploaded_at")
    search_fields = ("applicant_profile__user__full_name", "document_type__name")
    raw_id_fields = ("applicant_profile", "document_type")
    readonly_fields = ("uploaded_at", "ocr_processed_at", "ocr_data", "ocr_text")

    def has_ocr_data(self, obj):
        return bool(obj.ocr_data) if obj else False

    has_ocr_data.boolean = True
    has_ocr_data.short_description = _("Data OCR")


@admin.register(CompanyProfile)
class CompanyProfileAdmin(admin.ModelAdmin):
    list_display = ("company_name", "user", "contact_phone", "created_at")
    list_filter = ("created_at",)
    search_fields = ("company_name", "user__email", "contact_phone")
    raw_id_fields = ("user",)
    readonly_fields = ("created_at", "updated_at")
