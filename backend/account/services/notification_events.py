"""
Notification event definitions.

Single source of truth for:
- All notification event types (NotificationEvent enum)
- Per-event delivery config (channels, priority, type)
- Per-event message templates (title + body with context interpolation)

Usage
-----
    from account.services.notification_events import NotificationEvent, get_event_config, render_event_message

    config = get_event_config(NotificationEvent.PROFILE_ACCEPTED)
    title, message = render_event_message(NotificationEvent.PROFILE_ACCEPTED, {"user": user})
"""

from __future__ import annotations

from enum import Enum
from typing import Any

from ..models import NotificationPriority, NotificationType


# ---------------------------------------------------------------------------
# Event enum
# ---------------------------------------------------------------------------

class NotificationEvent(str, Enum):
    """All application-level notification events."""

    # ---- Account ----
    PASSWORD_CHANGED = "account.password_changed"
    ACCOUNT_DELETION_APPROVED = "account.deletion_approved"   # → Applicant (login disabled; records may be retained)
    ACCOUNT_DELETION_REJECTED = "account.deletion_rejected" # → Applicant

    # ---- Profile verification ----
    PROFILE_SUBMITTED = "profile.submitted"         # → Admin/Staff
    PROFILE_ACCEPTED = "profile.accepted"           # → Applicant
    PROFILE_REJECTED = "profile.rejected"           # → Applicant
    PROFILE_SUBMISSION_SUMMARY = "profile.submission_summary"  # → Applicant (ringkasan yang harus dilengkapi)

    # ---- Job application status ----
    APPLICATION_ASSIGNED = "application.assigned"   # → Applicant (PRA_SELEKSI initial)
    APPLICATION_PRA_SELEKSI_PASSED = "application.pra_seleksi_passed"  # → Applicant
    APPLICATION_INTERVIEW = "application.interview" # → Applicant
    APPLICATION_CADANGAN = "application.cadangan"   # → Applicant (CADANGAN reserve)
    APPLICATION_ACCEPTED = "application.accepted"   # → Applicant (DITERIMA)
    APPLICATION_REJECTED = "application.rejected"   # → Applicant
    APPLICATION_TRANSFERRED = "application.transferred"  # → Applicant (lintas lowongan)
    APPLICATION_DEPARTED = "application.departed"   # → Applicant (BERANGKAT)
    APPLICATION_COMPLETED = "application.completed" # → Applicant (SELESAI)

    # ---- Job listings ----
    JOB_DEADLINE_APPROACHING = "job.deadline_approaching"  # → Applicant (scheduled)
    JOB_POSTED = "job.posted"                              # → Verified applicants (broadcast)

    # ---- Batch ----
    BATCH_DEPARTURE_UPCOMING_7D = "batch.departure_upcoming_7d"  # → Applicant (scheduled)
    BATCH_DEPARTURE_UPCOMING_1D = "batch.departure_upcoming_1d"  # → Applicant (scheduled)
    BATCH_ANNOUNCEMENT = "batch.announcement"                    # → Applicant

    # ---- Documents ----
    DOCUMENT_REJECTED = "document.rejected"   # → Applicant

    # ---- Admin digest ----
    ADMIN_DAILY_DIGEST = "admin.daily_digest"  # → Admin/Staff (scheduled)


# ---------------------------------------------------------------------------
# Event configuration
# ---------------------------------------------------------------------------

class EventConfig:
    """Configuration for a single notification event."""

    __slots__ = (
        "notification_type",
        "priority",
        "send_email",
        "send_push",
        "send_inapp",
        # Preference gate: which NotificationPreference field controls this event.
        # None = always send (e.g. critical security), field name = check before sending.
        "email_pref_field",
        "push_pref_field",
    )

    def __init__(
        self,
        notification_type: str = NotificationType.INFO,
        priority: str = NotificationPriority.NORMAL,
        send_email: bool = False,
        send_push: bool = True,
        send_inapp: bool = True,
        email_pref_field: str | None = None,
        push_pref_field: str | None = None,
    ):
        self.notification_type = notification_type
        self.priority = priority
        self.send_email = send_email
        self.send_push = send_push
        self.send_inapp = send_inapp
        self.email_pref_field = email_pref_field
        self.push_pref_field = push_pref_field


