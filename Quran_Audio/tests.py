from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse

from Muslim_AI.content_api_clients import QuranAudioPageData


class QuranAudioViewTests(TestCase):
    @patch("Quran_Audio.views.load_quran_audio_page")
    @patch("Quran_Audio.views.fetch_alquran_editions")
    def test_home_renders_selected_audio_edition(self, fetch_editions_mock, load_page_mock):
        fetch_editions_mock.return_value = [
            {"identifier": "ar.alafasy", "englishName": "Alafasy"},
        ]
        load_page_mock.return_value = QuranAudioPageData(
            surah_data={
                "englishName": "Al-Fatihah",
                "numberOfAyahs": 1,
                "edition": {"englishName": "Alafasy", "name": "Alafasy"},
                "ayahs": [
                    {
                        "numberInSurah": 1,
                        "text": "بِسْمِ اللَّهِ",
                        "audio": "https://example.com/1.mp3",
                    }
                ],
            }
        )

        response = self.client.get(
            reverse("Quran_Audio:home"),
            {"chapter": 1, "edition": "ar.alafasy"},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.context["surah_data"]["englishName"], "Al-Fatihah")
        self.assertContains(response, "Al-Fatihah")
