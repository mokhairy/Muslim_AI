from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse

from Muslim_AI.content_api_clients import AyahRow, QuranTranslationPageData


class QuranTextViewTests(TestCase):
    @patch("Quran_Text.views.load_quran_translation_page")
    @patch("Quran_Text.views.fetch_alquran_editions")
    def test_home_renders_translation_rows(self, fetch_editions_mock, load_page_mock):
        fetch_editions_mock.return_value = [
            {"identifier": "en.asad", "language": "en", "englishName": "Muhammad Asad"},
        ]
        load_page_mock.return_value = QuranTranslationPageData(
            surah_data={"englishName": "Al-Fatihah"},
            ayah_rows=[
                AyahRow(
                    number_in_surah=1,
                    arabic_text="بِسْمِ اللَّهِ",
                    translation_text="In the name of Allah",
                )
            ],
        )

        response = self.client.get(reverse("Quran_Text:home"), {"surah": 1, "edition": "en.asad"})

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.context["ayah_rows"]), 1)
        self.assertContains(response, "In the name of Allah")