# One config entry per event
_EVENT_CONFIG: dict[NotificationEvent, EventConfig] = {
    # Account
    NotificationEvent.PASSWORD_CHANGED: EventConfig(
        notification_type=NotificationType.WARNING,
        priority=NotificationPriority.HIGH,
        send_email=True,
        send_push=False,
        email_pref_field="email_account_updates",
    ),
    NotificationEvent.ACCOUNT_DELETION_APPROVED: EventConfig(
        notification_type=NotificationType.WARNING,
        priority=NotificationPriority.HIGH,
        send_email=True,
        send_push=False,
        send_inapp=False,
        email_pref_field="email_account_updates",
    ),
    NotificationEvent.ACCOUNT_DELETION_REJECTED: EventConfig(
        notification_type=NotificationType.INFO,
        priority=NotificationPriority.HIGH,
        send_email=True,
        send_push=True,
        email_pref_field="email_account_updates",
        push_pref_field="push_application_updates",
    ),

    # Profile verification
    NotificationEvent.PROFILE_SUBMITTED: EventConfig(
        notification_type=NotificationType.INFO,
        priority=NotificationPriority.NORMAL,
        send_email=False,
        send_push=True,
        send_inapp=True,
        push_pref_field=None,  # Staff/admin always notified
    ),
    NotificationEvent.PROFILE_ACCEPTED: EventConfig(
        notification_type=NotificationType.SUCCESS,
        priority=NotificationPriority.HIGH,
        send_email=True,
        send_push=True,
        email_pref_field="email_profile_updates",
        push_pref_field="push_application_updates",
    ),
    NotificationEvent.PROFILE_REJECTED: EventConfig(
        notification_type=NotificationType.ERROR,
        priority=NotificationPriority.HIGH,
        send_email=True,
        send_push=True,
        email_pref_field="email_profile_updates",
        push_pref_field="push_application_updates",
    ),
    NotificationEvent.PROFILE_SUBMISSION_SUMMARY: EventConfig(
        notification_type=NotificationType.WARNING,
        priority=NotificationPriority.HIGH,
        send_email=False,
        send_push=True,
        send_inapp=True,
        push_pref_field="push_application_updates",
    ),

    # Job application statuses
    NotificationEvent.APPLICATION_ASSIGNED: EventConfig(
        notification_type=NotificationType.INFO,
        priority=NotificationPriority.HIGH,
        send_email=True,
        send_push=True,
        email_pref_field="email_application_updates",
        push_pref_field="push_application_updates",
    ),
    NotificationEvent.APPLICATION_PRA_SELEKSI_PASSED: EventConfig(
        notification_type=NotificationType.SUCCESS,
        priority=NotificationPriority.HIGH,
        send_email=True,
        send_push=True,
        email_pref_field="email_application_updates",
        push_pref_field="push_application_updates",
    ),
    NotificationEvent.APPLICATION_INTERVIEW: EventConfig(
        notification_type=NotificationType.SUCCESS,
        priority=NotificationPriority.URGENT,
        send_email=True,
        send_push=True,
        email_pref_field="email_application_updates",
        push_pref_field="push_application_updates",
    ),
    NotificationEvent.APPLICATION_CADANGAN: EventConfig(
        notification_type=NotificationType.WARNING,
        priority=NotificationPriority.HIGH,
        send_email=True,
        send_push=True,
        email_pref_field="email_application_updates",
        push_pref_field="push_application_updates",
    ),
    NotificationEvent.APPLICATION_ACCEPTED: EventConfig(
        notification_type=NotificationType.SUCCESS,
        priority=NotificationPriority.URGENT,
        send_email=True,
        send_push=True,
        email_pref_field="email_application_updates",
        push_pref_field="push_application_updates",
    ),
    NotificationEvent.APPLICATION_REJECTED: EventConfig(
        notification_type=NotificationType.ERROR,
        priority=NotificationPriority.HIGH,
        send_email=True,
        send_push=True,
        email_pref_field="email_application_updates",
        push_pref_field="push_application_updates",
    ),
    NotificationEvent.APPLICATION_TRANSFERRED: EventConfig(
        notification_type=NotificationType.INFO,
        priority=NotificationPriority.HIGH,
        send_email=True,
        send_push=True,
        email_pref_field="email_application_updates",
        push_pref_field="push_application_updates",
    ),
    NotificationEvent.APPLICATION_DEPARTED: EventConfig(
        notification_type=NotificationType.SUCCESS,
        priority=NotificationPriority.HIGH,
        send_email=True,
        send_push=True,
        email_pref_field="email_application_updates",
        push_pref_field="push_application_updates",
    ),
    NotificationEvent.APPLICATION_COMPLETED: EventConfig(
        notification_type=NotificationType.SUCCESS,
        priority=NotificationPriority.HIGH,
        send_email=True,
        send_push=True,
        email_pref_field="email_application_updates",
        push_pref_field="push_application_updates",
    ),

    # Job listings
    NotificationEvent.JOB_DEADLINE_APPROACHING: EventConfig(
        notification_type=NotificationType.WARNING,
        priority=NotificationPriority.NORMAL,
        # Email reminders disabled to reduce email volume / spam risk.
        send_email=False,
        send_push=True,
        email_pref_field="email_job_deadline_reminder",
        push_pref_field=None,
    ),
    NotificationEvent.JOB_POSTED: EventConfig(
        notification_type=NotificationType.INFO,
        priority=NotificationPriority.LOW,
        send_email=False,   # Marketing / opt-in only
        send_push=True,
        email_pref_field="email_job_alerts",
        push_pref_field=None,
    ),

    # Batch
    NotificationEvent.BATCH_DEPARTURE_UPCOMING_7D: EventConfig(
        notification_type=NotificationType.INFO,
        priority=NotificationPriority.HIGH,
        # Email reminders disabled to reduce email volume / spam risk.
        send_email=False,
        send_push=True,
        email_pref_field="email_batch_departure_reminder",
        push_pref_field="push_application_updates",
    ),
    NotificationEvent.BATCH_DEPARTURE_UPCOMING_1D: EventConfig(
        notification_type=NotificationType.WARNING,
        priority=NotificationPriority.URGENT,
        # Email reminders disabled to reduce email volume / spam risk.
        send_email=False,
        send_push=True,
        email_pref_field="email_batch_departure_reminder",
        push_pref_field="push_application_updates",
    ),
    NotificationEvent.BATCH_ANNOUNCEMENT: EventConfig(
        notification_type=NotificationType.INFO,
        priority=NotificationPriority.NORMAL,
        send_email=False,
        send_push=True,
        push_pref_field=None,
    ),

    # Documents
    NotificationEvent.DOCUMENT_REJECTED: EventConfig(
        notification_type=NotificationType.ERROR,
        priority=NotificationPriority.HIGH,
        send_email=True,
        send_push=True,
        email_pref_field="email_profile_updates",
        push_pref_field=None,
    ),

    # Admin digest (email-only scheduled)
    NotificationEvent.ADMIN_DAILY_DIGEST: EventConfig(
        notification_type=NotificationType.INFO,
        priority=NotificationPriority.NORMAL,
        send_email=True,
        send_push=False,
        send_inapp=False,
        email_pref_field=None,  # Always sent to admins
    ),
}


