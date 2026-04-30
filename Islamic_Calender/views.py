from __future__ import annotations

import calendar
import json
from collections import Counter
from datetime import date
from functools import cache
from urllib.request import Request, urlopen

from django.http import HttpRequest, HttpResponse
from django.shortcuts import render

from .calendar_utils import (
    APP_DEFAULT_CALENDAR_MODE,
    CALENDAR_MODES,
    CalendarModeDefinition,
    get_calendar_mode,
    gregorian_to_hijri_for_mode,
    hijri_to_gregorian_for_mode,
    islamic_month_length,
    supported_gregorian_range,
)
from .display import resolve_calendar_record, today_record
from .forms import GregorianLookupForm, HijriLookupForm

RAMADAN_MONTH = 9
WEEKDAY_ORDER = {name: index for index, name in enumerate(calendar.day_name)}
SERMONS_SOURCES_API_URL = "https://sermons.islamic.network/api/sources.json"
SERMONS_LANGUAGES_API_URL = "https://sermons.islamic.network/api/languages.json"
SERMONS_YEAR_API_URL = "https://sermons.islamic.network/api/{handle}/{year}/friday.json"
ISLAMIC_NETWORK_RESOURCE_CARDS = (
    {
        "name": "AlQuran.Cloud",
        "category": "Quran",
        "tagline": "Full Quran text, translations, tafsir, and audio editions.",
        "summary": (
            "The Quran stack already used in Muslim AI. It exposes edition discovery, "
            "surah and ayah endpoints, translations, tafsir, and recitation audio."
        ),
        "url": "https://alquran.cloud/",
        "api_url": "https://alquran.cloud/api",
        "highlights": ["Editions", "Translations", "Audio recitations", "Tafsir"],
    },
    {
        "name": "AlAdhan",
        "category": "Azan",
        "tagline": "Prayer timings, qibla, calendar, and Hijri date services.",
        "summary": (
            "This is the right companion service for the prayer automation app because it "
            "covers daily timings, monthly calendars, qibla direction, and Hijri metadata."
        ),
        "url": "https://aladhan.com/",
        "api_url": "https://aladhan.com/prayer-times-api",
        "highlights": ["Timings", "Monthly calendar", "Qibla", "Hijri metadata"],
    },
    {
        "name": "Sermons",
        "category": "Knowledge",
        "tagline": "Friday khutbah archives with downloadable media assets.",
        "summary": (
            "The sermons network exposes source catalogues, supported languages, and dated "
            "Friday sermon entries with MP3, PDF, and DOC assets."
        ),
        "url": "https://sermons.islamic.network/",
        "api_url": "https://sermons.islamic.network/api/",
        "highlights": ["Khutbah archives", "Audio", "PDF handouts", "Languages"],
    },
    {
        "name": "Islamic CDN",
        "category": "Infrastructure",
        "tagline": "Media delivery across Islamic Network services.",
        "summary": (
            "Audio and document delivery for Quran and sermon assets is backed by the "
            "Islamic Network CDN, which makes direct media embedding practical inside the app."
        ),
        "url": "https://islamic.network/",
        "api_url": "https://islamic.network/services.html",
        "highlights": ["Media hosting", "Asset delivery", "Cross-service support"],
    },
)


def _fetch_remote_json(url: str, *, timeout: int = 10):
    request = Request(
        url,
        headers={
            "User-Agent": "MuslimAI/1.0 (+https://islamic.network/)",
            "Accept": "application/json",
        },
    )
    with urlopen(request, timeout=timeout) as response:
        return json.load(response)


def _flatten_sermons(payload) -> list[dict[str, object]]:
    if isinstance(payload, list):
        containers = payload
    elif isinstance(payload, dict):
        containers = payload.get("months") or payload.get("data") or [payload]
    else:
        containers = []

    sermons: list[dict[str, object]] = []
    for container in containers:
        if not isinstance(container, dict):
            continue
        sermon_items = container.get("sermons")
        if isinstance(sermon_items, list):
            sermons.extend(item for item in sermon_items if isinstance(item, dict))
            continue
        if any(key in container for key in ("title", "date", "editions")):
            sermons.append(container)
    return sermons


