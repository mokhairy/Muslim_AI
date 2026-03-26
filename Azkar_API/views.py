from django.http import HttpRequest, HttpResponse
from django.shortcuts import render

from Muslim_AI.content_api_clients import load_azkar_page
from Muslim_AI.islamic_api_helpers import ExternalApiError, build_base_context


def home(request: HttpRequest) -> HttpResponse:
    selected_category = request.GET.get("category", "")
    service_error = None
    page_data = {
        "categories": [],
        "selected_category": selected_category,
        "entries": [],
    }

    try:
        result = load_azkar_page(selected_category=selected_category)
        page_data = {
            "categories": result.categories,
            "selected_category": result.selected_category,
            "entries": result.entries,
        }
    except ExternalApiError as exc:
        service_error = str(exc)

    context = {
        **build_base_context(request, active_page="azkar_api"),
        **page_data,
        "service_error": service_error,
    }
    return render(request, "Azkar_API/home.html", context)
