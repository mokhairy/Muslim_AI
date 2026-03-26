from django.http import HttpRequest, HttpResponse
from django.shortcuts import render

from Muslim_AI.content_api_clients import load_hisn_muslim_page
from Muslim_AI.islamic_api_helpers import ExternalApiError, build_base_context, parse_positive_int


def home(request: HttpRequest) -> HttpResponse:
    collection_id = parse_positive_int(request.GET.get("collection_id"), 27, minimum=1)

    service_error = None
    page_data = {
        "category_name": "",
        "entries": [],
    }
    try:
        result = load_hisn_muslim_page(collection_id=collection_id)
        page_data = {
            "category_name": result.category_name,
            "entries": result.entries,
        }
    except ExternalApiError as exc:
        service_error = str(exc)

    context = {
        **build_base_context(request, active_page="hisn_muslim"),
        "collection_id": collection_id,
        **page_data,
        "service_error": service_error,
    }
    return render(request, "Hisn_Muslim/home.html", context)