def _edition_links(editions: list[dict[str, object]]) -> dict[str, str]:
    links = {"audio_url": "", "pdf_url": "", "doc_url": ""}
    for edition in editions:
        if not isinstance(edition, dict):
            continue
        url = edition.get("url") or edition.get("href") or edition.get("download_url") or ""
        if not url:
            continue
        fingerprint = " ".join(
            str(value)
            for value in (
                edition.get("type"),
                edition.get("name"),
                edition.get("format"),
                url,
            )
            if value
        ).lower()
        if "mp3" in fingerprint and not links["audio_url"]:
            links["audio_url"] = str(url)
        elif "pdf" in fingerprint and not links["pdf_url"]:
            links["pdf_url"] = str(url)
        elif any(token in fingerprint for token in ("doc", "word")) and not links["doc_url"]:
            links["doc_url"] = str(url)
    return links


def build_islamic_network_resources_context() -> dict[str, object]:
    resources_error_messages: list[str] = []
    sermon_sources: list[dict[str, object]] = []
    sermon_languages: list[dict[str, object]] = []
    latest_sermons: list[dict[str, object]] = []
    latest_source_name = "Unavailable"
    latest_year = None

    try:
        sources_payload = _fetch_remote_json(SERMONS_SOURCES_API_URL)
        if isinstance(sources_payload, list):
            sermon_sources = [item for item in sources_payload if isinstance(item, dict)]
    except Exception:
        resources_error_messages.append("Live sermons catalogue is temporarily unavailable.")

    try:
        languages_payload = _fetch_remote_json(SERMONS_LANGUAGES_API_URL)
        if isinstance(languages_payload, list):
            sermon_languages = [item for item in languages_payload if isinstance(item, dict)]
    except Exception:
        resources_error_messages.append("Sermon language metadata could not be loaded.")

    if sermon_sources:
        selected_source = max(
            sermon_sources,
            key=lambda item: max(item.get("years") or [0]),
        )
        latest_source_name = str(selected_source.get("name", "Unavailable"))
        available_years = [
            int(year) for year in selected_source.get("years", []) if str(year).isdigit()
        ]
        if available_years:
            latest_year = max(available_years)
            try:
                sermons_payload = _fetch_remote_json(
                    SERMONS_YEAR_API_URL.format(
                        handle=selected_source.get("handle", ""),
                        year=latest_year,
                    )
                )
                sermons = _flatten_sermons(sermons_payload)
                latest_sermons = sorted(
                    [
                        {
                            "title": sermon.get("title") or "Untitled sermon",
                            "date_label": (sermon.get("date") or {}).get("iso8601", ""),
                            "languages": sorted(
                                {
                                    str(language)
                                    for language in (
                                        sermon.get("languages")
                                        or [
                                            edition.get("language")
                                            or edition.get("language_name")
                                            or edition.get("lang")
                                            for edition in sermon.get("editions", [])
                                            if isinstance(edition, dict)
                                        ]
                                    )
                                    if language
                                }
                            ),
                            **_edition_links(sermon.get("editions", [])),
                        }
                        for sermon in sermons
                    ],
                    key=lambda item: item["date_label"],
                    reverse=True,
                )[:5]
            except Exception:
                resources_error_messages.append("Latest sermon releases could not be fetched.")

    return {
        "network_resources": list(ISLAMIC_NETWORK_RESOURCE_CARDS),
        "sermon_sources": sermon_sources,
        "sermon_languages": sermon_languages,
        "latest_sermons": latest_sermons,
        "resources_error": " ".join(dict.fromkeys(resources_error_messages)),
        "resources_summary": {
            "services_count": len(ISLAMIC_NETWORK_RESOURCE_CARDS),
            "sources_count": len(sermon_sources),
            "languages_count": len(sermon_languages),
            "latest_source_name": latest_source_name,
            "latest_year": latest_year,
            "languages_preview": [
                item.get("name", "") for item in sermon_languages[:4] if item.get("name")
            ],
        },
    }


def month_bounds(year: int, month: int) -> tuple[date, date]:
    last_day = calendar.monthrange(year, month)[1]
    return date(year, month, 1), date(year, month, last_day)


