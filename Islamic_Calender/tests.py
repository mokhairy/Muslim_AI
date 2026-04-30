from datetime import date
from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from .calendar_utils import (
    APP_DEFAULT_CALENDAR_MODE,
    TABULAR_MODE,
    UMM_AL_QURA_MODE,
    get_calendar_mode,
    gregorian_to_hijri,
    gregorian_to_hijri_for_mode,
    hijri_to_gregorian,
    hijri_to_gregorian_for_mode,
)
from .models import CalendarDate
from .views import (
    build_ramadan_analysis_context,
    build_ramadan_year_entry,
    ramadan_last_ten_days,
    ramadan_odd_last_ten_days,
)


class CalendarConversionTests(TestCase):
    def test_islamic_epoch_matches_first_supported_day(self):
        hijri_value = gregorian_to_hijri(date(622, 7, 19))
        self.assertEqual((hijri_value.year, hijri_value.month, hijri_value.day), (1, 1, 1))

    def test_tabular_round_trip_conversion(self):
        original = date(2026, 3, 15)
        hijri_value = gregorian_to_hijri(original)
        converted_back = hijri_to_gregorian(
            hijri_value.year,
            hijri_value.month,
            hijri_value.day,
        )
        self.assertEqual(converted_back, original)

    def test_umm_al_qura_round_trip_conversion(self):
        original = date(2026, 3, 15)
        hijri_value = gregorian_to_hijri_for_mode(original, UMM_AL_QURA_MODE)
        converted_back = hijri_to_gregorian_for_mode(
            hijri_value.year,
            hijri_value.month,
            hijri_value.day,
            UMM_AL_QURA_MODE,
        )
        self.assertEqual(converted_back, original)


class CalendarDateModelTests(TestCase):
    def test_get_or_create_for_gregorian_persists_mapping(self):
        record = CalendarDate.get_or_create_for_gregorian(date(2026, 3, 15))
        self.assertEqual(record.gregorian_date.isoformat(), "2026-03-15")
        self.assertEqual(str(record), f"2026-03-15 / {record.hijri_display}")
        self.assertEqual(CalendarDate.objects.count(), 1)


