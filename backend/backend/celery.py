"""
Celery app for KMS-Connect.
Used for: email, OCR, export to Excel, push notifications, other background tasks.
"""
import os

from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "backend.settings")

app = Celery("backend")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()
