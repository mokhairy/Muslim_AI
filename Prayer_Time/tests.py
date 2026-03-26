from __future__ import annotations

from datetime import date, datetime
from unittest.mock import MagicMock, patch
from uuid import UUID
from zoneinfo import ZoneInfo

from django.test import TestCase
from django.urls import reverse

from .automation import process_automation_tick
from .models import PrayerAutomationSetting, SpeakerDevice, SpeakerGroupPreset
from .services import (
    PrayerCalendarDay,
    PrayerCalendarResult,
    PrayerTimesResult,
    PrayerTimesServiceError,
    PrayerTimingEntry,
    QiblaDirectionResult,
    ReverseGeocodeResult,
    _cast_to_chromecast,
    _chromecast_for_device,
)


def sample_prayer_result(
    *,
    prayer_date: date | None = None,
    timings: list[PrayerTimingEntry] | None = None,
) -> PrayerTimesResult:
    selected_date = prayer_date or date(2026, 3, 15)
    return PrayerTimesResult(
        requested_date=selected_date,
        latitude=23.588,
        longitude=58.383,
        timezone="Asia/Muscat",
        hijri_date="26-09-1447",
        readable_date=selected_date.strftime("%d %b %Y"),
        calculation_method="Umm Al-Qura University, Makkah",
        timings=timings
        or [
            PrayerTimingEntry(name="Fajr", time="04:58"),
            PrayerTimingEntry(name="Sunrise", time="06:16"),
            PrayerTimingEntry(name="Dhuhr", time="12:15"),
            PrayerTimingEntry(name="Asr", time="15:39"),
            PrayerTimingEntry(name="Maghrib", time="18:16"),
            PrayerTimingEntry(name="Isha", time="20:16"),
        ],
    )


def sample_qibla_result() -> QiblaDirectionResult:
    return QiblaDirectionResult(latitude=23.588, longitude=58.383, direction=266.4)


def sample_calendar_result() -> PrayerCalendarResult:
    return PrayerCalendarResult(
        year=2026,
        month=3,
        month_label="March 2026",
        timezone="Asia/Muscat",
        calculation_method="Umm Al-Qura University, Makkah",
        days=[
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
            PrayerCalendarDay(
                readable_date="16 Mar 2026",
                gregorian_date="2026-03-16",
                weekday="Monday",
                hijri_date="27-09-1447",
                hijri_month="Ramadan",
                holiday_summary="Lailat-ul-Qadr",
                timings={
                    "Fajr": "04:57",
                    "Sunrise": "06:15",
                    "Dhuhr": "12:15",
                    "Asr": "15:39",
                    "Maghrib": "18:17",
                    "Isha": "20:17",
                },
            ),
        ],
    )