def current_calendar_mode(request: HttpRequest) -> CalendarModeDefinition:
    return get_calendar_mode(request.GET.get("calendar_mode", APP_DEFAULT_CALENDAR_MODE))


def branding_kits() -> list[dict[str, object]]:
    return [
        {
            "slug": "aurora-arch",
            "name": "Aurora Arch",
            "tagline": "Elegant scholarship with a digital glow.",
            "logo_path": "Islamic_Calender/branding/aurora-arch.svg",
            "headline_font": "Sora SemiBold",
            "body_font": "Manrope Regular",
            "summary": (
                "A refined crescent-and-arch symbol aimed at a premium product that feels "
                "trustworthy, bright, and current."
            ),
            "colors": [
                {"label": "Emerald", "value": "#0f766e"},
                {"label": "Aqua", "value": "#38bdf8"},
                {"label": "Sand", "value": "#f7d488"},
                {"label": "Ink", "value": "#102033"},
            ],
            "keywords": ["Premium", "Calm", "Smart", "Editorial"],
            "titlebar_kicker": "Knowledge Workspace",
            "titlebar_title": "Muslim AI",
            "titlebar_meta": "Prayer, Quran, Hadith, Calendar",
        },
        {
            "slug": "lantern-pulse",
            "name": "Lantern Pulse",
            "tagline": "Warm, human, and built around daily rhythm.",
            "logo_path": "Islamic_Calender/branding/lantern-pulse.svg",
            "headline_font": "Outfit Bold",
            "body_font": "Plus Jakarta Sans",
            "summary": (
                "A lantern mark fused with a pulse line for a welcoming assistant focused "
                "on reminders, broadcasts, and daily practice."
            ),
            "colors": [
                {"label": "Coral", "value": "#ff6b57"},
                {"label": "Sun", "value": "#ffb703"},
                {"label": "Night", "value": "#14324a"},
                {"label": "Mist", "value": "#f4f7fb"},
            ],
            "keywords": ["Friendly", "Vibrant", "Daily-use", "Warm"],
            "titlebar_kicker": "Daily Guidance",
            "titlebar_title": "Muslim AI",
            "titlebar_meta": "Broadcasts, schedules, spiritual routines",
        },
        {
            "slug": "orbit-minaret",
            "name": "Orbit Minaret",
            "tagline": "Structured, technical, and platform-oriented.",
            "logo_path": "Islamic_Calender/branding/orbit-minaret.svg",
            "headline_font": "Space Grotesk Bold",
            "body_font": "Inter Medium",
            "summary": (
                "A circular orbit around a minaret-inspired spine. This direction fits a "
                "product that wants to feel like a serious, modern operating system."
            ),
            "colors": [
                {"label": "Cobalt", "value": "#2952ff"},
                {"label": "Mint", "value": "#4ce0b3"},
                {"label": "Cloud", "value": "#eef3ff"},
                {"label": "Slate", "value": "#162033"},
            ],
            "keywords": ["Platform", "Technical", "Bold", "Modern"],
            "titlebar_kicker": "Unified Islamic Toolkit",
            "titlebar_title": "Muslim AI",
            "titlebar_meta": "One platform for every Islamic workflow",
        },
        {
            "slug": "saffron-grid",
            "name": "Saffron Grid",
            "tagline": "Expressive, modular, and product-forward.",
            "logo_path": "Islamic_Calender/branding/saffron-grid.svg",
            "headline_font": "Syne ExtraBold",
            "body_font": "IBM Plex Sans",
            "summary": (
                "A modular monogram system with a strong app-icon feel. Best if you want "
                "Muslim AI to feel original and more startup-like."
            ),
            "colors": [
                {"label": "Saffron", "value": "#ff9f1c"},
                {"label": "Turquoise", "value": "#2ec4b6"},
                {"label": "Berry", "value": "#e71d36"},
                {"label": "Midnight", "value": "#1a132f"},
            ],
            "keywords": ["Distinct", "Startup", "Energetic", "Flexible"],
            "titlebar_kicker": "Modern Muslim Intelligence",
            "titlebar_title": "Muslim AI",
            "titlebar_meta": "Search, listen, track, and organize",
        },
    ]


