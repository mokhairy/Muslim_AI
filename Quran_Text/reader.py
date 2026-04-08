from __future__ import annotations

from types import SimpleNamespace

from django.http import HttpRequest, HttpResponse
from django.shortcuts import render

from Muslim_AI.content_api_clients import load_quran_audio_page, load_quran_translation_page
from Muslim_AI.islamic_api_helpers import (
    ExternalApiError,
    build_base_context,
    fetch_alquran_editions,
    fetch_json,
    parse_positive_int,
)

DEFAULT_TRANSLATION_EDITION = "en.asad"
DEFAULT_AUDIO_EDITION = "ar.alafasy"
QURAN_STRUCTURE_URL = "https://api.alquran.cloud/v1/surah"
QURAN_READER_MODES = (
    {
        "slug": "read",
        "label": "Read Quran only",
        "copy": "Focus on Arabic text and translation with an uncluttered reading layout.",
    },
    {
        "slug": "listen",
        "label": "Listen only",
        "copy": "Keep the player front and center while the surah progresses verse by verse.",
    },
    {
        "slug": "read_listen",
        "label": "Read while listening",
        "copy": "Follow each ayah as it is recited with automatic highlighting and scroll sync.",
    },
)


def _normalize_mode(raw_mode: str | None, *, default_mode: str) -> str:
    valid_modes = {item["slug"] for item in QURAN_READER_MODES}
    if raw_mode in valid_modes:
        return raw_mode
    return default_mode


def _translation_options() -> list[tuple[str, str]]:
    editions = fetch_alquran_editions(edition_format="text", edition_type="translation")
    preferred_order = (
        "en.asad",
        "en.pickthall",
        "en.yusufali",
        "fr.hamidullah",
        "ur.jalandhry",
    )
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


def _audio_options() -> list[tuple[str, str]]:
    editions = fetch_alquran_editions(edition_format="audio")
    preferred_order = (
        "ar.alafasy",
        "ar.abdulsamad",
        "ar.abdurrahmaansudais",
        "ar.shaatree",
        "ar.mahermuaiqly",
    )
    verse_by_verse_editions = [
        edition
        for edition in editions
        if edition.get("type") in {"versebyverse", "audio"}
    ]
    by_identifier = {edition.get("identifier"): edition for edition in verse_by_verse_editions}
    options: list[tuple[str, str]] = []
    for identifier in preferred_order:
        edition = by_identifier.get(identifier)
        if not edition:
            continue
        name = edition.get("englishName") or edition.get("name") or identifier
        options.append((identifier, f"Sheikh {name}"))
    if options:
        return options
    return [("ar.alafasy", "Sheikh Alafasy")]


def _surah_options() -> list[dict[str, object]]:
    try:
        payload = fetch_json(QURAN_STRUCTURE_URL)
    except ExternalApiError:
        return [
            {
                "number": index,
                "name": f"Surah {index}",
                "englishName": f"Surah {index}",
                "englishNameTranslation": "",
                "numberOfAyahs": "",
                "revelationType": "",
            }
            for index in range(1, 115)
        ]

    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, list):
        return []
    return [item for item in data if isinstance(item, dict)]


def _pick_valid_option(
    raw_value: str | None,
    options: list[tuple[str, str]],
    *,
    fallback: str,
) -> str:
    valid_identifiers = {identifier for identifier, _ in options}
    if raw_value in valid_identifiers:
        return raw_value
    if fallback in valid_identifiers:
        return fallback
    return options[0][0]


def _range_label(values: list[int], *, singular: str) -> str:
    if not values:
        return "--"
    if len(values) == 1:
        return f"{singular} {values[0]}"
    return f"{singular} {values[0]}-{values[-1]}"


def _secondary_audio_url(ayah_payload: dict[str, object]) -> str:
    secondary_audio = ayah_payload.get("audioSecondary")
    if isinstance(secondary_audio, list) and secondary_audio:
        first_url = secondary_audio[0]
        return first_url if isinstance(first_url, str) else ""
    return ""


def _merge_ayah_rows(translation_result, audio_result) -> list[dict[str, object]]:
    audio_by_ayah_number: dict[int, dict[str, object]] = {}
    audio_ayahs = []
    if audio_result.surah_data:
        audio_ayahs = audio_result.surah_data.get("ayahs", [])
    for ayah in audio_ayahs:
        if not isinstance(ayah, dict):
            continue
        number = ayah.get("numberInSurah")
        if isinstance(number, int):
            audio_by_ayah_number[number] = ayah

    merged_rows: list[dict[str, object]] = []
    for ayah in translation_result.ayah_rows:
        audio_ayah = audio_by_ayah_number.get(ayah.number_in_surah or -1, {})
        merged_rows.append(
            {
                "number_in_surah": ayah.number_in_surah,
                "arabic_text": ayah.arabic_text,
                "translation_text": ayah.translation_text,
                "audio_url": audio_ayah.get("audio") or "",
                "audio_secondary_url": _secondary_audio_url(audio_ayah),
                "juz": audio_ayah.get("juz"),
                "hizb_quarter": audio_ayah.get("hizbQuarter"),
                "page": audio_ayah.get("page"),
                "manzil": audio_ayah.get("manzil"),
            }
        )

    if merged_rows:
        return merged_rows

    for ayah in audio_ayahs:
        if not isinstance(ayah, dict):
            continue
        merged_rows.append(
            {
                "number_in_surah": ayah.get("numberInSurah"),
                "arabic_text": ayah.get("text"),
                "translation_text": "",
                "audio_url": ayah.get("audio") or "",
                "audio_secondary_url": _secondary_audio_url(ayah),
                "juz": ayah.get("juz"),
                "hizb_quarter": ayah.get("hizbQuarter"),
                "page": ayah.get("page"),
                "manzil": ayah.get("manzil"),
            }
        )
    return merged_rows


