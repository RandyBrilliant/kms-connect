"""
Celery tasks for main app (berita & lowongan kerja).
"""

from celery import shared_task
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
    now = timezone.now()
    qs = LowonganKerja.objects.filter(
        status=JobStatus.OPEN,
        deadline__lt=now,
    )
    updated = qs.update(status=JobStatus.CLOSED)
    return updated

