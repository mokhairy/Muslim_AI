from django.http import HttpRequest, HttpResponse
from django.shortcuts import render

from Muslim_AI.content_api_clients import load_hadith_library_page
from Muslim_AI.islamic_api_helpers import ExternalApiError, build_base_context, parse_positive_int


def home(request: HttpRequest) -> HttpResponse:
    selected_edition = request.GET.get("edition", "")
    hadith_limit = parse_positive_int(request.GET.get("limit"), 12, minimum=1, maximum=40)

    service_error = None
    page_data = {
        "editions": [],
        "selected_edition": selected_edition,
        "selected_metadata": None,
        "hadith_items": [],
    }

    try:
        result = load_hadith_library_page(
            selected_edition=selected_edition,
            hadith_limit=hadith_limit,
            load_selected_edition=bool(request.GET),
        )
        page_data = {
            "editions": result.editions,
            "selected_edition": result.selected_edition,
            "selected_metadata": result.selected_metadata,
            "hadith_items": result.hadith_items,
        }
    except ExternalApiError as exc:
        service_error = str(exc)

    context = {
        **build_base_context(request, active_page="hadith_library"),
        **page_data,
        "hadith_limit": hadith_limit,
        "service_error": service_error,
    }
    return render(request, "Hadith_Library/home.html", context)
