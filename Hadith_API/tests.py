from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse

from Muslim_AI.content_api_clients import HadithApiPageData


class HadithApiViewTests(TestCase):
    @patch("Hadith_API.views.load_hadith_api_page")
    def test_home_renders_hadith_items_and_preview(self, load_page_mock):
        load_page_mock.return_value = HadithApiPageData(
            hadith_items=[{"arab": "النص العربي", "id": "1"}],
            payload_preview='{"meta": {"page": 1}}',
        )

        response = self.client.get(reverse("Hadith_API:home"), {"collection": "abu-dawud"})

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.context["hadith_items"]), 1)
        self.assertIn('"meta"', response.context["payload_preview"])
