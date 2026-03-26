from __future__ import annotations

from django.db import models


class SpeakerDevice(models.Model):
    protocol = models.CharField(max_length=24)
    device_id = models.CharField(max_length=255, unique=True)
    name = models.CharField(max_length=255)
    host = models.GenericIPAddressField(null=True, blank=True)
    port = models.PositiveIntegerField(null=True, blank=True)
    device_type = models.CharField(max_length=255, blank=True)
    model_name = models.CharField(max_length=255, blank=True)
    location_url = models.URLField(blank=True)
    is_group = models.BooleanField(default=False)
    is_available = models.BooleanField(default=True)
    last_seen = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("name", "protocol")

    def __str__(self) -> str:
        return f"{self.name} ({self.protocol})"


class PrayerAutomationSetting(models.Model):
    enabled = models.BooleanField(default=False)
    location_label = models.CharField(max_length=120, blank=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    timezone_name = models.CharField(max_length=64, default="Asia/Muscat")
    selected_stream_url = models.URLField(blank=True)
    selected_stream_name = models.CharField(max_length=120, blank=True)
    prayer_stream_urls = models.JSONField(default=dict, blank=True)
    selected_device_ids = models.JSONField(default=list, blank=True)
    enabled_prayers = models.JSONField(default=list, blank=True)
    last_triggered = models.JSONField(default=dict, blank=True)
    cached_prayer_date = models.DateField(null=True, blank=True)
    cached_timings = models.JSONField(default=dict, blank=True)
    calculation_method = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    @classmethod
    def singleton(cls) -> PrayerAutomationSetting:
        instance = cls.objects.order_by("pk").first()
        if instance:
            return instance
        return cls.objects.create()


class SpeakerGroupPreset(models.Model):
    name = models.CharField(max_length=120, unique=True)
    selected_device_ids = models.JSONField(default=list, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("name",)

    def __str__(self) -> str:
        return self.name
