from __future__ import annotations

from datetime import date
from unittest.mock import patch

from django.test import SimpleTestCase

from Prayer_Time.services import (
    PrayerCalendarDay,
    PrayerTimingEntry,
    clear_prayer_service_caches,
    fetch_prayer_calendar,
    fetch_prayer_times,
)


class PrayerServiceIntegrationTests(SimpleTestCase):
    def tearDown(self) -> None:
        clear_prayer_service_caches()
        super().tearDown()

    @patch("Prayer_Time.services._load_json_uncached")
    def test_fetch_prayer_times_shapes_entries_and_uses_cache(self, load_json_mock):
        load_json_mock.return_value = {
            "code": 200,
            "data": {
                "timings": {
                    "Fajr": "04:58 (+04)",
                    "Sunrise": "06:16 (+04)",
                    "Dhuhr": "12:15 (+04)",
                    "Asr": "15:39 (+04)",
                    "Maghrib": "18:16 (+04)",
                    "Isha": "20:16 (+04)",
                },
                "meta": {
                    "timezone": "Asia/Muscat",
                    "method": {"name": "Umm Al-Qura University, Makkah"},
                },
                "date": {
                    "hijri": {"date": "26-09-1447"},
                    "readable": "15 Mar 2026",
                },
            },
        }

        first = fetch_prayer_times(
            prayer_date=date(2026, 3, 15),
            latitude=23.588,
            longitude=58.383,
        )
        second = fetch_prayer_times(
            prayer_date=date(2026, 3, 15),
            latitude=23.588,
            longitude=58.383,
        )

        self.assertEqual(load_json_mock.call_count, 1)
        self.assertEqual(first.timings[0], PrayerTimingEntry(name="Fajr", time="04:58"))
        self.assertEqual(second.timings[0].time, "04:58")

    @patch("Prayer_Time.services._load_json_uncached")
    def test_fetch_prayer_calendar_shapes_days(self, load_json_mock):
        load_json_mock.return_value = {
            "code": 200,
            "data": [
                {
                    "timings": {
                        "Fajr": "04:58 (+04)",
                        "Sunrise": "06:16 (+04)",
                        "Dhuhr": "12:15 (+04)",
                        "Asr": "15:39 (+04)",
                        "Maghrib": "18:16 (+04)",
                        "Isha": "20:16 (+04)",
                    },
                    "date": {
                        "readable": "15 Mar 2026",
                        "gregorian": {
                            "date": "2026-03-15",
                            "weekday": {"en": "Sunday"},
                            "month": {"en": "March"},
                        },
                        "hijri": {
                            "date": "26-09-1447",
                            "month": {"en": "Ramadan"},
                            "holidays": [],
                        },
                    },
                    "meta": {
                        "timezone": "Asia/Muscat",
                        "method": {"name": "Umm Al-Qura University, Makkah"},
                    },
                }
            ],
        }

        result = fetch_prayer_calendar(year=2026, month=3, latitude=23.588, longitude=58.383)

        self.assertEqual(result.month_label, "March 2026")
        self.assertEqual(
            result.days[0],
            PrayerCalendarDay(
                readable_date="15 Mar 2026",
                gregorian_date="2026-03-15",
                weekday="Sunday",
                hijri_date="26-09-1447",
                hijri_month="Ramadan",
                holiday_summary="",
                timings={
                    "Fajr": "04:58",
                    "Sunrise": "06:16",
                    "Dhuhr": "12:15",
                    "Asr": "15:39",
                    "Maghrib": "18:16",
                    "Isha": "20:16",
                },
            ),
        )
