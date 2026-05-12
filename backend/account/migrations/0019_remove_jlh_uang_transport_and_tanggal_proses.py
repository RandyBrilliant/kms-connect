# Generated manually — drop stored tanggal proses (derived from lamaran) and
# stored jlh uang transport (sum of per-stage amounts).

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ("account", "0018_inbound_transport_stage_costs"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="applicantinboundtransportstagecost",
            name="tanggal_proses",
        ),
        migrations.RemoveField(
            model_name="applicantprofile",
            name="jlh_uang_transport",
        ),
    ]
