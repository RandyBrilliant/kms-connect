# Load Celery app when Django starts (so shared_task etc. use this app)
from .celery import app as celery_app

__all__ = ("celery_app",)
