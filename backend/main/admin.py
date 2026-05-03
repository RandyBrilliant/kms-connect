from django.contrib import admin

from .models import (
    ApplicationStatusHistory,
    BatchAnnouncement,
    InterviewCohort,
    InterviewCohortAnnouncement,
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
        "name", "job", "tahap_order", "tahap_label", "applicant_count",
        "pra_seleksi_date",
        "created_by", "created_at",
    ]
    list_filter = ["job__status", "tahap_order"]
    search_fields = ["name", "notes", "tahap_label", "job__title"]
    ordering = ["job", "tahap_order", "-created_at"]
    readonly_fields = [
        "created_at", "updated_at",
        "applicant_count", "confirmed_pra_seleksi_count", "confirmed_interview_count",
    ]
    inlines = [JobApplicationInline]


# ---------------------------------------------------------------------------
# InterviewCohort
# ---------------------------------------------------------------------------


class CohortApplicationInline(admin.TabularInline):
    model = JobApplication
    fk_name = "interview_cohort"
    extra = 0
    fields = [
        "applicant", "status", "interview_confirmed_at", "applied_at",
    ]
    readonly_fields = ["applicant", "status", "interview_confirmed_at", "applied_at"]
    can_delete = False
    show_change_link = True


@admin.register(InterviewCohort)
class InterviewCohortAdmin(admin.ModelAdmin):
    list_display = [
        "name", "job", "interview_date", "applicant_count",
        "is_active", "created_by", "created_at",
    ]
    list_filter = ["is_active", "job__status"]
    search_fields = ["name", "notes", "job__title"]
    ordering = ["job", "-interview_date", "-created_at"]
    readonly_fields = [
        "created_at", "updated_at",
        "applicant_count", "confirmed_interview_count",
    ]
    inlines = [CohortApplicationInline]


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
        "applicant", "job", "batch", "interview_cohort", "status",
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
# Announcements (batch + cohort)
# ---------------------------------------------------------------------------


@admin.register(BatchAnnouncement)
class BatchAnnouncementAdmin(admin.ModelAdmin):
    list_display = ["title", "batch", "created_by", "created_at"]
    list_filter = ["batch__job"]
    search_fields = ["title", "body", "batch__name"]
    ordering = ["-created_at"]
    readonly_fields = ["created_at", "created_by"]


@admin.register(InterviewCohortAnnouncement)
class InterviewCohortAnnouncementAdmin(admin.ModelAdmin):
    list_display = ["title", "cohort", "created_by", "created_at"]
    list_filter = ["cohort__job"]
    search_fields = ["title", "body", "cohort__name"]
    ordering = ["-created_at"]
    readonly_fields = ["created_at", "created_by"]
