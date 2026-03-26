from django.http import HttpRequest, HttpResponse
from django.shortcuts import render

from Muslim_AI.content_api_clients import load_hadith_api_page
from Muslim_AI.islamic_api_helpers import ExternalApiError, build_base_context, parse_positive_int


def home(request: HttpRequest) -> HttpResponse:
    collection = (request.GET.get("collection") or "abu-dawud").strip() or "abu-dawud"
    page_number = parse_positive_int(request.GET.get("page"), 1, minimum=1)
    page_limit = parse_positive_int(request.GET.get("limit"), 20, minimum=1, maximum=50)

    service_error = None
    page_data = {
        "hadith_items": [],
        "payload_preview": "",
    }

    try:
        result = load_hadith_api_page(
            collection=collection,
            page_number=page_number,
            page_limit=page_limit,
        )
        page_data = {
            "hadith_items": result.hadith_items,
            "payload_preview": result.payload_preview,
        }
    except ExternalApiError as exc:
        service_error = str(exc)

    context = {
        **build_base_context(request, active_page="hadith_api"),
        "collection": collection,
        "page_number": page_number,
        "page_limit": page_limit,
        **page_data,
        "service_error": service_error,
    }
    return render(request, "Hadith_API/home.html", context)
