"""
Signal handlers for the chat app.
Auto-creates a ChatThread whenever a new JobApplication is created.
"""
from django.db.models.signals import post_save
from django.dispatch import receiver

from main.models import JobApplication


@receiver(post_save, sender=JobApplication)
def create_chat_thread_on_application(sender, instance, created, **kwargs):
    """
    Auto-create a ChatThread for every new JobApplication.
    Uses get_or_create to be idempotent (safe to run twice if needed).
    """
    if created:
        from .models import ChatThread
        ChatThread.objects.get_or_create(application=instance)
