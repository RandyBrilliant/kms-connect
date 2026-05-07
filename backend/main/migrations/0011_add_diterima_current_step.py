"""
Migration 0011 – add diterima_current_step to JobApplication.

The field is a CharField with a fixed default of "MASUK_BERKAS_ASLI".
For existing rows already in the DITERIMA status, we run a data migration
that infers the correct starting position from the applicant's profile data
(e.g. if their Medical result is already "FIT", we push them past that step)
so that admins do not have to click through every step manually.
"""
from django.db import migrations, models


# ---------------------------------------------------------------------------
# Helper: derive the first sub-step that is NOT yet complete from profile data.
# This mirrors the logic in ApplicationService.get_document_collection_progress.
# ---------------------------------------------------------------------------
STEP_ORDER = [
    "MASUK_BERKAS_ASLI",
    "MEDICAL",
    "BUAT_ID_PEKERJA",
    "BUAT_PASPOR",
    "FWCMS",
    "PSIKOLOGI_TEST",
    "PAP_BP3MI",
    "PDO_KILANG",
    "PERSIAPAN_KEBERANGKATAN",
]


def _step_done(profile, step_code):
    """Return True if the data required for *step_code* exists on *profile*."""
    if step_code == "MASUK_BERKAS_ASLI":
        # Consider done if at least one of the common post-acceptance doc
        # fields is populated (simplified check; same spirit as service logic).
        return bool(
            getattr(profile, "tgl_keberangkatan", None)
            or getattr(profile, "hasil_medical", None)
            or getattr(profile, "no_id_sisko", None)
        )
    if step_code == "MEDICAL":
        return getattr(profile, "hasil_medical", None) == "FIT"
    if step_code == "BUAT_ID_PEKERJA":
        return bool(getattr(profile, "no_id_sisko", None))
    if step_code == "BUAT_PASPOR":
        return bool(getattr(profile, "passport_number", None))
    if step_code in ("FWCMS", "PSIKOLOGI_TEST"):
        return bool(getattr(profile, "tgl_fwcm_psikotes", None))
    if step_code == "PAP_BP3MI":
        return bool(getattr(profile, "no_sip", None))
    if step_code == "PDO_KILANG":
        return bool(getattr(profile, "tgl_kirim_bio_ke_mly", None))
    if step_code == "PERSIAPAN_KEBERANGKATAN":
        return bool(getattr(profile, "tgl_calling_visa", None)) and bool(
            getattr(profile, "no_calling_visa", None)
        )
    return False


def _infer_current_step(profile):
    """Return the first incomplete step (or the last step if everything done)."""
    last = STEP_ORDER[-1]
    for step in STEP_ORDER:
        if not _step_done(profile, step):
            return step
    return last


def set_diterima_current_step(apps, schema_editor):
    JobApplication = apps.get_model("main", "JobApplication")
    # Only update rows that are in DITERIMA status.
    # "DITERIMA" is the string value stored in the DB column.
    diterima_apps = JobApplication.objects.filter(status="DITERIMA").select_related(
        "applicant_user__applicantprofile"
    )
    to_update = []
    for app in diterima_apps:
        try:
            profile = app.applicant_user.applicantprofile
            inferred = _infer_current_step(profile)
        except Exception:
            # If profile is missing, default to first step – safest.
            inferred = STEP_ORDER[0]
        app.diterima_current_step = inferred
        to_update.append(app)

    if to_update:
        JobApplication.objects.bulk_update(to_update, ["diterima_current_step"])


def noop(apps, schema_editor):
    """Reverse migration is a no-op; the column is just dropped."""
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("main", "0010_add_diterima_step_confirmations"),
    ]

    operations = [
        migrations.AddField(
            model_name="jobapplication",
            name="diterima_current_step",
            field=models.CharField(
                choices=[
                    ("MASUK_BERKAS_ASLI", "Masuk Berkas Asli"),
                    ("MEDICAL", "Medical"),
                    ("BUAT_ID_PEKERJA", "Buat ID Pekerja"),
                    ("BUAT_PASPOR", "Buat Paspor"),
                    ("FWCMS", "FWCMS"),
                    ("PSIKOLOGI_TEST", "Psikologi Test"),
                    ("PAP_BP3MI", "PAP BP3MI"),
                    ("PDO_KILANG", "PDO Kilang"),
                    ("PERSIAPAN_KEBERANGKATAN", "Persiapan Keberangkatan"),
                ],
                db_index=True,
                default="MASUK_BERKAS_ASLI",
                help_text=(
                    "Posisi pelamar dalam alur sub-tahapan Diterima (9 langkah "
                    "berurutan). Dikendalikan oleh admin."
                ),
                max_length=30,
                verbose_name="sub-tahapan diterima saat ini",
            ),
        ),
        # Backfill existing DITERIMA rows to the inferred position.
        migrations.RunPython(set_diterima_current_step, reverse_code=noop),
    ]
