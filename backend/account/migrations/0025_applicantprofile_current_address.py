import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("account", "0024_remove_applicantprofile_photo"),
        (
            "regions",
            "0002_rename_regions_district_regency_idx_regions_dis_regency_0a3d69_idx_and_more",
        ),
    ]

    operations = [
        migrations.AddField(
            model_name="applicantprofile",
            name="current_address",
            field=models.TextField(
                blank=True,
                help_text="Alamat tempat tinggal saat ini untuk CV. Tidak disalin dari alamat KTP.",
                verbose_name="alamat tempat tinggal sekarang",
            ),
        ),
        migrations.AddField(
            model_name="applicantprofile",
            name="current_postal_code",
            field=models.CharField(
                blank=True,
                help_text="Kode pos alamat tempat tinggal saat ini.",
                max_length=20,
                verbose_name="kode pos tempat tinggal sekarang",
            ),
        ),
        migrations.AddField(
            model_name="applicantprofile",
            name="current_province",
            field=models.ForeignKey(
                blank=True,
                help_text="Provinsi alamat tempat tinggal saat ini.",
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="applicant_profiles_current",
                to="regions.province",
                verbose_name="provinsi (tempat tinggal sekarang)",
            ),
        ),
        migrations.AddField(
            model_name="applicantprofile",
            name="current_district",
            field=models.ForeignKey(
                blank=True,
                help_text="Kota atau Kabupaten alamat tempat tinggal saat ini.",
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="applicant_profiles_current_district",
                to="regions.regency",
                verbose_name="kota / kabupaten (tempat tinggal sekarang)",
            ),
        ),
        migrations.AddField(
            model_name="applicantprofile",
            name="current_village",
            field=models.ForeignKey(
                blank=True,
                help_text="Kelurahan/desa alamat tempat tinggal saat ini.",
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="applicant_profiles_current_address",
                to="regions.village",
                verbose_name="kelurahan / desa (tempat tinggal sekarang)",
            ),
        ),
    ]
