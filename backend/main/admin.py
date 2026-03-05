from django.contrib import admin

from .models import (
    ApplicationStatusHistory,
    BatchAnnouncement,
    JobApplication,
    LamaranBatch,
    LowonganKerja,
    News,
)


# ---------------------------------------------------------------------------
# News
# ---------------------------------------------------------------------------


@admin.register(News)
class NewsAdmin(admin.ModelAdmin):
    list_display = ["title", "status", "is_pinned", "published_at", "created_by"]
    list_filter = ["status", "is_pinned"]
    search_fields = ["title", "summary", "content"]
    ordering = ["-published_at", "-created_at"]
    readonly_fields = ["slug", "created_at", "updated_at"]


# ---------------------------------------------------------------------------
# LowonganKerja
# ---------------------------------------------------------------------------


@admin.register(LowonganKerja)
class LowonganKerjaAdmin(admin.ModelAdmin):
    list_display = ["title", "company", "status", "employment_type", "posted_at", "deadline", "start_date", "quota"]
    list_filter = ["status", "employment_type", "location_country"]
    search_fields = ["title", "description", "company__company_name"]
    ordering = ["-posted_at"]
    readonly_fields = ["slug", "created_at", "updated_at"]


# ---------------------------------------------------------------------------
# LamaranBatch
# ---------------------------------------------------------------------------


class JobApplicationInline(admin.TabularInline):
    model = JobApplication
    extra = 0
    fields = [
        "applicant", "status",
        "pra_seleksi_confirmed_at", "interview_confirmed_at",
        "applied_at",
    ]
    readonly_fields = ["applicant", "status", "pra_seleksi_confirmed_at", "interview_confirmed_at", "applied_at"]
    can_delete = False
    show_change_link = True


@admin.register(LamaranBatch)
class LamaranBatchAdmin(admin.ModelAdmin):
    list_display = [
        "name", "job", "applicant_count",
        "pra_seleksi_date", "interview_date",
        "created_by", "created_at",
    ]
    list_filter = ["job__status"]
    search_fields = ["name", "notes", "job__title"]
    ordering = ["-created_at"]
    readonly_fields = ["created_at", "updated_at", "applicant_count", "confirmed_pra_seleksi_count", "confirmed_interview_count"]
    inlines = [JobApplicationInline]


# ---------------------------------------------------------------------------
# JobApplication
# ---------------------------------------------------------------------------


class ApplicationStatusHistoryInline(admin.TabularInline):
    model = ApplicationStatusHistory
    extra = 0
    fields = ["from_status", "to_status", "changed_by", "changed_at", "note"]
    readonly_fields = fields
    can_delete = False


@admin.register(JobApplication)
class JobApplicationAdmin(admin.ModelAdmin):
    list_display = [
        "applicant", "job", "batch", "status",
        "pra_seleksi_confirmed_at", "interview_confirmed_at",
        "applied_at",
    ]
    list_filter = ["status", "job"]
    search_fields = ["applicant__user__full_name", "applicant__user__email", "job__title"]
    ordering = ["-applied_at"]
    readonly_fields = [
        "applied_at", "pra_seleksi_confirmed_at", "interview_confirmed_at",
        "placement_end_date", "created_at", "updated_at",
    ]
    inlines = [ApplicationStatusHistoryInline]


# ---------------------------------------------------------------------------
# BatchAnnouncement
# ---------------------------------------------------------------------------


@admin.register(BatchAnnouncement)
class BatchAnnouncementAdmin(admin.ModelAdmin):
    list_display = ["title", "batch", "created_by", "created_at"]
    list_filter = ["batch__job"]
    search_fields = ["title", "body", "batch__name"]
    ordering = ["-created_at"]
    readonly_fields = ["created_at", "created_by"]
