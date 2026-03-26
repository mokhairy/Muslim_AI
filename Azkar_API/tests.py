from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse

from Muslim_AI.content_api_clients import AzkarPageData


class AzkarApiViewTests(TestCase):
    @patch("Azkar_API.views.load_azkar_page")
    def test_home_renders_selected_category_entries(self, load_page_mock):
        load_page_mock.return_value = AzkarPageData(
            categories=["Morning", "Evening"],
            selected_category="Morning",
            entries=[{"content": "Morning remembrance", "count": 3}],
        )

        response = self.client.get(reverse("Azkar_API:home"))

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.context["selected_category"], "Morning")
        self.assertEqual(len(response.context["entries"]), 1)
        self.assertContains(response, "Morning remembrance")
