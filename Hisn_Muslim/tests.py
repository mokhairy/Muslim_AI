from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse

from Muslim_AI.content_api_clients import HisnMuslimPageData


class HisnMuslimViewTests(TestCase):
    @patch("Hisn_Muslim.views.load_hisn_muslim_page")
    def test_home_renders_collection_entries(self, load_page_mock):
        load_page_mock.return_value = HisnMuslimPageData(
            category_name="Morning Adhkar",
            entries=[{"ARABIC_TEXT": "ذكر الصباح", "REPEAT": 1}],
        )

        response = self.client.get(reverse("Hisn_Muslim:home"), {"collection_id": 27})

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.context["category_name"], "Morning Adhkar")
        self.assertEqual(len(response.context["entries"]), 1)