def get_event_config(event: NotificationEvent) -> EventConfig:
    """Return the delivery config for an event. Raises KeyError if unknown."""
    return _EVENT_CONFIG[event]


# ---------------------------------------------------------------------------
# Message templates
# ---------------------------------------------------------------------------
# Each function receives a ``context`` dict and returns (title: str, body: str).
# Use lazy formatting — avoid heavy DB hits here.

def _t(event: NotificationEvent):
    """Decorator: register a template function for an event."""
    def _decorator(fn):
        _TEMPLATES[event] = fn
        return fn
    return _decorator


_TEMPLATES: dict[NotificationEvent, Any] = {}


@_t(NotificationEvent.PASSWORD_CHANGED)
def _tmpl_password_changed(ctx: dict) -> tuple[str, str]:
    name = ctx.get("user_name", "Pengguna")
    return (
        "Kata Sandi Diubah",
        f"Halo {name}, kata sandi akun Anda baru saja diubah. "
        "Jika Anda tidak melakukan perubahan ini, segera hubungi kami.",
    )


@_t(NotificationEvent.ACCOUNT_DELETION_APPROVED)
def _tmpl_account_deletion_approved(ctx: dict) -> tuple[str, str]:
    name = ctx.get("user_name", "Anda")
    notes = ctx.get("admin_notes", "")
    body = (
        f"Halo {name}, permintaan penghapusan akun Anda telah disetujui dan diproses. "
        "Akun Anda telah ditutup dari layanan aktif: akses login dinonaktifkan dan Anda tidak dapat lagi "
        "menggunakan aplikasi dengan akun ini. Pemrosesan penghapusan dari layanan telah dilaksanakan "
        "sesuai permintaan Anda. Informasi tertentu dapat disimpan sebagaimana diizinkan undang-undang "
        "untuk keperluan operasional dan kepatuhan."
    )
    if notes:
        body += f" Catatan dari admin: {notes}"
    return ("Permintaan Penghapusan Akun Disetujui", body)


