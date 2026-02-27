"""
Chat models: ChatThread and ChatMessage.

One ChatThread per JobApplication — created automatically via signal.
ChatMessages are the individual messages exchanged between the applicant and admin.

Transport: REST polling + FCM push (upgradeable to WebSocket later without model changes).
"""
from django.db import models
from django.utils.translation import gettext_lazy as _

from account.models import CustomUser
from main.models import JobApplication


class ChatThread(models.Model):
    """
    Satu thread obrolan per JobApplication.
    Dibuat otomatis saat JobApplication dibuat (lihat chat/signals.py).

    Keputusan desain:
    - OneToOne ke JobApplication menjaga konteks obrolan terikat pada lamaran spesifik.
    - Admin melihat semua thread; pelamar hanya melihat thread miliknya.
    - Admin dapat menutup thread (is_closed=True) untuk menghentikan pesan baru.
    """

    application = models.OneToOneField(
        JobApplication,
        on_delete=models.CASCADE,
        related_name="chat_thread",
        verbose_name=_("lamaran"),
        help_text=_("Lamaran kerja yang terkait dengan thread ini."),
    )
    is_closed = models.BooleanField(
        _("ditutup"),
        default=False,
        db_index=True,
        help_text=_("Admin dapat menutup thread sehingga tidak ada pesan baru yang dapat dikirim."),
    )
    created_at = models.DateTimeField(_("dibuat pada"), auto_now_add=True)
    updated_at = models.DateTimeField(
        _("diperbarui pada"),
        auto_now=True,
        db_index=True,
        help_text=_("Diperbarui setiap kali pesan baru dikirim — digunakan untuk mengurutkan thread."),
    )

    class Meta:
        verbose_name = _("thread obrolan")
        verbose_name_plural = _("daftar thread obrolan")
        ordering = ["-updated_at"]
        indexes = [
            models.Index(fields=["is_closed", "updated_at"]),
        ]

    def __str__(self) -> str:
        return f"Thread #{self.pk} — {self.application}"


class ChatMessage(models.Model):
    """
    Pesan individual dalam sebuah ChatThread.
    Dapat dikirim oleh pelamar (APPLICANT) atau admin/staff (ADMIN/STAFF).

    is_read: menandai apakah penerima sudah membaca pesan.
    Logika: pesan dari admin → is_read diperbarui oleh pelamar (via mark-read endpoint).
             pesan dari pelamar → admin melihat notifikasi unread_count di thread list.
    """

    thread = models.ForeignKey(
        ChatThread,
        on_delete=models.CASCADE,
        related_name="messages",
        verbose_name=_("thread"),
    )
    sender = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name="sent_chat_messages",
        verbose_name=_("pengirim"),
    )
    body = models.TextField(
        _("isi pesan"),
        help_text=_("Teks pesan."),
    )
    sent_at = models.DateTimeField(
        _("dikirim pada"),
        auto_now_add=True,
        db_index=True,
    )
    is_read = models.BooleanField(
        _("sudah dibaca"),
        default=False,
        db_index=True,
        help_text=_("True setelah penerima membaca pesan ini."),
    )
    read_at = models.DateTimeField(
        _("dibaca pada"),
        null=True,
        blank=True,
    )

    class Meta:
        verbose_name = _("pesan obrolan")
        verbose_name_plural = _("daftar pesan obrolan")
        ordering = ["sent_at"]
        indexes = [
            # Fetch messages in a thread ordered by time (primary query pattern)
            models.Index(fields=["thread", "sent_at"]),
            # Polling query: fetch messages after a timestamp
            models.Index(fields=["thread", "sent_at", "is_read"]),
        ]

    def __str__(self) -> str:
        preview = self.body[:50]
        return f"[Thread #{self.thread_id}] {self.sender.email}: {preview}"
