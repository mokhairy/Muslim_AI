from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse

from Muslim_AI.content_api_clients import AyahRow, QuranAudioPageData, QuranTranslationPageData
from Quran_Text.tests import _editions_side_effect


class QuranAudioViewTests(TestCase):
    @patch("Quran_Text.reader.fetch_json")
    @patch("Quran_Text.reader.fetch_alquran_editions")
    @patch("Quran_Text.reader.load_quran_audio_page")
    @patch("Quran_Text.reader.load_quran_translation_page")
    def test_home_defaults_to_listen_mode(
        self,
        load_translation_mock,
        load_audio_mock,
        fetch_editions_mock,
        fetch_json_mock,
    ):
        fetch_editions_mock.side_effect = _editions_side_effect
        fetch_json_mock.return_value = {
            "data": [
                {
                    "number": 1,
                    "name": "سُورَةُ ٱلْفَاتِحَةِ",
                    "englishName": "Al-Faatiha",
                    "englishNameTranslation": "The Opening",
                    "numberOfAyahs": 7,
                    "revelationType": "Meccan",
                }
            ]
        }
        load_translation_mock.return_value = QuranTranslationPageData(
            surah_data={"englishName": "Al-Faatiha"},
            ayah_rows=[
                AyahRow(
                    number_in_surah=1,
                    arabic_text="بِسْمِ اللَّهِ",
                    translation_text="In the name of Allah",
                )
            ],
        )
        load_audio_mock.return_value = QuranAudioPageData(
            surah_data={
                "englishName": "Al-Faatiha",
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
        self.assertEqual(response.context["selected_mode"], "listen")
        self.assertEqual(response.context["selected_audio_edition"], "ar.alafasy")
        self.assertEqual(response.context["surah_number"], 1)
        self.assertContains(response, "Listen only")
        self.assertContains(response, "Play ayah")
