from __future__ import annotations

from django.http import HttpRequest, HttpResponse
from django.shortcuts import render

from Muslim_AI.content_api_clients import load_quran_translation_page
from Muslim_AI.islamic_api_helpers import (
    ExternalApiError,
    build_base_context,
    fetch_alquran_editions,
    parse_positive_int,
)


def _translation_options() -> list[tuple[str, str]]:
    editions = fetch_alquran_editions(edition_format="text", edition_type="translation")
    preferred_order = ("en.asad", "en.pickthall", "en.yusufali", "fr.hamidullah", "ur.jalandhry")
    by_identifier = {edition.get("identifier"): edition for edition in editions}
    options: list[tuple[str, str]] = []
    for identifier in preferred_order:
        edition = by_identifier.get(identifier)
        if not edition:
            continue
        options.append(
            (
                identifier,
                f"{edition.get('language', '').upper()} - "
                f"{edition.get('englishName') or edition.get('name')}",
            )
        )
    if options:
        return options
    return [
        ("en.asad", "EN - Muhammad Asad"),
        ("en.pickthall", "EN - Pickthall"),
        ("fr.hamidullah", "FR - Hamidullah"),
    ]


def home(request: HttpRequest) -> HttpResponse:
    surah_number = parse_positive_int(request.GET.get("surah"), 1, minimum=1, maximum=114)
    edition_options = _translation_options()
    valid_identifiers = {identifier for identifier, _ in edition_options}
    selected_edition = request.GET.get("edition", "en.asad")
    if selected_edition not in valid_identifiers:
        selected_edition = edition_options[0][0]

    service_error = None
    page_data = {
        "surah_data": None,
        "ayah_rows": [],
    }
    try:
        result = load_quran_translation_page(
            surah_number=surah_number,
            selected_edition=selected_edition,
        )
        page_data = {
            "surah_data": result.surah_data,
            "ayah_rows": result.ayah_rows,
        }
    except ExternalApiError as exc:
        service_error = str(exc)

    context = {
        **build_base_context(request, active_page="quran_text"),
        "surah_number": surah_number,
        "selected_edition": selected_edition,
        "edition_options": edition_options,
        **page_data,
        "service_error": service_error,
    }
    return render(request, "Quran_Text/home.html", context)
