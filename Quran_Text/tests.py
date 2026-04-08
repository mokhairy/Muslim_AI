from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse

from Muslim_AI.content_api_clients import AyahRow, QuranAudioPageData, QuranTranslationPageData


def _editions_side_effect(*, edition_format: str, edition_type: str | None = None):
    if edition_format == "text":
        return [
            {"identifier": "en.asad", "language": "en", "englishName": "Muhammad Asad"},
        ]
    if edition_format == "audio":
        return [
            {
                "identifier": "ar.alafasy",
                "englishName": "Alafasy",
                "type": "versebyverse",
            },
        ]
    return []


class QuranTextViewTests(TestCase):
    @patch("Quran_Text.reader.fetch_json")
    @patch("Quran_Text.reader.fetch_alquran_editions")
    @patch("Quran_Text.reader.load_quran_audio_page")
    @patch("Quran_Text.reader.load_quran_translation_page")
    def test_home_renders_combined_reader_rows(
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
            surah_data={
                "number": 1,
                "name": "سُورَةُ ٱلْفَاتِحَةِ",
                "englishName": "Al-Faatiha",
                "englishNameTranslation": "The Opening",
                "numberOfAyahs": 7,
                "revelationType": "Meccan",
            },
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
                        "audioSecondary": ["https://example.com/1-low.mp3"],
                        "juz": 1,
                        "page": 1,
                        "manzil": 1,
                        "hizbQuarter": 1,
                    }
                ],
            }
        )

        response = self.client.get(
            reverse("Quran_Text:home"),
            {
                "surah": 1,
                "translation": "en.asad",
                "reader": "ar.alafasy",
                "mode": "read_listen",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.context["selected_mode"], "read_listen")
        self.assertTrue(response.context["player_available"])
        self.assertEqual(len(response.context["ayah_entries"]), 1)
        self.assertEqual(response.context["ayah_entries"][0]["audio_url"], "https://example.com/1.mp3")
        self.assertContains(response, "Read while listening")
        self.assertContains(response, "In the name of Allah")
        self.assertContains(response, "Sheikh Alafasy")

    @patch("Quran_Text.reader.fetch_json")
    @patch("Quran_Text.reader.fetch_alquran_editions")
    @patch("Quran_Text.reader.load_quran_audio_page")
    @patch("Quran_Text.reader.load_quran_translation_page")
    def test_home_handles_empty_secondary_audio_list(
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
                    "number": 2,
                    "name": "سُورَةُ ٱلْبَقَرَةِ",
                    "englishName": "Al-Baqara",
                    "englishNameTranslation": "The Cow",
                    "numberOfAyahs": 286,
                    "revelationType": "Medinan",
                }
            ]
        }
        load_translation_mock.return_value = QuranTranslationPageData(
            surah_data={"number": 2, "englishName": "Al-Baqara"},
            ayah_rows=[
                AyahRow(
                    number_in_surah=1,
                    arabic_text="الم",
                    translation_text="Alif. Lam. Mim.",
                )
            ],
        )
        load_audio_mock.return_value = QuranAudioPageData(
            surah_data={
                "englishName": "Al-Baqara",
                "edition": {"englishName": "Abdul Samad", "name": "Abdul Samad"},
                "ayahs": [
                    {
                        "numberInSurah": 1,
                        "text": "الم",
                        "audio": "https://example.com/2-1.mp3",
                        "audioSecondary": [],
                    }
                ],
            }
        )

        response = self.client.get(
            reverse("Quran_Text:home"),
            {
                "surah": 2,
                "translation": "en.asad",
                "reader": "ar.alafasy",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.context["ayah_entries"][0]["audio_secondary_url"], "")
