from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse

from Muslim_AI.content_api_clients import (
    HadithEdition,
    HadithLibraryMetadata,
    HadithLibraryPageData,
)


class HadithLibraryViewTests(TestCase):
    @patch("Hadith_Library.views.load_hadith_library_page")
    def test_home_loads_selected_edition(self, load_page_mock):
        load_page_mock.return_value = HadithLibraryPageData(
            editions=[HadithEdition(name="eng-abudawud", label="English - Abu Dawud", link="x")],
            selected_edition="eng-abudawud",
            selected_metadata=HadithLibraryMetadata(
                name="eng-abudawud",
                label="English - Abu Dawud",
                link="x",
                source_name="Sunan Abi Dawud",
            ),
            hadith_items=[{"hadithnumber": 1, "text": "Sample hadith"}],
        )

        response = self.client.get(reverse("Hadith_Library:home"), {"edition": "eng-abudawud"})

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.context["selected_metadata"].source_name, "Sunan Abi Dawud")
        self.assertEqual(len(response.context["hadith_items"]), 1)
        self.assertContains(response, "Sample hadith")
