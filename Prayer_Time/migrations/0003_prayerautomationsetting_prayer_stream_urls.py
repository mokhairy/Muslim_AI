from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("Prayer_Time", "0002_speakergrouppreset"),
    ]

    operations = [
        migrations.AddField(
            model_name="prayerautomationsetting",
            name="prayer_stream_urls",
            field=models.JSONField(blank=True, default=dict),
        ),
    ]