def build_month_weeks(
    year: int,
    month: int,
    selected_date: date | None,
    *,
    mode: CalendarModeDefinition,
):
    cal = calendar.Calendar(firstweekday=6)
    raw_weeks = cal.monthdatescalendar(year, month)
    supported_min, supported_max = supported_gregorian_range(mode.slug)

    weeks = []
    for week in raw_weeks:
        row = []
        for day_value in week:
            record = None
            if supported_min <= day_value <= supported_max:
                record = resolve_calendar_record(day_value, mode=mode)
            row.append(
                {
                    "date": day_value,
                    "record": record,
                    "in_month": day_value.month == month,
                    "is_selected": day_value == selected_date,
                }
            )
        weeks.append(row)
    return weeks


def parse_month_year(
    request: HttpRequest,
    fallback: date,
    *,
    mode: CalendarModeDefinition,
) -> tuple[int, int]:
    supported_min, supported_max = supported_gregorian_range(mode.slug)
    try:
        year = int(request.GET.get("year", fallback.year))
        month = int(request.GET.get("month", fallback.month))
        if month < 1 or month > 12:
            raise ValueError
        anchor = date(year, month, 1)
    except (TypeError, ValueError):
        anchor = date(fallback.year, fallback.month, 1)

    min_anchor = date(supported_min.year, supported_min.month, 1)
    max_anchor = date(supported_max.year, supported_max.month, 1)
    if anchor < min_anchor:
        anchor = min_anchor
    if anchor > max_anchor:
        anchor = max_anchor
    return anchor.year, anchor.month


