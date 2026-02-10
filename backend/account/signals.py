"""
Signals for account app.
Queue OCR when an ApplicantDocument is created or when its file is replaced.
Queue image optimization when an image doc is uploaded and size > 500 KB.
"""
from django.db.models.signals import pre_save, post_save
from django.dispatch import receiver

from .document_specs import MAX_IMAGE_BYTES, is_image_type
from .models import ApplicantDocument
from .tasks import process_document_ocr, optimize_document_image


def _previous_file_name(instance: ApplicantDocument) -> str | None:
    """Nama file sebelum save (untuk deteksi ganti file)."""
    return getattr(instance, "_previous_file_name", None)


@receiver(pre_save, sender=ApplicantDocument)
def _store_previous_file_name(sender, instance: ApplicantDocument, **kwargs):
    if instance.pk:
        try:
            old = ApplicantDocument.objects.only("file").get(pk=instance.pk)
            instance._previous_file_name = old.file.name if old.file else None
        except ApplicantDocument.DoesNotExist:
            instance._previous_file_name = None
    else:
        instance._previous_file_name = None


def _file_was_created_or_replaced(instance: ApplicantDocument, created: bool) -> bool:
    if not instance.file:
        return False
    if created:
        return True
    prev = _previous_file_name(instance)
    return prev != (instance.file.name if instance.file else None)


@receiver(post_save, sender=ApplicantDocument)
def queue_ocr_on_document_upload(sender, instance: ApplicantDocument, created, **kwargs):
    """
    Setelah dokumen diunggah (baru atau file diganti), antrekan OCR di background.
    """
    if _file_was_created_or_replaced(instance, created):
        process_document_ocr.delay(instance.pk)


@receiver(post_save, sender=ApplicantDocument)
def queue_optimize_image_on_upload(sender, instance: ApplicantDocument, created, **kwargs):
    """
    Untuk dokumen tipe gambar: jika ukuran > 500 KB, antrekan kompresi di background.
    """
    if not instance.file or not instance.document_type_id:
        return
    if not is_image_type(instance.document_type.code):
        return
    if not _file_was_created_or_replaced(instance, created):
        return
    try:
        if instance.file.size <= MAX_IMAGE_BYTES:
            return
    except (OSError, ValueError):
        return
    optimize_document_image.delay(instance.pk)
