from __future__ import annotations

from django.http import HttpRequest, HttpResponse
from django.shortcuts import render

from Muslim_AI.content_api_clients import load_tafsir_page
from Muslim_AI.islamic_api_helpers import (
    ExternalApiError,
    build_base_context,
    fetch_alquran_editions,
    parse_positive_int,
)


def _tafsir_options() -> list[tuple[str, str]]:
    editions = fetch_alquran_editions(edition_format="text", edition_type="tafsir")
    options = [
        (
            edition.get("identifier", ""),
            edition.get("englishName") or edition.get("name") or edition.get("identifier", ""),
        )
        for edition in editions
        if edition.get("identifier")
    ]
    return options or [("ar.muyassar", "King Fahad Quran Complex")]


def home(request: HttpRequest) -> HttpResponse:
    surah_number = parse_positive_int(request.GET.get("surah"), 1, minimum=1, maximum=114)
    translation_options = _tafsir_options()
    valid_identifiers = {identifier for identifier, _ in translation_options}
    selected_translation = request.GET.get("translation", "ar.muyassar")
    if selected_translation not in valid_identifiers:
        selected_translation = translation_options[0][0]

    service_error = None
    page_data = {
        "tafsir_items": [],
    }
    try:
        result = load_tafsir_page(
            surah_number=surah_number,
            selected_translation=selected_translation,
        )
        page_data = {
            "tafsir_items": result.tafsir_items,
        }
    except ExternalApiError as exc:
        service_error = str(exc)

    context = {
        **build_base_context(request, active_page="tafsir"),
        "surah_number": surah_number,
        "selected_translation": selected_translation,
        "translation_options": translation_options,
        **page_data,
        "service_error": service_error,
    }
    return render(request, "Tafsir/home.html", context)
