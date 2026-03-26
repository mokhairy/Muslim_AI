from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse

from Muslim_AI.content_api_clients import TafsirItem, TafsirPageData


class TafsirViewTests(TestCase):
    @patch("Tafsir.views.load_tafsir_page")
    @patch("Tafsir.views.fetch_alquran_editions")
    def test_home_renders_tafsir_rows(self, fetch_editions_mock, load_page_mock):
        fetch_editions_mock.return_value = [
            {"identifier": "ar.muyassar", "englishName": "Muyassar"},
        ]
        load_page_mock.return_value = TafsirPageData(
            tafsir_items=[
                TafsirItem(
                    numberInSurah=1,
                    arabic_text="بِسْمِ اللَّهِ",
                    tafsir_text="تفسير ميسر",
                )
            ]
        )

        response = self.client.get(
            reverse("Tafsir:home"),
            {"surah": 1, "translation": "ar.muyassar"},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.context["tafsir_items"]), 1)
        self.assertContains(response, "تفسير ميسر")
