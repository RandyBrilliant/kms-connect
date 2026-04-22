from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ("account", "0010_alter_notificationpreference_email_account_updates_and_more"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="applicantprofile",
            name="zero_cost_understood",
        ),
    ]
