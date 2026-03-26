from __future__ import annotations

import logging
import time
from datetime import datetime
from zoneinfo import ZoneInfo

from django.db import OperationalError, ProgrammingError, close_old_connections

from .models import PrayerAutomationSetting
from .services import broadcast_stream_to_devices, fetch_prayer_times, timings_to_map

logger = logging.getLogger(__name__)


def _stream_url_for_prayer(settings: PrayerAutomationSetting, prayer_name: str) -> str:
    return (settings.prayer_stream_urls or {}).get(prayer_name) or settings.selected_stream_url


def process_automation_tick() -> None:
    try:
        settings = PrayerAutomationSetting.objects.order_by("pk").first()
    except (OperationalError, ProgrammingError):
        return
    if not settings or not settings.enabled:
        return
    if settings.latitude is None or settings.longitude is None:
        return
    if (
        not settings.selected_stream_url and not settings.prayer_stream_urls
    ) or not settings.selected_device_ids:
        return
    if not settings.enabled_prayers:
        return

    timezone_name = settings.timezone_name or "Asia/Muscat"
    zone = ZoneInfo(timezone_name)
    now_local = datetime.now(zone)
    today = now_local.date()
    refresh_cache = settings.cached_prayer_date != today or not settings.cached_timings

    if refresh_cache:
        prayer_result = fetch_prayer_times(
            prayer_date=today,
            latitude=settings.latitude,
            longitude=settings.longitude,
        )
        settings.cached_prayer_date = today
        settings.cached_timings = timings_to_map(prayer_result)
        settings.timezone_name = prayer_result.timezone
        settings.calculation_method = prayer_result.calculation_method
        settings.save(
            update_fields=[
                "cached_prayer_date",
                "cached_timings",
                "timezone_name",
                "calculation_method",
                "updated_at",
            ]
        )
        zone = ZoneInfo(settings.timezone_name)
        now_local = datetime.now(zone)
        today = now_local.date()

    current_time = now_local.strftime("%H:%M")
    last_triggered = dict(settings.last_triggered or {})

    for prayer_name in settings.enabled_prayers:
        prayer_time = settings.cached_timings.get(prayer_name)
        if prayer_time != current_time:
            continue
        if last_triggered.get(prayer_name) == today.isoformat():
            continue
        stream_url = _stream_url_for_prayer(settings, prayer_name)
        if not stream_url:
            continue

        results = broadcast_stream_to_devices(stream_url, settings.selected_device_ids)
        if results["successes"]:
            last_triggered[prayer_name] = today.isoformat()
            settings.last_triggered = last_triggered
            settings.save(update_fields=["last_triggered", "updated_at"])
        if results["errors"]:
            logger.warning("Prayer broadcast errors: %s", "; ".join(results["errors"]))


def run_automation_loop(*, interval_seconds: int = 20) -> None:
    if interval_seconds < 1:
        raise ValueError("interval_seconds must be at least 1.")

    while True:
        close_old_connections()
        try:
            process_automation_tick()
        except Exception:  # pragma: no cover
            logger.exception("Prayer automation tick failed.")
        time.sleep(interval_seconds)
