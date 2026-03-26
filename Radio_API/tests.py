from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse

from Muslim_AI.content_api_clients import RadioPageData, RadioStation


class RadioApiViewTests(TestCase):
    @patch("Radio_API.views.load_radio_page")
    def test_home_selects_requested_station(self, load_page_mock):
        load_page_mock.return_value = RadioPageData(
            stations=[
                RadioStation(id=1, name="Makkah Radio", url="https://example.com/1"),
                RadioStation(id=2, name="Madinah Radio", url="https://example.com/2"),
            ],
            selected_station=RadioStation(
                id=2,
                name="Madinah Radio",
                url="https://example.com/2",
            ),
            selected_station_id=2,
        )

        response = self.client.get(reverse("Radio_API:home"), {"station": 2})

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.context["selected_station"].name, "Madinah Radio")
        self.assertContains(response, "Madinah Radio")
