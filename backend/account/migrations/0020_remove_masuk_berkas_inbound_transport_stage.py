# Masuk Berkas Asli is not part of inbound transport reimbursement.

from django.db import migrations, models


def forwards_delete_masuk_berkas_cost_rows(apps, schema_editor):
    ApplicantInboundTransportStageCost = apps.get_model(
        "account", "ApplicantInboundTransportStageCost"
    )
    ApplicantInboundTransportStageCost.objects.filter(
        stage_code="MASUK_BERKAS_ASLI"
    ).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("account", "0019_remove_jlh_uang_transport_and_tanggal_proses"),
    ]

    operations = [
        migrations.RunPython(forwards_delete_masuk_berkas_cost_rows, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="applicantinboundtransportstagecost",
            name="stage_code",
            field=models.CharField(
                choices=[
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
                max_length=30,
                verbose_name="kode sub-tahapan",
            ),
        ),
    ]