@_t(NotificationEvent.ACCOUNT_DELETION_REJECTED)
def _tmpl_account_deletion_rejected(ctx: dict) -> tuple[str, str]:
    name = ctx.get("user_name", "Anda")
    notes = ctx.get("admin_notes", "")
    body = (
        f"Halo {name}, permintaan penghapusan akun Anda tidak disetujui. "
        "Akun Anda tetap aktif dan Anda dapat terus menggunakan layanan."
    )
    if notes:
        body += f" Catatan: {notes}"
    return ("Permintaan Penghapusan Akun Ditolak", body)


@_t(NotificationEvent.PROFILE_SUBMITTED)
def _tmpl_profile_submitted(ctx: dict) -> tuple[str, str]:
    name = ctx.get("applicant_name", "Pelamar")
    register = ctx.get("register_number", "")
    reg_str = f" ({register})" if register else ""
    return (
        "Profil Baru Menunggu Verifikasi",
        f"Profil pelamar {name}{reg_str} telah dikirim dan menunggu verifikasi Anda.",
    )


@_t(NotificationEvent.PROFILE_ACCEPTED)
def _tmpl_profile_accepted(ctx: dict) -> tuple[str, str]:
    name = ctx.get("user_name", "Anda")
    return (
        "Profil Anda Diterima!",
        f"Selamat {name}! Profil Anda telah diverifikasi dan diterima. "
        "Anda sekarang dapat melamar lowongan kerja yang tersedia.",
    )


@_t(NotificationEvent.PROFILE_REJECTED)
def _tmpl_profile_rejected(ctx: dict) -> tuple[str, str]:
    name = ctx.get("user_name", "Anda")
    notes = ctx.get("verification_notes", "")
    body = (
        f"Maaf {name}, pendaftaran Anda tidak dapat kami terima. "
        "Terima kasih atas minat, waktu, dan usaha Anda selama proses pendaftaran ini."
    )
    if notes:
        body += f" Catatan dari admin: {notes}"
    return ("Pendaftaran Anda Ditolak", body)


@_t(NotificationEvent.PROFILE_SUBMISSION_SUMMARY)
def _tmpl_profile_submission_summary(ctx: dict) -> tuple[str, str]:
    name = ctx.get("applicant_name", "Pelamar")
    biodata = (ctx.get("biodata_summary") or "").strip()
    docs = (ctx.get("docs_summary") or "").strip()
    total = ctx.get("total_missing", None)

    missing_cnt_part = ""
    if isinstance(total, int) and total > 0:
        missing_cnt_part = f" (total {total} item yang perlu dilengkapi)"

    parts: list[str] = []
    if biodata:
        parts.append(f"Biodata: {biodata}")
    if docs:
        parts.append(f"Dokumen: {docs}")

    details = " ".join(parts) if parts else "Silakan lengkapi data Anda untuk lanjut melamar."

    return (
        "Ringkasan Pengisian Profil Anda",
        f"Halo {name}! Agar bisa lanjut melamar, mohon lengkapi:{missing_cnt_part} {details}",
    )


@_t(NotificationEvent.APPLICATION_ASSIGNED)
def _tmpl_application_assigned(ctx: dict) -> tuple[str, str]:
    job_title = ctx.get("job_title", "lowongan")
    batch_name = ctx.get("batch_name", "")
    batch_str = f" – {batch_name}" if batch_name else ""
    return (
        "Anda Ditambahkan ke Lamaran Baru",
        f"Anda telah ditambahkan ke lamaran untuk posisi «{job_title}»{batch_str}. "
        "Tahap selanjutnya: Pra-Seleksi. Pantau terus perkembangan di aplikasi.",
    )


