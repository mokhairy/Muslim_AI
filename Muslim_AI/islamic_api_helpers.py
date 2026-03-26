from __future__ import annotations

import json
from functools import lru_cache
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from django.http import HttpRequest

from Islamic_Calender.calendar_utils import (
    APP_DEFAULT_CALENDAR_MODE,
    CALENDAR_MODES,
    get_calendar_mode,
)
from Islamic_Calender.display import today_record


class ExternalApiError(Exception):
    pass


def parse_positive_int(
    raw_value: str | None,
    default: int,
    *,
    minimum: int = 1,
    maximum: int | None = None,
) -> int:
    try:
        value = int(raw_value or default)
    except (TypeError, ValueError):
        value = default
    if value < minimum:
        value = minimum
    if maximum is not None and value > maximum:
        value = maximum
    return value


def fetch_json(
    url: str,
    *,
    timeout: int = 15,
    headers: dict[str, str] | None = None,
):
    request_headers = {
        "User-Agent": "MuslimAI/1.0 (+https://alquran.cloud integration)",
        "Accept": "application/json, text/plain, */*",
    }
    if headers:
        request_headers.update(headers)
    request = Request(url, headers=request_headers)
    try:
        with urlopen(request, timeout=timeout) as response:
            payload = response.read().decode("utf-8", "replace").lstrip("\ufeff")
    except Exception as exc:  # pragma: no cover
        raise ExternalApiError("Unable to reach the external API right now.") from exc

    try:
        return json.loads(payload)
    except json.JSONDecodeError as exc:  # pragma: no cover
        raise ExternalApiError(
            "The external API returned a response that could not be parsed."
        ) from exc


@lru_cache(maxsize=32)
def fetch_alquran_editions(*, edition_format: str, edition_type: str | None = None) -> list[dict]:
    query = {"format": edition_format}
    if edition_type:
        query["type"] = edition_type
    payload = fetch_json(f"https://api.alquran.cloud/v1/edition?{urlencode(query)}")
    if not isinstance(payload, dict):
        return []
    data = payload.get("data")
    return data if isinstance(data, list) else []


def build_base_context(request: HttpRequest, *, active_page: str) -> dict[str, object]:
    mode = get_calendar_mode(request.GET.get("calendar_mode") or APP_DEFAULT_CALENDAR_MODE)
    return {
        "active_page": active_page,
        "calendar_modes": list(CALENDAR_MODES.values()),
        "current_calendar_mode": mode,
        "today_record": today_record(mode),
    }
