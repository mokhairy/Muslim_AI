from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="PrayerAutomationSetting",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("enabled", models.BooleanField(default=False)),
                ("location_label", models.CharField(blank=True, max_length=120)),
                ("latitude", models.FloatField(blank=True, null=True)),
                ("longitude", models.FloatField(blank=True, null=True)),
                ("timezone_name", models.CharField(default="Asia/Muscat", max_length=64)),
                ("selected_stream_url", models.URLField(blank=True)),
                ("selected_stream_name", models.CharField(blank=True, max_length=120)),
                ("selected_device_ids", models.JSONField(blank=True, default=list)),
                ("enabled_prayers", models.JSONField(blank=True, default=list)),
                ("last_triggered", models.JSONField(blank=True, default=dict)),
                ("cached_prayer_date", models.DateField(blank=True, null=True)),
                ("cached_timings", models.JSONField(blank=True, default=dict)),
                ("calculation_method", models.CharField(blank=True, max_length=255)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
        ),
        migrations.CreateModel(
            name="SpeakerDevice",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("protocol", models.CharField(max_length=24)),
                ("device_id", models.CharField(max_length=255, unique=True)),
                ("name", models.CharField(max_length=255)),
                ("host", models.GenericIPAddressField(blank=True, null=True)),
                ("port", models.PositiveIntegerField(blank=True, null=True)),
                ("device_type", models.CharField(blank=True, max_length=255)),
                ("model_name", models.CharField(blank=True, max_length=255)),
                ("location_url", models.URLField(blank=True)),
                ("is_group", models.BooleanField(default=False)),
                ("is_available", models.BooleanField(default=True)),
                ("last_seen", models.DateTimeField(auto_now=True)),
            ],
            options={"ordering": ("name", "protocol")},
        ),
    ]
