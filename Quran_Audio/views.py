from __future__ import annotations

from django.http import HttpRequest, HttpResponse
from django.shortcuts import render

from Muslim_AI.content_api_clients import load_quran_audio_page
from Muslim_AI.islamic_api_helpers import (
    ExternalApiError,
    build_base_context,
    fetch_alquran_editions,
    parse_positive_int,
)


def _audio_options() -> list[tuple[str, str]]:
    editions = fetch_alquran_editions(edition_format="audio")
    preferred_order = (
        "ar.alafasy",
        "ar.abdulsamad",
        "ar.abdurrahmaansudais",
        "ar.shaatree",
        "ar.mahermuaiqly",
    )
    by_identifier = {edition.get("identifier"): edition for edition in editions}
    options: list[tuple[str, str]] = []
    for identifier in preferred_order:
        edition = by_identifier.get(identifier)
        if not edition:
            continue
        options.append(
            (identifier, edition.get("englishName") or edition.get("name") or identifier)
        )
    if options:
        return options
    return [("ar.alafasy", "Alafasy")]


def home(request: HttpRequest) -> HttpResponse:
    chapter_id = parse_positive_int(request.GET.get("chapter"), 1, minimum=1, maximum=114)
    edition_options = _audio_options()
    valid_identifiers = {identifier for identifier, _ in edition_options}
    selected_edition = request.GET.get("edition", "ar.alafasy")
    if selected_edition not in valid_identifiers:
        selected_edition = edition_options[0][0]

    service_error = None
    page_data = {
        "surah_data": None,
    }
    try:
        result = load_quran_audio_page(
            chapter_id=chapter_id,
            selected_edition=selected_edition,
        )
        page_data = {
            "surah_data": result.surah_data,
        }
    except ExternalApiError as exc:
        service_error = str(exc)

    context = {
        **build_base_context(request, active_page="quran_audio"),
        "chapter_id": chapter_id,
        "selected_edition": selected_edition,
        "edition_options": edition_options,
        **page_data,
        "service_error": service_error,
    }
    return render(request, "Quran_Audio/home.html", context)