class HomeViewTests(TestCase):
    def test_home_page_renders(self):
        response = self.client.get(reverse("Islamic_Calender:home"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Muslim AI Calendar")
        self.assertContains(response, "Umm al-Qura")
        self.assertContains(response, "Today Gregorian")
        self.assertContains(response, timezone.localdate().isoformat())

    def test_gregorian_lookup_shows_selected_result(self):
        response = self.client.get(
            reverse("Islamic_Calender:home"),
            {"gregorian_date": "2026-03-15"},
        )
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "2026-03-15")
        self.assertContains(response, "AH")

    def test_home_page_can_switch_to_tabular_mode(self):
        response = self.client.get(
            reverse("Islamic_Calender:home"),
            {"calendar_mode": TABULAR_MODE},
        )
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Arithmetic civil Hijri calendar")
        self.assertContains(response, "0622-07-19")

    @patch("Islamic_Calender.views.build_islamic_network_resources_context")
    def test_resources_page_renders(self, build_resources_context_mock):
        build_resources_context_mock.return_value = {
            "network_resources": [
                {
                    "name": "AlQuran.Cloud",
                    "category": "Quran",
                    "tagline": "Quran API",
                    "summary": "Quran data.",
                    "url": "https://alquran.cloud/",
                    "api_url": "https://alquran.cloud/api",
                    "highlights": ["Editions"],
                }
            ],
            "sermon_sources": [],
            "sermon_languages": [],
            "latest_sermons": [
                {
                    "title": "Friday Sermon",
                    "date_label": "2026-03-13",
                    "languages": ["Arabic"],
                    "audio_url": "https://example.com/sermon.mp3",
                    "pdf_url": "",
                    "doc_url": "",
                }
            ],
            "resources_error": "",
            "resources_summary": {
                "services_count": 1,
                "sources_count": 1,
                "languages_count": 1,
                "latest_source_name": "UAE Awqaf",
                "latest_year": 2026,
                "languages_preview": ["Arabic"],
            },
        }
        response = self.client.get(reverse("Islamic_Calender:resources"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Islamic Network Resources")
        self.assertContains(response, "AlQuran.Cloud")
        self.assertContains(response, "Latest Friday Sermons")

    def test_privacy_policy_page_renders(self):
        response = self.client.get(reverse("Islamic_Calender:privacy_policy"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Privacy Policy")
        self.assertContains(response, "MuslimAI is an Islamic companion app")
        self.assertContains(response, "mkhairy@londontrade.ca")


class RamadanAnalysisHelperTests(TestCase):
    def test_ramadan_last_ten_days_are_derived_from_month_length(self):
        self.assertEqual(ramadan_last_ten_days(1447, TABULAR_MODE), list(range(21, 31)))
        self.assertEqual(ramadan_odd_last_ten_days(1447, TABULAR_MODE), [21, 23, 25, 27, 29])

    def test_build_ramadan_year_entry_contains_last_ten_days_and_odd_nights(self):
        ramadan_year = build_ramadan_year_entry(1447, mode=get_calendar_mode(TABULAR_MODE))
        self.assertEqual(ramadan_year["hijri_year"], 1447)
        self.assertEqual(
            [day["hijri_day"] for day in ramadan_year["last_ten_days"]],
            list(range(21, 31)),
        )
        self.assertEqual(
            [night["hijri_day"] for night in ramadan_year["odd_nights"]],
            [21, 23, 25, 27, 29],
        )
        self.assertEqual(
            ramadan_year["gregorian_start"],
            hijri_to_gregorian(1447, 9, 1),
        )

    def test_default_calendar_mode_is_umm_al_qura(self):
        self.assertEqual(APP_DEFAULT_CALENDAR_MODE, UMM_AL_QURA_MODE)
        self.assertEqual(get_calendar_mode().slug, UMM_AL_QURA_MODE)


class RamadanAnalysisViewTests(TestCase):
    def test_ramadan_analysis_page_renders(self):
        response = self.client.get(reverse("Islamic_Calender:ramadan_analysis"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Ramadan Trend Analysis")
        self.assertContains(response, "Umm al-Qura")
        self.assertContains(response, "Today Hijri")
        self.assertContains(response, "21 Ramadan")
        self.assertContains(response, "27 Ramadan")
        self.assertContains(response, "Odd-Night Insight")
        self.assertContains(response, "Friday Balance Across the Last Ten Days")
        self.assertContains(response, "Odd-Night Weekday Heatmap")

    def test_ramadan_analysis_context_has_friday_highlight_for_default_mode(self):
        context = build_ramadan_analysis_context()
        self.assertEqual(context["current_calendar_mode"].slug, UMM_AL_QURA_MODE)
        self.assertGreaterEqual(context["supported_ramadan_start_year"], 1343)
        self.assertLessEqual(context["supported_ramadan_end_year"], 1500)
        self.assertEqual(
            context["last_ten_day_headers"],
            [19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30],
        )
        self.assertEqual(context["odd_day_headers"], [19, 21, 23, 25, 27, 29])
        self.assertEqual(len(context["last_ten_day_trends"]), 12)
        self.assertEqual(len(context["odd_day_trends"]), 6)
        self.assertIsNotNone(context["friday_focus"])
        self.assertEqual(len(context["friday_balance_chart"]["bars"]), 12)
        self.assertEqual(len(context["odd_weekday_heatmap"]["rows"]), 6)

    def test_ramadan_analysis_context_for_tabular_mode(self):
        context = build_ramadan_analysis_context(TABULAR_MODE)
        self.assertEqual(context["current_calendar_mode"].slug, TABULAR_MODE)
        self.assertEqual(context["supported_ramadan_start_year"], 1)
        self.assertGreaterEqual(context["supported_ramadan_end_year"], 1500)
        self.assertEqual(context["last_ten_day_headers"], [21, 22, 23, 24, 25, 26, 27, 28, 29, 30])