def _meta_cards(
    surah_data: dict[str, object] | None,
    ayah_rows: list[dict[str, object]],
) -> list[dict[str, str]]:
    juz_values = sorted(
        {
            int(item["juz"])
            for item in ayah_rows
            if isinstance(item.get("juz"), int)
        }
    )
    page_values = sorted(
        {
            int(item["page"])
            for item in ayah_rows
            if isinstance(item.get("page"), int)
        }
    )
    manzil_values = sorted(
        {
            int(item["manzil"])
            for item in ayah_rows
            if isinstance(item.get("manzil"), int)
        }
    )
    return [
        {
            "label": "Surah",
            "value": (
                f"{surah_data.get('number', '--')} · "
                f"{surah_data.get('englishName', 'Unknown')}"
                if surah_data
                else "--"
            ),
        },
        {
            "label": "Ayat",
            "value": (
                str(surah_data.get("numberOfAyahs", "--"))
                if surah_data
                else str(len(ayah_rows) or "--")
            ),
        },
        {
            "label": "Revelation",
            "value": str(surah_data.get("revelationType", "--")) if surah_data else "--",
        },
        {"label": "Juz", "value": _range_label(juz_values, singular="Juz")},
        {"label": "Pages", "value": _range_label(page_values, singular="Page")},
        {"label": "Manzil", "value": _range_label(manzil_values, singular="Manzil")},
    ]


def build_quran_reader_context(
    request: HttpRequest,
    *,
    default_mode: str,
    active_page: str,
    legacy_edition_kind: str,
) -> dict[str, object]:
    surah_number = parse_positive_int(
        request.GET.get("surah") or request.GET.get("chapter"),
        1,
        minimum=1,
        maximum=114,
    )
    translation_options = _translation_options()
    audio_options = _audio_options()
    surah_options = _surah_options()

    raw_translation = request.GET.get("translation")
    raw_reader = request.GET.get("reader") or request.GET.get("audio_edition")
    if legacy_edition_kind == "translation" and not raw_translation:
        raw_translation = request.GET.get("edition")
    if legacy_edition_kind == "audio" and not raw_reader:
        raw_reader = request.GET.get("edition")

    selected_mode = _normalize_mode(request.GET.get("mode"), default_mode=default_mode)
    selected_translation = _pick_valid_option(
        raw_translation,
        translation_options,
        fallback=DEFAULT_TRANSLATION_EDITION,
    )
    selected_audio_edition = _pick_valid_option(
        raw_reader,
        audio_options,
        fallback=DEFAULT_AUDIO_EDITION,
    )

    service_errors: list[str] = []
    try:
        translation_result = load_quran_translation_page(
            surah_number=surah_number,
            selected_edition=selected_translation,
        )
    except ExternalApiError as exc:
        translation_result = SimpleNamespace(surah_data=None, ayah_rows=[])
        service_errors.append(str(exc))

    try:
        audio_result = load_quran_audio_page(
            chapter_id=surah_number,
            selected_edition=selected_audio_edition,
        )
    except ExternalApiError as exc:
        audio_result = SimpleNamespace(surah_data=None)
        service_errors.append(str(exc))

    ayah_entries = _merge_ayah_rows(translation_result, audio_result)
    display_surah = translation_result.surah_data or audio_result.surah_data
    player_tracks = [
        {
            "ayahNumber": item["number_in_surah"],
            "audioUrl": item["audio_url"],
            "secondaryUrl": item["audio_secondary_url"],
            "arabicText": item["arabic_text"],
            "translationText": item["translation_text"],
        }
        for item in ayah_entries
        if item.get("audio_url")
    ]

    return {
        **build_base_context(request, active_page=active_page),
        "selected_mode": selected_mode,
        "reader_modes": list(QURAN_READER_MODES),
        "surah_number": surah_number,
        "surah_options": surah_options,
        "selected_translation": selected_translation,
        "translation_options": translation_options,
        "selected_audio_edition": selected_audio_edition,
        "audio_options": audio_options,
        "surah_data": display_surah,
        "ayah_entries": ayah_entries,
        "player_tracks": player_tracks,
        "player_available": bool(player_tracks),
        "meta_cards": _meta_cards(display_surah, ayah_entries),
        "service_error": " ".join(dict.fromkeys(service_errors)),
    }


def render_quran_reader_page(
    request: HttpRequest,
    *,
    default_mode: str,
    active_page: str,
    legacy_edition_kind: str,
) -> HttpResponse:
    context = build_quran_reader_context(
        request,
        default_mode=default_mode,
        active_page=active_page,
        legacy_edition_kind=legacy_edition_kind,
    )
    return render(request, "Quran_Text/home.html", context)