@_t(NotificationEvent.APPLICATION_PRA_SELEKSI_PASSED)
def _tmpl_application_pra_seleksi_passed(ctx: dict) -> tuple[str, str]:
    job_title = ctx.get("job_title", "lowongan")
    batch_name = ctx.get("batch_name", "")
    batch_str = f" ({batch_name})" if batch_name else ""
    notes = ctx.get("notes", "")
    body = (
        f"Selamat! Anda dinyatakan lulus tahap Pra-Seleksi untuk posisi "
        f"«{job_title}»{batch_str}. Tim kami akan menginformasikan jadwal "
        "interview berikutnya."
    )
    if notes:
        body += f" Catatan: {notes}."
    return ("Lulus Pra-Seleksi", body)


@_t(NotificationEvent.APPLICATION_INTERVIEW)
def _tmpl_application_interview(ctx: dict) -> tuple[str, str]:
    job_title = ctx.get("job_title", "lowongan")
    date_str = ctx.get("interview_date_str", "")
    location = ctx.get("interview_location", "")
    body = f"Selamat! Anda lolos ke tahap Interview untuk posisi «{job_title}»."
    if date_str:
        body += f" Jadwal: {date_str}."
    if location:
        body += f" Lokasi: {location}."
    body += " Segera konfirmasi kehadiran Anda."
    return ("Undangan Interview", body)


@_t(NotificationEvent.APPLICATION_CADANGAN)
def _tmpl_application_cadangan(ctx: dict) -> tuple[str, str]:
    job_title = ctx.get("job_title", "lowongan")
    company = ctx.get("company_name", "")
    company_str = f" di {company}" if company else ""
    return (
        "Anda Masuk Daftar Cadangan",
        f"Hasil interview Anda untuk posisi «{job_title}»{company_str} "
        "adalah masuk daftar cadangan. "
        "Anda akan diprioritaskan jika slot utama tersedia. Pantau terus status lamaran Anda.",
    )


@_t(NotificationEvent.APPLICATION_ACCEPTED)
def _tmpl_application_accepted(ctx: dict) -> tuple[str, str]:
    job_title = ctx.get("job_title", "lowongan")
    company = ctx.get("company_name", "")
    company_str = f" di {company}" if company else ""
    return (
        "Lamaran Anda Diterima!",
        f"Selamat! Lamaran Anda untuk posisi «{job_title}»{company_str} telah DITERIMA. "
        "Tim kami akan segera menghubungi Anda mengenai langkah berikutnya.",
    )


@_t(NotificationEvent.APPLICATION_TRANSFERRED)
def _tmpl_application_transferred(ctx: dict) -> tuple[str, str]:
    job_title = ctx.get("job_title", "lowongan")
    target = ctx.get("target_job_title", "lowongan lain")
    notes = ctx.get("notes", "")
    body = (
        f"Lamaran Anda untuk posisi «{job_title}» telah dipindahkan ke lowongan "
        f"«{target}» dan melanjutkan ke tahap Interview."
    )
    if notes:
        body += f" Catatan: {notes}."
    body += " Buka aplikasi untuk detail jadwal interview."
    return ("Lamaran Dipindah ke Lowongan Lain", body)


@_t(NotificationEvent.APPLICATION_REJECTED)
def _tmpl_application_rejected(ctx: dict) -> tuple[str, str]:
    job_title = ctx.get("job_title", "lowongan")
    notes = ctx.get("notes", "")
    body = f"Maaf, lamaran Anda untuk posisi «{job_title}» tidak dapat kami lanjutkan saat ini."
    if notes:
        body += f" Catatan: {notes}."
    body += " Tetap semangat dan coba lowongan lain yang tersedia."
    return ("Hasil Seleksi Lamaran", body)


@_t(NotificationEvent.APPLICATION_DEPARTED)
def _tmpl_application_departed(ctx: dict) -> tuple[str, str]:
    job_title = ctx.get("job_title", "lowongan")
    company = ctx.get("company_name", "")
    company_str = f" ({company})" if company else ""
    return (
        "Status: Berangkat",
        f"Selamat! Anda telah resmi dinyatakan berangkat untuk posisi «{job_title}»{company_str}. "
        "Selamat mencapai tujuan dan semoga sukses!",
    )


