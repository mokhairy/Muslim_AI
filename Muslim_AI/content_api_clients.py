from __future__ import annotations

import json
from dataclasses import dataclass, field
from functools import lru_cache

from .islamic_api_helpers import fetch_json

EDITION_INDEX_URL = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions.json"
AZKAR_SOURCE_URL = (
    "https://raw.githubusercontent.com/nawafalqari/azkar-api/"
    "56df51279ab6eb86dc2f6202c7de26c8948331c1/azkar.json"
)


@dataclass(frozen=True)
class AyahRow:
    number_in_surah: int | None
    arabic_text: str | None
    translation_text: str | None


@dataclass(frozen=True)
class QuranTranslationPageData:
    surah_data: dict[str, object] | None = None
    ayah_rows: list[AyahRow] = field(default_factory=list)


@dataclass(frozen=True)
class QuranAudioPageData:
    surah_data: dict[str, object] | None = None


@dataclass(frozen=True)
class TafsirItem:
    numberInSurah: int | None
    arabic_text: str | None
    tafsir_text: str | None


@dataclass(frozen=True)
class TafsirPageData:
    tafsir_items: list[TafsirItem] = field(default_factory=list)


@dataclass(frozen=True)
class HadithApiPageData:
    hadith_items: list[object] = field(default_factory=list)
    payload_preview: str = ""


@dataclass(frozen=True)
class AzkarPageData:
    categories: list[str] = field(default_factory=list)
    selected_category: str = ""
    entries: list[dict[str, object]] = field(default_factory=list)


@dataclass(frozen=True)
class HadithEdition:
    name: str
    label: str
    link: str


@dataclass(frozen=True)
class HadithLibraryMetadata:
    name: str
    label: str
    link: str
    source_name: str = ""


@dataclass(frozen=True)
class HadithLibraryPageData:
    editions: list[HadithEdition] = field(default_factory=list)
    selected_edition: str = ""
    selected_metadata: HadithLibraryMetadata | None = None
    hadith_items: list[object] = field(default_factory=list)


@dataclass(frozen=True)
class HisnMuslimPageData:
    category_name: str = ""
    entries: list[object] = field(default_factory=list)


@dataclass(frozen=True)
class RadioStation:
    id: int
    name: str
    url: str


@dataclass(frozen=True)
class RadioPageData:
    stations: list[RadioStation] = field(default_factory=list)
    selected_station: RadioStation | None = None
    selected_station_id: int = 1


@lru_cache(maxsize=128)
def _fetch_cached_json(url: str) -> object:
    return fetch_json(url)


def clear_content_api_caches() -> None:
    _fetch_cached_json.cache_clear()


def _quran_editions_payload(surah_number: int, selected_edition: str) -> object:
    return _fetch_cached_json(
        f"https://api.alquran.cloud/v1/surah/{surah_number}/editions/quran-uthmani,{selected_edition}"
    )


def load_quran_translation_page(
    *,
    surah_number: int,
    selected_edition: str,
) -> QuranTranslationPageData:
    surah_data = None
    ayah_rows: list[AyahRow] = []
    payload = _quran_editions_payload(surah_number, selected_edition)
    editions = payload.get("data", []) if isinstance(payload, dict) else []
    if len(editions) >= 2:
        arabic_data = editions[0]
        translation_data = editions[1]
        surah_data = translation_data
        arabic_ayahs = arabic_data.get("ayahs", [])
        translation_ayahs = translation_data.get("ayahs", [])
        for arabic_ayah, translation_ayah in zip(arabic_ayahs, translation_ayahs, strict=False):
            ayah_rows.append(
                AyahRow(
                    number_in_surah=arabic_ayah.get("numberInSurah"),
                    arabic_text=arabic_ayah.get("text"),
                    translation_text=translation_ayah.get("text"),
                )
            )
    return QuranTranslationPageData(
        surah_data=surah_data,
        ayah_rows=ayah_rows,
    )


def load_quran_audio_page(*, chapter_id: int, selected_edition: str) -> QuranAudioPageData:
    payload = _fetch_cached_json(
        f"https://api.alquran.cloud/v1/surah/{chapter_id}/{selected_edition}"
    )
    return QuranAudioPageData(
        surah_data=payload.get("data") if isinstance(payload, dict) else None,
    )


def load_tafsir_page(*, surah_number: int, selected_translation: str) -> TafsirPageData:
    tafsir_items: list[TafsirItem] = []
    payload = _quran_editions_payload(surah_number, selected_translation)
    editions = payload.get("data", []) if isinstance(payload, dict) else []
    if len(editions) >= 2:
        arabic_ayahs = editions[0].get("ayahs", [])
        tafsir_ayahs = editions[1].get("ayahs", [])
        for arabic_ayah, tafsir_ayah in zip(arabic_ayahs, tafsir_ayahs, strict=False):
            tafsir_items.append(
                TafsirItem(
                    numberInSurah=arabic_ayah.get("numberInSurah"),
                    arabic_text=arabic_ayah.get("text"),
                    tafsir_text=tafsir_ayah.get("text"),
                )
            )
    return TafsirPageData(tafsir_items=tafsir_items)


