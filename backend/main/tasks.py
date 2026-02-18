"""
Celery tasks for main app (berita & lowongan kerja).
"""

from celery import shared_task
from django.db.utils import ProgrammingError
from django.utils import timezone

from .models import LowonganKerja, JobStatus


@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=3)
def close_expired_jobs(self):
    """
    Tutup lowongan kerja yang sudah melewati deadline.

    Kriteria:
    - status saat ini = OPEN
    - deadline tidak null
    - deadline < sekarang (timezone-aware)

    Aksi:
    - set status → CLOSED
    - tidak mengubah posted_at / created_by.
    """
    try:
        now = timezone.now()
        qs = LowonganKerja.objects.filter(
            status=JobStatus.OPEN,
            deadline__lt=now,
        )
        updated = qs.update(status=JobStatus.CLOSED)
        return updated
    except ProgrammingError as e:
        # Table may not exist yet during fresh DB/migrations (e.g. Celery beat runs before migrate)
        if "does not exist" in str(e):
            return 0
        raise

