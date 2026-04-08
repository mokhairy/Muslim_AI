from __future__ import annotations

from django.http import HttpRequest, HttpResponse

from .reader import render_quran_reader_page


def home(request: HttpRequest) -> HttpResponse:
    return render_quran_reader_page(
        request,
        default_mode="read_listen",
        active_page="quran_text",
        legacy_edition_kind="translation",
    )
