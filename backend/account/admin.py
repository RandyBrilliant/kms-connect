"""
Admin for account models: CustomUser, role-based profiles, and document types.
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
    list_display = ("email", "role", "email_verified", "is_active", "date_joined")
    list_filter = ("role", "is_active", "email_verified")
    search_fields = ("email",)
    ordering = ("-date_joined",)
    readonly_fields = ("date_joined", "last_login", "updated_at", "email_verified_at")

    fieldsets = (
        (None, {"fields": ("email", "password")}),
        (_("Peran & status"), {"fields": ("role", "is_active", "is_staff", "is_superuser")}),
        (_("Verifikasi email"), {"fields": ("email_verified", "email_verified_at")}),
        (_("OAuth"), {"fields": ("google_id",)}),
        (_("Tanggal penting"), {"fields": ("date_joined", "last_login", "updated_at")}),
    )

    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("email", "role", "password1", "password2"),
            },
        ),
    )


@admin.register(StaffProfile)
class StaffProfileAdmin(admin.ModelAdmin):
    list_display = ("full_name", "user", "contact_phone", "created_at")
    list_filter = ("created_at",)
    search_fields = ("full_name", "user__email", "contact_phone")
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
        "full_name",
        "user",
        "nik",
        "verification_status",
        "get_referrer_display",
        "contact_phone",
        "birth_date",
        "verified_at",
        "created_at",
    )
    list_filter = ("gender", "verification_status", "created_at")
    search_fields = ("full_name", "user__email", "nik", "contact_phone")
    raw_id_fields = ("user", "referrer", "verified_by")
    readonly_fields = ("created_at", "updated_at")
    inlines = [WorkExperienceInline, ApplicantDocumentInline]

    fieldsets = (
        (_("Pengguna & perujuk"), {"fields": ("user", "referrer")}),
        (
            _("I. Data CPMI (Biodata)"),
            {
                "fields": (
                    "full_name",
                    "birth_place",
                    "birth_date",
                    "address",
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
                    "family_contact_phone",
                ),
                "description": _("Ayah, Ibu, dan Suami/Istri (isi sesuai yang berlaku)."),
            },
        ),
        (
            _("Identitas & foto"),
            {"fields": ("nik", "gender", "photo", "notes")},
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
    list_display = ("applicant_profile", "company_name", "position", "start_date", "end_date", "still_employed", "sort_order")
    list_filter = ("still_employed", "created_at")
    search_fields = ("company_name", "position", "applicant_profile__full_name")
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
    search_fields = ("applicant_profile__full_name", "document_type__name")
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
