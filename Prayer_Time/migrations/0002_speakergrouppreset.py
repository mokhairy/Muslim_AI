from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("Prayer_Time", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="SpeakerGroupPreset",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("name", models.CharField(max_length=120, unique=True)),
                ("selected_device_ids", models.JSONField(blank=True, default=list)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={"ordering": ("name",)},
        ),
    ]