class PrayerTimesViewTests(TestCase):
    def test_page_renders_without_lookup(self):
        response = self.client.get(reverse("Prayer_Time:home"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Prayer Times")
        self.assertContains(response, "Use Current Location")
        self.assertContains(response, "Adhan Streams")
        self.assertContains(response, "Automatic Adhan")

    @patch("Prayer_Time.views.fetch_qibla_direction")
    @patch("Prayer_Time.views.reverse_geocode_location")
    def test_qibla_page_renders_direction(self, reverse_geocode_mock, fetch_qibla_direction_mock):
        fetch_qibla_direction_mock.return_value = sample_qibla_result()
        reverse_geocode_mock.return_value = ReverseGeocodeResult(
            label="Muscat, Oman",
            display_name="Muscat, Muscat Governorate, Oman",
        )
        response = self.client.get(
            reverse("Prayer_Time:qibla"),
            {
                "latitude": "23.588",
                "longitude": "58.383",
                "location_label": "",
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Qibla Direction")
        self.assertContains(response, "266.4")
        self.assertContains(response, "West")
        self.assertContains(response, "Muscat, Oman")
        self.assertContains(response, 'id="qibla-map"')
        self.assertContains(response, "Current location map")

    @patch("Prayer_Time.views.fetch_prayer_calendar")
    @patch("Prayer_Time.views.fetch_qibla_direction")
    @patch("Prayer_Time.views.fetch_prayer_times")
    def test_lookup_renders_prayer_times(
        self,
        fetch_prayer_times_mock,
        fetch_qibla_direction_mock,
        fetch_prayer_calendar_mock,
    ):
        fetch_prayer_times_mock.return_value = sample_prayer_result()
        fetch_qibla_direction_mock.return_value = sample_qibla_result()
        fetch_prayer_calendar_mock.return_value = sample_calendar_result()
        response = self.client.get(
            reverse("Prayer_Time:home"),
            {
                "prayer_date": "2026-03-15",
                "latitude": "23.588",
                "longitude": "58.383",
                "location_label": "Muscat, Oman",
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Muscat, Oman")
        self.assertContains(response, "04:58")
        self.assertContains(response, "Umm Al-Qura University, Makkah")
        self.assertContains(response, "Location Clock")
        self.assertContains(response, "Qibla and Monthly Prayer Calendar")
        self.assertContains(response, "March 2026")

    @patch("Prayer_Time.views.fetch_prayer_calendar")
    @patch("Prayer_Time.views.fetch_qibla_direction")
    @patch("Prayer_Time.views.fetch_prayer_times")
    def test_lookup_builds_next_prayer_dashboard(
        self,
        fetch_prayer_times_mock,
        fetch_qibla_direction_mock,
        fetch_prayer_calendar_mock,
    ):
        def fetch_side_effect(*, prayer_date, latitude, longitude):
            if prayer_date.day == 16:
                return sample_prayer_result(
                    prayer_date=prayer_date,
                    timings=[
                        PrayerTimingEntry(name="Fajr", time="04:59"),
                        PrayerTimingEntry(name="Sunrise", time="06:16"),
                        PrayerTimingEntry(name="Dhuhr", time="12:15"),
                        PrayerTimingEntry(name="Asr", time="15:39"),
                        PrayerTimingEntry(name="Maghrib", time="18:16"),
                        PrayerTimingEntry(name="Isha", time="20:16"),
                    ],
                )
            return sample_prayer_result(prayer_date=prayer_date)

        fetch_prayer_times_mock.side_effect = fetch_side_effect
        fetch_qibla_direction_mock.return_value = sample_qibla_result()
        fetch_prayer_calendar_mock.return_value = sample_calendar_result()
        response = self.client.get(
            reverse("Prayer_Time:home"),
            {
                "prayer_date": "2026-03-15",
                "latitude": "23.588",
                "longitude": "58.383",
                "location_label": "Muscat, Oman",
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Next Prayer")
        self.assertContains(response, "Countdown")
        self.assertContains(response, "next-prayer-schedule")
        self.assertIsNotNone(response.context["next_prayer_dashboard"])
        self.assertEqual(response.context["next_prayer_dashboard"]["schedule"][0]["name"], "Fajr")
        self.assertContains(response, "266.4")

    @patch("Prayer_Time.views.fetch_prayer_calendar")
    @patch("Prayer_Time.views.fetch_qibla_direction")
    @patch("Prayer_Time.views.reverse_geocode_location")
    @patch("Prayer_Time.views.fetch_prayer_times")
    def test_lookup_uses_reverse_geocoded_location_when_label_missing(
        self,
        fetch_prayer_times_mock,
        reverse_geocode_mock,
        fetch_qibla_direction_mock,
        fetch_prayer_calendar_mock,
    ):
        fetch_prayer_times_mock.return_value = sample_prayer_result()
        reverse_geocode_mock.return_value = ReverseGeocodeResult(
            label="Muscat, Muscat Governorate, Oman",
            display_name="Sultan Qaboos Street, Muscat, Muscat Governorate, Oman",
        )
        fetch_qibla_direction_mock.return_value = sample_qibla_result()
        fetch_prayer_calendar_mock.return_value = sample_calendar_result()
        response = self.client.get(
            reverse("Prayer_Time:home"),
            {
                "prayer_date": "2026-03-15",
                "latitude": "23.588",
                "longitude": "58.383",
                "location_label": "",
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Muscat, Muscat Governorate, Oman")
        self.assertContains(response, "Sultan Qaboos Street, Muscat, Muscat Governorate, Oman")

    @patch("Prayer_Time.views.fetch_prayer_calendar")
    @patch("Prayer_Time.views.fetch_qibla_direction")
    @patch("Prayer_Time.views.fetch_prayer_times")
    def test_service_error_is_rendered(
        self,
        fetch_prayer_times_mock,
        fetch_qibla_direction_mock,
        fetch_prayer_calendar_mock,
    ):
        fetch_prayer_times_mock.side_effect = PrayerTimesServiceError("Lookup unavailable.")
        fetch_qibla_direction_mock.return_value = sample_qibla_result()
        fetch_prayer_calendar_mock.return_value = sample_calendar_result()
        response = self.client.get(
            reverse("Prayer_Time:home"),
            {
                "prayer_date": "2026-03-15",
                "latitude": "23.588",
                "longitude": "58.383",
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Lookup unavailable.")

    def test_load_group_without_selection_shows_validation_error(self):
        response = self.client.post(
            reverse("Prayer_Time:home"),
            {
                "action": "load_group",
                "calendar_mode": "umm_al_qura",
                "automation-speaker_group_id": "",
                "automation-latitude": "23.588",
                "automation-longitude": "58.383",
                "automation-selected_stream_url": "https://www.islamcan.com/audio/adhan/azan1.mp3",
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Choose a speaker preset to load.")

    @patch("Prayer_Time.views.fetch_prayer_calendar")
    @patch("Prayer_Time.views.fetch_qibla_direction")
    @patch("Prayer_Time.views.reverse_geocode_location")
    @patch("Prayer_Time.views.fetch_prayer_times")
    def test_save_automation_persists_settings(
        self,
        fetch_prayer_times_mock,
        reverse_geocode_mock,
        fetch_qibla_direction_mock,
        fetch_prayer_calendar_mock,
    ):
        fetch_prayer_times_mock.return_value = sample_prayer_result()
        reverse_geocode_mock.return_value = ReverseGeocodeResult(
            label="Muscat, Muscat Governorate, Oman",
            display_name="Sultan Qaboos Street, Muscat, Muscat Governorate, Oman",
        )
        fetch_qibla_direction_mock.return_value = sample_qibla_result()
        fetch_prayer_calendar_mock.return_value = sample_calendar_result()
        SpeakerDevice.objects.create(
            protocol="cast",
            device_id="cast:abc",
            name="Living Room Speaker",
            host="192.168.1.10",
            is_available=True,
        )
        response = self.client.post(
            reverse("Prayer_Time:home"),
            {
                "action": "save_automation",
                "calendar_mode": "umm_al_qura",
                "automation-enabled": "on",
                "automation-location_label": "Home",
                "automation-latitude": "23.588",
                "automation-longitude": "58.383",
                "automation-selected_stream_url": "https://www.islamcan.com/audio/adhan/azan1.mp3",
                "automation-enabled_prayers": ["Fajr", "Maghrib"],
                "automation-selected_device_ids": ["cast:abc"],
            },
        )
        self.assertEqual(response.status_code, 200)
        settings = PrayerAutomationSetting.singleton()
        self.assertTrue(settings.enabled)
        self.assertEqual(settings.location_label, "Home")
        self.assertEqual(settings.selected_device_ids, ["cast:abc"])
        self.assertEqual(settings.enabled_prayers, ["Fajr", "Maghrib"])
        self.assertContains(response, "Automatic adhan settings saved.")

    @patch("Prayer_Time.views.fetch_prayer_calendar")
    @patch("Prayer_Time.views.fetch_qibla_direction")
    @patch("Prayer_Time.views.reverse_geocode_location")
    @patch("Prayer_Time.views.fetch_prayer_times")
    def test_save_automation_uses_reverse_geocoded_location_when_label_missing(
        self,
        fetch_prayer_times_mock,
        reverse_geocode_mock,
        fetch_qibla_direction_mock,
        fetch_prayer_calendar_mock,
    ):
        fetch_prayer_times_mock.return_value = sample_prayer_result()
        reverse_geocode_mock.return_value = ReverseGeocodeResult(
            label="Muscat, Muscat Governorate, Oman",
            display_name="Sultan Qaboos Street, Muscat, Muscat Governorate, Oman",
        )
        fetch_qibla_direction_mock.return_value = sample_qibla_result()
        fetch_prayer_calendar_mock.return_value = sample_calendar_result()
        SpeakerDevice.objects.create(
            protocol="cast",
            device_id="cast:abc",
            name="Living Room Speaker",
            host="192.168.1.10",
            is_available=True,
        )
        response = self.client.post(
            reverse("Prayer_Time:home"),
            {
                "action": "save_automation",
                "calendar_mode": "umm_al_qura",
                "automation-enabled": "on",
                "automation-location_label": "",
                "automation-latitude": "23.588",
                "automation-longitude": "58.383",
                "automation-selected_stream_url": "https://www.islamcan.com/audio/adhan/azan1.mp3",
                "automation-enabled_prayers": ["Fajr"],
                "automation-selected_device_ids": ["cast:abc"],
            },
        )
        self.assertEqual(response.status_code, 200)
        settings = PrayerAutomationSetting.singleton()
        self.assertEqual(settings.location_label, "Muscat, Muscat Governorate, Oman")
        self.assertContains(response, "Muscat, Muscat Governorate, Oman")

    @patch("Prayer_Time.views.fetch_prayer_calendar")
    @patch("Prayer_Time.views.fetch_qibla_direction")
    @patch("Prayer_Time.views.reverse_geocode_location")
    @patch("Prayer_Time.views.fetch_prayer_times")
    def test_save_automation_persists_per_prayer_custom_streams(
        self,
        fetch_prayer_times_mock,
        reverse_geocode_mock,
        fetch_qibla_direction_mock,
        fetch_prayer_calendar_mock,
    ):
        fetch_prayer_times_mock.return_value = sample_prayer_result()
        reverse_geocode_mock.return_value = ReverseGeocodeResult(
            label="Muscat, Muscat Governorate, Oman",
            display_name="Sultan Qaboos Street, Muscat, Muscat Governorate, Oman",
        )
        fetch_qibla_direction_mock.return_value = sample_qibla_result()
        fetch_prayer_calendar_mock.return_value = sample_calendar_result()
        SpeakerDevice.objects.create(
            protocol="cast",
            device_id="cast:abc",
            name="Living Room Speaker",
            host="192.168.1.10",
            is_available=True,
        )
        response = self.client.post(
            reverse("Prayer_Time:home"),
            {
                "action": "save_automation",
                "calendar_mode": "umm_al_qura",
                "automation-enabled": "on",
                "automation-location_label": "Home",
                "automation-latitude": "23.588",
                "automation-longitude": "58.383",
                "automation-selected_stream_url": "https://www.islamcan.com/audio/adhan/azan1.mp3",
                "automation-stream_for_fajr": "https://www.islamcan.com/audio/adhan/azan2.mp3",
                "automation-stream_for_maghrib": "https://www.islamcan.com/audio/adhan/azan3.mp3",
                "automation-enabled_prayers": ["Fajr", "Maghrib"],
                "automation-selected_device_ids": ["cast:abc"],
            },
        )
        self.assertEqual(response.status_code, 200)
        settings = PrayerAutomationSetting.singleton()
        self.assertEqual(
            settings.prayer_stream_urls,
            {
                "Fajr": "https://www.islamcan.com/audio/adhan/azan2.mp3",
                "Maghrib": "https://www.islamcan.com/audio/adhan/azan3.mp3",
            },
        )
        self.assertContains(response, "Fajr: Makkah Adhan 2")
        self.assertContains(response, "Maghrib: Makkah Adhan 3")

    @patch("Prayer_Time.views.broadcast_stream_to_devices")
    def test_test_broadcast_reports_results(self, broadcast_mock):
        SpeakerDevice.objects.create(
            protocol="cast",
            device_id="cast:abc",
            name="Living Room Speaker",
            host="192.168.1.10",
            is_available=True,
        )
        broadcast_mock.return_value = {
            "successes": ["Living Room Speaker"],
            "errors": [],
        }
        response = self.client.post(
            reverse("Prayer_Time:home"),
            {
                "action": "test_broadcast",
                "calendar_mode": "umm_al_qura",
                "automation-location_label": "Home",
                "automation-latitude": "23.588",
                "automation-longitude": "58.383",
                "automation-selected_stream_url": "https://www.islamcan.com/audio/adhan/azan1.mp3",
                "automation-enabled_prayers": ["Fajr"],
                "automation-selected_device_ids": ["cast:abc"],
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Test broadcast sent to 1 device(s).")
        self.assertContains(response, "Succeeded: Living Room Speaker")


class BroadcastServiceTests(TestCase):
    @patch("Prayer_Time.services.quick_play")
    @patch("Prayer_Time.services._chromecast_for_device")
    def test_cast_to_chromecast_uses_buffered_mpeg_payload(
        self,
        chromecast_for_device_mock,
        quick_play_mock,
    ):
        device = SpeakerDevice(
            protocol="cast",
            device_id="cast:ecfd964f-2013-42b6-b6c9-4b480e29dabb",
            name="All Home Speakers",
        )
        cast = MagicMock()
        browser = MagicMock()
        chromecast_for_device_mock.return_value = (cast, browser)

        _cast_to_chromecast(device, "https://www.islamcan.com/audio/adhan/azan1.mp3")

        cast.wait.assert_called_once_with(timeout=10)
        quick_play_mock.assert_called_once_with(
            cast,
            "default_media_receiver",
            {
                "media_id": "https://www.islamcan.com/audio/adhan/azan1.mp3",
                "media_type": "audio/mpeg",
                "stream_type": "BUFFERED",
            },
            timeout=30,
        )
        cast.disconnect.assert_called_once_with()
        browser.stop_discovery.assert_called_once_with()

    @patch("Prayer_Time.services.pychromecast.get_chromecasts")
    @patch("Prayer_Time.services.pychromecast.get_listed_chromecasts")
    def test_chromecast_group_fallback_uses_known_host_discovery(
        self,
        listed_mock,
        get_chromecasts_mock,
    ):
        class Browser:
            def __init__(self):
                self.stopped = False

            def stop_discovery(self):
                self.stopped = True

        device = SpeakerDevice.objects.create(
            protocol="cast",
            device_id="cast:ecfd964f-2013-42b6-b6c9-4b480e29dabb",
            name="All Home Speakers",
            host="192.168.5.46",
            port=32159,
            model_name="Google Cast Group",
            is_available=True,
            is_group=True,
        )
        listed_browser = Browser()
        host_browser = Browser()
        sentinel_cast = type(
            "Cast",
            (),
            {"uuid": UUID(device.device_id.removeprefix("cast:"))},
        )()
        listed_mock.return_value = ([], listed_browser)
        get_chromecasts_mock.return_value = ([sentinel_cast], host_browser)

        result, browser = _chromecast_for_device(device)

        self.assertIs(result, sentinel_cast)
        self.assertIs(browser, host_browser)
        self.assertTrue(listed_browser.stopped)
        get_chromecasts_mock.assert_called_once_with(
            tries=1,
            retry_wait=0.5,
            timeout=5,
            known_hosts=["192.168.5.46"],
        )

    @patch("Prayer_Time.services.pychromecast.get_chromecast_from_host")
    @patch("Prayer_Time.services.pychromecast.get_chromecasts")
    @patch("Prayer_Time.services.pychromecast.get_listed_chromecasts")
    def test_chromecast_fallback_uses_supported_host_api(
        self,
        listed_mock,
        get_chromecasts_mock,
        from_host_mock,
    ):
        class Browser:
            def stop_discovery(self):
                return None

        device = SpeakerDevice.objects.create(
            protocol="cast",
            device_id="cast:ecfd964f-2013-42b6-b6c9-4b480e29dabb",
            name="All Home Speakers",
            host="192.168.5.46",
            port=32159,
            model_name="Google Cast Group",
            is_available=True,
        )
        listed_mock.return_value = ([], Browser())
        get_chromecasts_mock.return_value = ([], Browser())
        sentinel_cast = object()
        from_host_mock.return_value = sentinel_cast

        result, browser = _chromecast_for_device(device)

        self.assertIs(result, sentinel_cast)
        self.assertIsNone(browser)
        from_host_mock.assert_called_once_with(
            (
                "192.168.5.46",
                32159,
                UUID(device.device_id.removeprefix("cast:")),
                "Google Cast Group",
                "All Home Speakers",
            )
        )

    def test_save_group_persists_speaker_preset(self):
        SpeakerDevice.objects.create(
            protocol="cast",
            device_id="cast:living-room",
            name="Living Room Speaker",
            host="192.168.1.10",
            is_available=True,
        )
        SpeakerDevice.objects.create(
            protocol="dlna",
            device_id="dlna:tv",
            name="Family Room TV",
            host="192.168.1.22",
            is_available=True,
        )
        response = self.client.post(
            reverse("Prayer_Time:home"),
            {
                "action": "save_group",
                "calendar_mode": "umm_al_qura",
                "group-name": "Downstairs",
                "group-selected_device_ids": ["cast:living-room", "dlna:tv"],
            },
        )
        self.assertEqual(response.status_code, 200)
        group = SpeakerGroupPreset.objects.get(name="Downstairs")
        self.assertEqual(group.selected_device_ids, ["cast:living-room", "dlna:tv"])
        self.assertContains(response, "Speaker preset saved.")

    def test_load_group_prefills_automation_targets(self):
        living_room = SpeakerDevice.objects.create(
            protocol="cast",
            device_id="cast:living-room",
            name="Living Room Speaker",
            host="192.168.1.10",
            is_available=True,
        )
        tv = SpeakerDevice.objects.create(
            protocol="dlna",
            device_id="dlna:tv",
            name="Family Room TV",
            host="192.168.1.22",
            is_available=True,
        )
        preset = SpeakerGroupPreset.objects.create(
            name="Downstairs",
            selected_device_ids=[living_room.device_id, tv.device_id],
        )
        response = self.client.post(
            reverse("Prayer_Time:home"),
            {
                "action": "load_group",
                "calendar_mode": "umm_al_qura",
                "automation-speaker_group_id": str(preset.pk),
                "automation-location_label": "Home",
                "automation-latitude": "23.588",
                "automation-longitude": "58.383",
                "automation-selected_stream_url": "https://www.islamcan.com/audio/adhan/azan1.mp3",
                "automation-enabled_prayers": ["Fajr"],
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Loaded preset: Downstairs.")
        self.assertEqual(
            response.context["automation_form"].initial["selected_device_ids"],
            [living_room.device_id, tv.device_id],
        )
        self.assertEqual(len(response.context["selected_devices"]), 2)


class PrayerAutomationTests(TestCase):
    @patch("Prayer_Time.automation.broadcast_stream_to_devices")
    @patch("Prayer_Time.automation.datetime")
    def test_process_automation_tick_uses_custom_stream_for_prayer(
        self,
        datetime_mock,
        broadcast_mock,
    ):
        fixed_now = datetime(2026, 3, 15, 4, 58, tzinfo=ZoneInfo("Asia/Muscat"))
        datetime_mock.now.return_value = fixed_now
        settings = PrayerAutomationSetting.singleton()
        settings.enabled = True
        settings.latitude = 23.588
        settings.longitude = 58.383
        settings.timezone_name = "Asia/Muscat"
        settings.selected_stream_url = "https://www.islamcan.com/audio/adhan/azan1.mp3"
        settings.prayer_stream_urls = {
            "Fajr": "https://www.islamcan.com/audio/adhan/azan2.mp3",
        }
        settings.selected_device_ids = ["cast:abc"]
        settings.enabled_prayers = ["Fajr"]
        settings.cached_prayer_date = fixed_now.date()
        settings.cached_timings = {"Fajr": "04:58"}
        settings.save()
        broadcast_mock.return_value = {"successes": ["Living Room Speaker"], "errors": []}

        process_automation_tick()

        broadcast_mock.assert_called_once_with(
            "https://www.islamcan.com/audio/adhan/azan2.mp3",
            ["cast:abc"],
        )
