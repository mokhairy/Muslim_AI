from django.http import HttpRequest, HttpResponse
from django.shortcuts import render

from Muslim_AI.content_api_clients import load_radio_page
from Muslim_AI.islamic_api_helpers import ExternalApiError, build_base_context, parse_positive_int


def home(request: HttpRequest) -> HttpResponse:
    selected_station_id = parse_positive_int(request.GET.get("station"), 1, minimum=1)

    service_error = None
    page_data = {
        "stations": [],
        "selected_station": None,
        "selected_station_id": selected_station_id,
    }
    try:
        result = load_radio_page(selected_station_id=selected_station_id)
        page_data = {
            "stations": result.stations,
            "selected_station": result.selected_station,
            "selected_station_id": result.selected_station_id,
        }
    except ExternalApiError as exc:
        service_error = str(exc)

    context = {
        **build_base_context(request, active_page="radio_api"),
        **page_data,
        "service_error": service_error,
    }
    return render(request, "Radio_API/home.html", context)
