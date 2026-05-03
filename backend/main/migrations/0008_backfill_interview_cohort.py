"""
Data migration: backfill InterviewCohort + LamaranBatch tahap_label
based on the legacy schema where one LamaranBatch held both pra-seleksi
and interview schedules.

Backfill rules
--------------
1. Every existing LamaranBatch keeps `tahap_order=1` (default from schema
   migration). We add a human-friendly `tahap_label="Pra-Seleksi"` so
   admin lists are readable from day one.

2. For each LamaranBatch where ANY of the following is true, create exactly
   one InterviewCohort owned by the batch's job:
     - batch.interview_date is set, OR
     - batch has at least one JobApplication that ever reached INTERVIEW
       (status currently INTERVIEW/DITERIMA/BERANGKAT/SELESAI, or any
       ApplicationStatusHistory.to_status == INTERVIEW).
   The new cohort copies interview_date / interview_location /
   interview_notes from the batch (they will remain on the batch row as
   deprecated columns until the next major release).

3. For every JobApplication whose status_history contains INTERVIEW (or
   whose current status is INTERVIEW or later), set its `interview_cohort`
   to the cohort created from its batch. Applications still in PRA_SELEKSI
   keep `interview_cohort = NULL`.

Reversal
--------
The reverse path simply nulls out `interview_cohort` on JobApplication and
deletes generated InterviewCohort rows. Deprecated batch interview columns
are not modified — they were never removed.
"""

from __future__ import annotations

from django.db import migrations


_INTERVIEW_AND_BEYOND = ("INTERVIEW", "DITERIMA", "BERANGKAT", "SELESAI")


def _ensure_tahap_label(batch) -> bool:
    """Set a default human label for legacy batches so admin lists read nicely."""
    if not batch.tahap_label:
        batch.tahap_label = "Pra-Seleksi"
        return True
    return False


def _make_cohort_name(batch) -> str:
    """Stable, deterministic cohort name derived from the batch."""
    if batch.interview_date:
        date_str = batch.interview_date.strftime("%d %b %Y %H:%M")
        return f"Interview {date_str} — {batch.name}"[:120]
    return f"Interview — {batch.name}"[:120]


def forwards(apps, schema_editor):
    LamaranBatch = apps.get_model("main", "LamaranBatch")
    InterviewCohort = apps.get_model("main", "InterviewCohort")
    JobApplication = apps.get_model("main", "JobApplication")
    ApplicationStatusHistory = apps.get_model("main", "ApplicationStatusHistory")

    batches = list(LamaranBatch.objects.all().select_related("job"))
    if not batches:
        return

    batch_ids = [b.pk for b in batches]

    # Set of batch ids whose applications ever touched INTERVIEW or later.
    interview_touched_batch_ids: set[int] = set(
        JobApplication.objects.filter(
            batch_id__in=batch_ids,
            status__in=_INTERVIEW_AND_BEYOND,
        ).values_list("batch_id", flat=True).distinct()
    )
    interview_touched_batch_ids.update(
        ApplicationStatusHistory.objects.filter(
            to_status="INTERVIEW",
            application__batch_id__in=batch_ids,
        ).values_list("application__batch_id", flat=True).distinct()
    )

    cohort_by_batch: dict[int, int] = {}

    for batch in batches:
        label_changed = _ensure_tahap_label(batch)
        needs_cohort = (
            batch.interview_date is not None
            or batch.pk in interview_touched_batch_ids
        )

        if needs_cohort:
            cohort = InterviewCohort.objects.create(
                job=batch.job,
                name=_make_cohort_name(batch),
                notes="(Otomatis dibuat dari LamaranBatch lama saat migrasi.)",
                interview_date=batch.interview_date,
                interview_location=batch.interview_location or "",
                interview_notes=batch.interview_notes or "",
                is_active=True,
                created_by=batch.created_by,
            )
            cohort_by_batch[batch.pk] = cohort.pk

        if label_changed:
            batch.save(update_fields=["tahap_label"])

    if not cohort_by_batch:
        return

    # Decide which applications get linked to a cohort:
    #   - applications currently in INTERVIEW/DITERIMA/BERANGKAT/SELESAI
    #   - applications currently DITOLAK whose history shows they reached INTERVIEW
    interview_reachers: set[int] = set(
        ApplicationStatusHistory.objects.filter(
            to_status="INTERVIEW",
            application__batch_id__in=cohort_by_batch.keys(),
        ).values_list("application_id", flat=True)
    )

    candidates = JobApplication.objects.filter(
        batch_id__in=cohort_by_batch.keys()
    ).only("id", "batch_id", "status", "interview_cohort_id")

    to_update = []
    for app in candidates:
        if app.interview_cohort_id:
            continue
        if app.status in _INTERVIEW_AND_BEYOND or app.pk in interview_reachers:
            cohort_id = cohort_by_batch.get(app.batch_id)
            if cohort_id:
                app.interview_cohort_id = cohort_id
                to_update.append(app)

    if to_update:
        JobApplication.objects.bulk_update(
            to_update, ["interview_cohort"], batch_size=500
        )


def backwards(apps, schema_editor):
    JobApplication = apps.get_model("main", "JobApplication")
    InterviewCohort = apps.get_model("main", "InterviewCohort")

    JobApplication.objects.exclude(interview_cohort__isnull=True).update(
        interview_cohort=None
    )
    InterviewCohort.objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ("main", "0007_add_interview_cohort_and_tahapan"),
    ]

    operations = [
        migrations.RunPython(forwards, backwards),
    ]