def _extract_hadith_items(payload: object) -> list[object]:
    if isinstance(payload, list):
        return payload
    if not isinstance(payload, dict):
        return []
    for key in ("items", "data", "hadiths", "hadith"):
        value = payload.get(key)
        if isinstance(value, list):
            return value
    return []


def load_hadith_api_page(
    *,
    collection: str,
    page_number: int,
    page_limit: int,
) -> HadithApiPageData:
    payload = _fetch_cached_json(
        f"https://hadis-api-id.vercel.app/hadith/{collection}?page={page_number}&limit={page_limit}"
    )
    return HadithApiPageData(
        hadith_items=_extract_hadith_items(payload),
        payload_preview=json.dumps(payload, ensure_ascii=False, indent=2)[:4000],
    )


def _flatten_azkar_entries(node: object) -> list[dict[str, object]]:
    if isinstance(node, dict) and "content" in node:
        return [node]
    if isinstance(node, list):
        flattened: list[dict[str, object]] = []
        for item in node:
            flattened.extend(_flatten_azkar_entries(item))
        return flattened
    return []


def load_azkar_page(*, selected_category: str) -> AzkarPageData:
    categories: list[str] = []
    entries: list[dict[str, object]] = []
    payload = _fetch_cached_json(AZKAR_SOURCE_URL)
    if isinstance(payload, dict):
        categories = [str(key) for key in payload]
        if categories and selected_category not in payload:
            selected_category = categories[0]
        entries = _flatten_azkar_entries(payload.get(selected_category, []))
    return AzkarPageData(
        categories=categories,
        selected_category=selected_category,
        entries=entries,
    )


def _flatten_editions(payload: object) -> list[HadithEdition]:
    editions: list[HadithEdition] = []
    if not isinstance(payload, dict):
        return editions
    for book_key, book_payload in payload.items():
        if not isinstance(book_payload, dict):
            continue
        for edition in book_payload.get("collection", []):
            if not isinstance(edition, dict):
                continue
            name = str(edition.get("name", ""))
            link = str(edition.get("linkmin") or edition.get("link") or "")
            if not name or not link:
                continue
            editions.append(
                HadithEdition(
                    name=name,
                    label=f"{edition.get('language', 'Unknown')} - {edition.get('book', book_key)}",
                    link=link,
                )
            )
    return editions


def load_hadith_library_page(
    *,
    selected_edition: str,
    hadith_limit: int,
    load_selected_edition: bool,
) -> HadithLibraryPageData:
    selected_metadata = None
    hadith_items: list[object] = []

    edition_index = _fetch_cached_json(EDITION_INDEX_URL)
    editions = _flatten_editions(edition_index)
    if editions and not selected_edition:
        available_names = {item.name for item in editions}
        selected_edition = "eng-abudawud" if "eng-abudawud" in available_names else editions[0].name
    if load_selected_edition:
        selected_metadata = next((item for item in editions if item.name == selected_edition), None)
    if load_selected_edition and selected_metadata is not None:
        payload = _fetch_cached_json(selected_metadata.link)
        if isinstance(payload, dict):
            hadith_items = (payload.get("hadiths") or [])[:hadith_limit]
            selected_metadata = HadithLibraryMetadata(
                name=selected_metadata.name,
                label=selected_metadata.label,
                link=selected_metadata.link,
                source_name=str(payload.get("metadata", {}).get("name", "")),
            )
    return HadithLibraryPageData(
        editions=editions,
        selected_edition=selected_edition,
        selected_metadata=selected_metadata,
        hadith_items=hadith_items,
    )


def load_hisn_muslim_page(*, collection_id: int) -> HisnMuslimPageData:
    category_name = ""
    entries: list[object] = []
    payload = _fetch_cached_json(f"https://www.hisnmuslim.com/api/ar/{collection_id}.json")
    if isinstance(payload, dict) and payload:
        category_name, entries = next(iter(payload.items()))
    return HisnMuslimPageData(
        category_name=category_name,
        entries=list(entries),
    )


def load_radio_page(*, selected_station_id: int) -> RadioPageData:
    stations: list[RadioStation] = []
    selected_station = None
    payload = _fetch_cached_json("https://data-rosy.vercel.app/radio.json")
    if isinstance(payload, dict):
        stations = [
            RadioStation(
                id=int(station.get("id", 0)),
                name=str(station.get("name", "")),
                url=str(station.get("url", "")),
            )
            for station in payload.get("radios", []) or []
            if station.get("id") is not None and station.get("name") and station.get("url")
        ]
    selected_station = next(
        (station for station in stations if station.id == selected_station_id),
        None,
    )
    if selected_station is None and stations:
        selected_station = stations[0]
        selected_station_id = selected_station.id
    return RadioPageData(
        stations=stations,
        selected_station=selected_station,
        selected_station_id=selected_station_id,
    )