def adjacent_month(anchor: date, direction: int, *, mode: CalendarModeDefinition) -> date | None:
    year = anchor.year + ((anchor.month - 1 + direction) // 12)
    month = ((anchor.month - 1 + direction) % 12) + 1
    candidate = date(year, month, 1)
    supported_min, supported_max = supported_gregorian_range(mode.slug)
    min_anchor = date(supported_min.year, supported_min.month, 1)
    max_anchor = date(supported_max.year, supported_max.month, 1)
    if candidate < min_anchor or candidate > max_anchor:
        return None
    return candidate


def ramadan_last_ten_days(year: int, mode_slug: str = APP_DEFAULT_CALENDAR_MODE) -> list[int]:
    month_length = islamic_month_length(year, RAMADAN_MONTH, mode_slug)
    return list(range(month_length - 9, month_length + 1))


def ramadan_odd_last_ten_days(
    year: int,
    mode_slug: str = APP_DEFAULT_CALENDAR_MODE,
) -> list[int]:
    return [day for day in ramadan_last_ten_days(year, mode_slug) if day % 2 == 1]


def complete_supported_ramadan_years(mode: CalendarModeDefinition) -> list[int]:
    supported_min, supported_max = supported_gregorian_range(mode.slug)
    start_year = gregorian_to_hijri_for_mode(supported_min, mode.slug).year
    end_year = gregorian_to_hijri_for_mode(supported_max, mode.slug).year
    ramadan_years: list[int] = []

    for hijri_year in range(start_year, end_year + 1):
        month_length = islamic_month_length(hijri_year, RAMADAN_MONTH, mode.slug)
        ramadan_start = hijri_to_gregorian_for_mode(hijri_year, RAMADAN_MONTH, 1, mode.slug)
        ramadan_end = hijri_to_gregorian_for_mode(
            hijri_year,
            RAMADAN_MONTH,
            month_length,
            mode.slug,
        )
        if ramadan_start < supported_min or ramadan_end > supported_max:
            continue
        ramadan_years.append(hijri_year)

    return ramadan_years


def build_ramadan_year_entry(
    hijri_year: int,
    *,
    mode: CalendarModeDefinition,
) -> dict[str, object]:
    month_length = islamic_month_length(hijri_year, RAMADAN_MONTH, mode.slug)
    ramadan_start = hijri_to_gregorian_for_mode(hijri_year, RAMADAN_MONTH, 1, mode.slug)
    ramadan_end = hijri_to_gregorian_for_mode(hijri_year, RAMADAN_MONTH, month_length, mode.slug)
    last_ten_days = []
    odd_nights = []

    for hijri_day in ramadan_last_ten_days(hijri_year, mode.slug):
        gregorian_day = hijri_to_gregorian_for_mode(hijri_year, RAMADAN_MONTH, hijri_day, mode.slug)
        day_entry = {
            "hijri_day": hijri_day,
            "gregorian_date": gregorian_day,
            "weekday": gregorian_day.strftime("%A"),
            "is_friday": gregorian_day.strftime("%A") == "Friday",
            "is_odd": hijri_day % 2 == 1,
        }
        last_ten_days.append(day_entry)
        if day_entry["is_odd"]:
            odd_nights.append(day_entry)

    return {
        "hijri_year": hijri_year,
        "calendar_mode": mode,
        "gregorian_start": ramadan_start,
        "gregorian_end": ramadan_end,
        "last_ten_days": last_ten_days,
        "odd_nights": odd_nights,
    }


def build_ramadan_day_trends(
    ramadan_years: list[dict[str, object]],
    *,
    day_key: str,
) -> list[dict[str, object]]:
    if not ramadan_years:
        return []

    trend_rows: list[dict[str, object]] = []
    tracked_days = sorted(
        {day["hijri_day"] for ramadan_year in ramadan_years for day in ramadan_year[day_key]}
    )

    for hijri_day in tracked_days:
        weekday_counts: Counter[str] = Counter()
        friday_years: list[int] = []
        eligible_years = 0

        for ramadan_year in ramadan_years:
            day_entry = next(
                (day for day in ramadan_year[day_key] if day["hijri_day"] == hijri_day),
                None,
            )
            if day_entry is None:
                continue

            eligible_years += 1
            weekday = day_entry["weekday"]
            weekday_counts[weekday] += 1
            if day_entry["is_friday"]:
                friday_years.append(ramadan_year["hijri_year"])

        if not weekday_counts:
            continue

        dominant_count = max(weekday_counts.values())
        dominant_weekdays = sorted(
            [weekday for weekday, count in weekday_counts.items() if count == dominant_count],
            key=lambda weekday: WEEKDAY_ORDER[weekday],
        )
        dominant_weekday = dominant_weekdays[0]
        least_common_count = min(weekday_counts.values())
        weekday_spread = dominant_count - least_common_count
        friday_count = len(friday_years)
        friday_share = (friday_count / eligible_years) if eligible_years else 0
        odd_label = "odd night" if hijri_day % 2 == 1 else "even night"
        highlight = (
            f"{hijri_day} Ramadan is tracked as an {odd_label}; "
            f"Friday appears in {friday_count} of {eligible_years} years and the "
            f"weekday spread is only {weekday_spread} years."
        )

        trend_rows.append(
            {
                "hijri_day": hijri_day,
                "is_odd": hijri_day % 2 == 1,
                "eligible_years": eligible_years,
                "dominant_weekday": dominant_weekday,
                "dominant_count": dominant_count,
                "dominant_weekdays": dominant_weekdays,
                "friday_count": friday_count,
                "friday_share": friday_share,
                "friday_percentage": friday_share * 100,
                "weekday_counts": {
                    weekday: weekday_counts.get(weekday, 0) for weekday in calendar.day_name
                },
                "weekday_spread": weekday_spread,
                "last_friday_year": friday_years[-1] if friday_years else None,
                "recent_friday_years": list(reversed(friday_years[-5:])),
                "friday_years": friday_years,
                "highlight": highlight,
            }
        )

    return trend_rows


def build_odd_day_analysis(
    odd_day_trends: list[dict[str, object]],
    *,
    total_years: int,
) -> dict[str, object]:
    if not odd_day_trends or not total_years:
        return {
            "aggregate_friday_count": 0,
            "aggregate_friday_percentage": 0,
            "expected_uniform_percentage": 0,
            "friday_range": 0,
            "highest_friday_day": None,
            "highest_friday_count": 0,
            "lowest_friday_day": None,
            "lowest_friday_count": 0,
            "common_gap": None,
            "common_gap_count": 0,
            "insights": [],
        }

    highest_friday = max(
        odd_day_trends,
        key=lambda item: (item["friday_count"], item["hijri_day"]),
    )
    lowest_friday = min(
        odd_day_trends,
        key=lambda item: (item["friday_count"], item["hijri_day"]),
    )
    aggregate_friday_count = sum(trend["friday_count"] for trend in odd_day_trends)
    aggregate_observations = sum(trend["eligible_years"] for trend in odd_day_trends)
    gap_counts: Counter[int] = Counter()

    for trend in odd_day_trends:
        friday_years = trend["friday_years"]
        gap_counts.update(
            later_year - earlier_year
            for earlier_year, later_year in zip(friday_years, friday_years[1:], strict=False)
        )

    common_gap, common_gap_count = gap_counts.most_common(1)[0]
    aggregate_friday_percentage = (aggregate_friday_count / aggregate_observations) * 100
    expected_uniform_percentage = (1 / 7) * 100
    friday_range = highest_friday["friday_count"] - lowest_friday["friday_count"]

    insights = [
        (
            f"Across {aggregate_observations:,} odd-night observations, Friday appears "
            f"{aggregate_friday_count:,} times ({aggregate_friday_percentage:.1f}%), "
            f"which is effectively the uniform 1-in-7 weekday rate."
        ),
        (
            f"The odd-night Friday range is only {friday_range} years: "
            f"{highest_friday['hijri_day']} Ramadan is highest at "
            f"{highest_friday['friday_count']} years, while "
            f"{lowest_friday['hijri_day']} Ramadan is lowest at "
            f"{lowest_friday['friday_count']} years."
        ),
        (
            f"When Friday repeats on an odd Ramadan night, the most common gap is "
            f"{common_gap} Hijri years ({common_gap_count} repeats), with shorter 5- and "
            f"3-year jumps filling out the cycle."
        ),
    ]

    return {
        "aggregate_friday_count": aggregate_friday_count,
        "aggregate_friday_percentage": aggregate_friday_percentage,
        "expected_uniform_percentage": expected_uniform_percentage,
        "friday_range": friday_range,
        "highest_friday_day": highest_friday["hijri_day"],
        "highest_friday_count": highest_friday["friday_count"],
        "lowest_friday_day": lowest_friday["hijri_day"],
        "lowest_friday_count": lowest_friday["friday_count"],
        "common_gap": common_gap,
        "common_gap_count": common_gap_count,
        "insights": insights,
    }


def build_friday_balance_chart(
    last_ten_day_trends: list[dict[str, object]],
) -> dict[str, object]:
    if not last_ten_day_trends:
        return {
            "width": 760,
            "height": 280,
            "baseline_y": 140,
            "bars": [],
            "expected_percentage": 0,
        }

    width = 760
    height = 280
    margin_top = 24
    margin_right = 20
    margin_bottom = 56
    margin_left = 56
    plot_width = width - margin_left - margin_right
    plot_height = height - margin_top - margin_bottom
    baseline_y = margin_top + (plot_height / 2)
    usable_half_height = (plot_height / 2) - 16
    max_abs_delta = (
        max(
            abs(trend["friday_count"] - (trend["eligible_years"] / 7))
            for trend in last_ten_day_trends
        )
        or 1
    )
    slot_width = plot_width / len(last_ten_day_trends)
    bar_width = min(44, slot_width * 0.68)
    day_label_y = height - 18
    bars: list[dict[str, object]] = []

    for index, trend in enumerate(last_ten_day_trends):
        expected_count = trend["eligible_years"] / 7
        delta = trend["friday_count"] - expected_count
        bar_height = (abs(delta) / max_abs_delta) * usable_half_height
        x = margin_left + (index * slot_width) + ((slot_width - bar_width) / 2)
        y = baseline_y - bar_height if delta >= 0 else baseline_y
        count_y = y - 8 if delta >= 0 else y + bar_height + 16
        delta_y = baseline_y - bar_height - 24 if delta >= 0 else baseline_y + bar_height + 30

        bars.append(
            {
                "hijri_day": trend["hijri_day"],
                "friday_count": trend["friday_count"],
                "delta": delta,
                "delta_display": f"{delta:+.1f}",
                "expected_count_display": f"{expected_count:.1f}",
                "x": round(x, 2),
                "y": round(y, 2),
                "width": round(bar_width, 2),
                "height": round(bar_height, 2),
                "center_x": round(x + (bar_width / 2), 2),
                "count_y": round(count_y, 2),
                "delta_y": round(delta_y, 2),
                "day_label_y": day_label_y,
                "is_odd": trend["is_odd"],
                "is_positive": delta >= 0,
            }
        )

    return {
        "width": width,
        "height": height,
        "baseline_y": round(baseline_y, 2),
        "plot_left": margin_left,
        "plot_right": width - margin_right,
        "bars": bars,
        "expected_percentage": (1 / 7) * 100,
    }


def build_odd_weekday_heatmap(odd_day_trends: list[dict[str, object]]) -> dict[str, object]:
    weekday_labels = list(calendar.day_name)
    if not odd_day_trends:
        return {
            "weekday_labels": weekday_labels,
            "rows": [],
            "min_count": 0,
            "max_count": 0,
        }

    all_counts = [
        trend["weekday_counts"][weekday] for trend in odd_day_trends for weekday in weekday_labels
    ]
    min_count = min(all_counts)
    max_count = max(all_counts)
    spread = max_count - min_count
    rows: list[dict[str, object]] = []

    for trend in odd_day_trends:
        cells = []
        for weekday in weekday_labels:
            count = trend["weekday_counts"][weekday]
            normalized = ((count - min_count) / spread) if spread else 0.5
            cells.append(
                {
                    "weekday": weekday,
                    "count": count,
                    "intensity": f"{0.2 + (normalized * 0.7):.3f}",
                    "is_friday": weekday == "Friday",
                    "is_dominant": count == trend["dominant_count"],
                }
            )
        rows.append(
            {
                "hijri_day": trend["hijri_day"],
                "cells": cells,
            }
        )

    return {
        "weekday_labels": weekday_labels,
        "rows": rows,
        "min_count": min_count,
        "max_count": max_count,
    }


def align_ramadan_years_for_table(
    ramadan_years: list[dict[str, object]],
    *,
    day_headers: list[int],
) -> None:
    for ramadan_year in ramadan_years:
        by_day = {day["hijri_day"]: day for day in ramadan_year["last_ten_days"]}
        ramadan_year["aligned_last_ten_days"] = [
            by_day.get(day_header) for day_header in day_headers
        ]


@cache
def build_ramadan_analysis_context(mode_slug: str = APP_DEFAULT_CALENDAR_MODE) -> dict[str, object]:
    mode = get_calendar_mode(mode_slug)
    ramadan_years = [
        build_ramadan_year_entry(year, mode=mode) for year in complete_supported_ramadan_years(mode)
    ]
    last_ten_day_trends = build_ramadan_day_trends(ramadan_years, day_key="last_ten_days")
    odd_day_trends = build_ramadan_day_trends(ramadan_years, day_key="odd_nights")
    odd_day_analysis = build_odd_day_analysis(
        odd_day_trends,
        total_years=len(ramadan_years),
    )
    friday_balance_chart = build_friday_balance_chart(
        last_ten_day_trends,
    )
    odd_weekday_heatmap = build_odd_weekday_heatmap(odd_day_trends)
    last_ten_day_headers = [trend["hijri_day"] for trend in last_ten_day_trends]
    align_ramadan_years_for_table(ramadan_years, day_headers=last_ten_day_headers)
    friday_focus = max(
        odd_day_trends,
        key=lambda item: (item["friday_count"], item["friday_share"], -item["hijri_day"]),
        default=None,
    )

    return {
        "current_calendar_mode": mode,
        "calendar_modes": list(CALENDAR_MODES.values()),
        "ramadan_years": list(reversed(ramadan_years)),
        "last_ten_day_headers": last_ten_day_headers,
        "last_ten_day_trends": last_ten_day_trends,
        "odd_day_headers": [trend["hijri_day"] for trend in odd_day_trends],
        "odd_day_trends": odd_day_trends,
        "odd_day_analysis": odd_day_analysis,
        "friday_balance_chart": friday_balance_chart,
        "odd_weekday_heatmap": odd_weekday_heatmap,
        "friday_focus": friday_focus,
        "supported_ramadan_years": len(ramadan_years),
        "supported_ramadan_start_year": ramadan_years[0]["hijri_year"] if ramadan_years else None,
        "supported_ramadan_end_year": ramadan_years[-1]["hijri_year"] if ramadan_years else None,
    }


def home(request: HttpRequest) -> HttpResponse:
    mode = current_calendar_mode(request)
    supported_min, supported_max = supported_gregorian_range(mode.slug)
    selected_record = None
    gregorian_form = GregorianLookupForm(calendar_mode=mode.slug)
    hijri_form = HijriLookupForm(calendar_mode=mode.slug)

    if request.GET.get("gregorian_date"):
        gregorian_form = GregorianLookupForm(request.GET, calendar_mode=mode.slug)
        if gregorian_form.is_valid():
            selected_record = resolve_calendar_record(
                gregorian_form.cleaned_data["gregorian_date"],
                mode=mode,
            )
    elif request.GET.get("hijri_year"):
        hijri_form = HijriLookupForm(request.GET, calendar_mode=mode.slug)
        if hijri_form.is_valid():
            selected_record = resolve_calendar_record(
                hijri_form.cleaned_data["gregorian_date"],
                mode=mode,
            )

    fallback_date = (
        selected_record.gregorian_date
        if selected_record
        else min(max(date.today(), supported_min), supported_max)
    )
    year, month = parse_month_year(request, fallback=fallback_date, mode=mode)
    month_anchor = date(year, month, 1)
    month_weeks = build_month_weeks(
        year,
        month,
        selected_record.gregorian_date if selected_record else None,
        mode=mode,
    )

    context = {
        "active_page": "calendar",
        "calendar_modes": list(CALENDAR_MODES.values()),
        "current_calendar_mode": mode,
        "today_record": today_record(mode),
        "gregorian_form": gregorian_form,
        "hijri_form": hijri_form,
        "month_choices": list(enumerate(calendar.month_name[1:], start=1)),
        "selected_record": selected_record,
        "month_weeks": month_weeks,
        "month_anchor": month_anchor,
        "previous_month": adjacent_month(month_anchor, -1, mode=mode),
        "next_month": adjacent_month(month_anchor, 1, mode=mode),
        "supported_min": supported_min,
        "supported_max": supported_max,
    }
    return render(request, "Islamic_Calender/home.html", context)


def ramadan_analysis(request: HttpRequest) -> HttpResponse:
    mode = current_calendar_mode(request)
    context = {
        **build_ramadan_analysis_context(mode.slug),
        "active_page": "ramadan",
        "today_record": today_record(mode),
    }
    return render(request, "Islamic_Calender/ramadan_analysis.html", context)


def branding(request: HttpRequest) -> HttpResponse:
    mode = current_calendar_mode(request)
    context = {
        "active_page": "branding",
        "calendar_modes": list(CALENDAR_MODES.values()),
        "current_calendar_mode": mode,
        "today_record": today_record(mode),
        "branding_kits": branding_kits(),
    }
    return render(request, "Islamic_Calender/branding.html", context)


def resources(request: HttpRequest) -> HttpResponse:
    mode = current_calendar_mode(request)
    context = {
        **build_islamic_network_resources_context(),
        "active_page": "resources",
        "calendar_modes": list(CALENDAR_MODES.values()),
        "current_calendar_mode": mode,
        "today_record": today_record(mode),
    }
    return render(request, "Islamic_Calender/resources.html", context)


def privacy_policy(request: HttpRequest) -> HttpResponse:
    mode = current_calendar_mode(request)
    context = {
        "active_page": "privacy",
        "calendar_modes": list(CALENDAR_MODES.values()),
        "current_calendar_mode": mode,
        "today_record": today_record(mode),
    }
    return render(request, "Islamic_Calender/privacy_policy.html", context)
