from __future__ import annotations

from unittest.mock import patch

from django.test import SimpleTestCase

from Muslim_AI.content_api_clients import (
    AyahRow,
    HadithLibraryMetadata,
    RadioStation,
    clear_content_api_caches,
    load_hadith_library_page,
    load_quran_translation_page,
    load_radio_page,
)


class ContentApiClientTests(SimpleTestCase):
    def tearDown(self) -> None:
        clear_content_api_caches()
        super().tearDown()

    @patch("Muslim_AI.content_api_clients.fetch_json")
    def test_quran_translation_page_shapes_rows_and_uses_cache(self, fetch_json_mock):
        fetch_json_mock.return_value = {
            "data": [
                {
                    "ayahs": [
                        {"numberInSurah": 1, "text": "بِسْمِ اللَّهِ"},
                    ]
                },
                {
                    "englishName": "Al-Fatihah",
                    "ayahs": [
                        {"numberInSurah": 1, "text": "In the name of Allah"},
                    ],
                },
            ]
        }

        first = load_quran_translation_page(surah_number=1, selected_edition="en.asad")
        second = load_quran_translation_page(surah_number=1, selected_edition="en.asad")

        self.assertEqual(fetch_json_mock.call_count, 1)
        self.assertEqual(first.surah_data["englishName"], "Al-Fatihah")
        self.assertEqual(
            first.ayah_rows,
            [
                AyahRow(
                    number_in_surah=1,
                    arabic_text="بِسْمِ اللَّهِ",
                    translation_text="In the name of Allah",
                )
            ],
        )
        self.assertEqual(second.ayah_rows, first.ayah_rows)

    @patch("Muslim_AI.content_api_clients.fetch_json")
    def test_hadith_library_page_shapes_metadata(self, fetch_json_mock):
        fetch_json_mock.side_effect = [
            {
                "abudawud": {
                    "collection": [
                        {
                            "name": "eng-abudawud",
                            "language": "English",
                            "book": "Abu Dawud",
                            "linkmin": "https://example.com/abudawud.json",
                        }
                    ]
                }
            },
            {
                "metadata": {"name": "Sunan Abi Dawud"},
                "hadiths": [{"hadithnumber": 1, "text": "Sample hadith"}],
            },
        ]

        result = load_hadith_library_page(
            selected_edition="eng-abudawud",
            hadith_limit=5,
            load_selected_edition=True,
        )

        self.assertEqual(result.selected_edition, "eng-abudawud")
        self.assertEqual(
            result.selected_metadata,
            HadithLibraryMetadata(
                name="eng-abudawud",
                label="English - Abu Dawud",
                link="https://example.com/abudawud.json",
                source_name="Sunan Abi Dawud",
            ),
        )
        self.assertEqual(len(result.hadith_items), 1)

    @patch("Muslim_AI.content_api_clients.fetch_json")
    def test_radio_page_falls_back_to_first_station(self, fetch_json_mock):
        fetch_json_mock.return_value = {
            "radios": [
                {"id": 1, "name": "Makkah Radio", "url": "https://example.com/1"},
                {"id": 2, "name": "Madinah Radio", "url": "https://example.com/2"},
            ]
        }

        result = load_radio_page(selected_station_id=999)

        self.assertEqual(
            result.selected_station, RadioStation(1, "Makkah Radio", "https://example.com/1")
        )
        self.assertEqual(result.selected_station_id, 1)