@_t(NotificationEvent.APPLICATION_COMPLETED)
def _tmpl_application_completed(ctx: dict) -> tuple[str, str]:
    job_title = ctx.get("job_title", "lowongan")
    return (
        "Status: Selesai",
        f"Masa kerja Anda untuk posisi «{job_title}» telah selesai. "
        "Terima kasih atas dedikasi Anda. Anda bisa mendaftar kembali setelah masa cooldown berakhir.",
    )


@_t(NotificationEvent.JOB_DEADLINE_APPROACHING)
def _tmpl_job_deadline(ctx: dict) -> tuple[str, str]:
    job_title = ctx.get("job_title", "lowongan")
    days = ctx.get("days_remaining", 3)
    return (
        f"Deadline Lowongan Dalam {days} Hari",
        f"Lowongan «{job_title}» akan ditutup dalam {days} hari lagi. "
        "Pastikan profil Anda lengkap agar bisa dipertimbangkan.",
    )


@_t(NotificationEvent.JOB_POSTED)
def _tmpl_job_posted(ctx: dict) -> tuple[str, str]:
    job_title = ctx.get("job_title", "lowongan baru")
    company = ctx.get("company_name", "")
    company_str = f" dari {company}" if company else ""
    return (
        "Lowongan Baru Tersedia",
        f"Lowongan baru{company_str}: «{job_title}» sudah dibuka. "
        "Pastikan profil Anda terverifikasi untuk bisa dipertimbangkan.",
    )


@_t(NotificationEvent.BATCH_DEPARTURE_UPCOMING_7D)
def _tmpl_batch_departure_7d(ctx: dict) -> tuple[str, str]:
    batch_name = ctx.get("batch_name", "batch Anda")
    job_title = ctx.get("job_title", "")
    job_str = f" untuk «{job_title}»" if job_title else ""
    return (
        "7 Hari Menuju Keberangkatan",
        f"Keberangkatan {batch_name}{job_str} tinggal 7 hari lagi. "
        "Pastikan semua dokumen dan persiapan Anda sudah lengkap.",
    )


@_t(NotificationEvent.BATCH_DEPARTURE_UPCOMING_1D)
def _tmpl_batch_departure_1d(ctx: dict) -> tuple[str, str]:
    batch_name = ctx.get("batch_name", "batch Anda")
    job_title = ctx.get("job_title", "")
    job_str = f" untuk «{job_title}»" if job_title else ""
    return (
        "Besok Keberangkatan!",
        f"Keberangkatan {batch_name}{job_str} adalah BESOK. "
        "Harap pastikan semua persiapan sudah siap. Hubungi tim kami jika ada pertanyaan.",
    )


@_t(NotificationEvent.BATCH_ANNOUNCEMENT)
def _tmpl_batch_announcement(ctx: dict) -> tuple[str, str]:
    batch_name = ctx.get("batch_name", "Batch Anda")
    title = ctx.get("announcement_title", "Pengumuman Baru")
    body_text = ctx.get("announcement_body", "")
    return (
        f"[{batch_name}] {title}",
        body_text or "Ada pengumuman baru dari admin untuk batch Anda.",
    )


@_t(NotificationEvent.DOCUMENT_REJECTED)
def _tmpl_document_rejected(ctx: dict) -> tuple[str, str]:
    doc_name = ctx.get("document_name", "dokumen")
    reason = ctx.get("rejection_reason", "")
    body = f"Dokumen «{doc_name}» Anda ditolak."
    if reason:
        body += f" Alasan: {reason}."
    body += " Harap unggah ulang dokumen yang valid."
    return ("Dokumen Ditolak", body)


@_t(NotificationEvent.ADMIN_DAILY_DIGEST)
def _tmpl_admin_digest(ctx: dict) -> tuple[str, str]:
    pending = ctx.get("pending_profiles", 0)
    new_today = ctx.get("new_today", 0)
    return (
        "Ringkasan Harian Admin",
        f"Ringkasan: {pending} profil menunggu verifikasi, {new_today} pelamar baru hari ini.",
    )


def render_event_message(event: NotificationEvent, context: dict) -> tuple[str, str]:
    """
    Render (title, message) for the given event and context dict.
    Falls back to a generic message if no template is registered.
    """
    template_fn = _TEMPLATES.get(event)
    if template_fn:
        return template_fn(context)
    return (str(event), "Anda memiliki notifikasi baru.")
