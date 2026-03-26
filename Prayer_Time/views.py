from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from datetime import time as dt_time
from zoneinfo import ZoneInfo

from django.http import HttpRequest, HttpResponse
from django.shortcuts import render
from django.utils import timezone

from Islamic_Calender.calendar_utils import APP_DEFAULT_CALENDAR_MODE, get_calendar_mode
from Islamic_Calender.display import today_record

from .forms import (
    PrayerAutomationForm,
    PrayerTimesLookupForm,
    QiblaLookupForm,
    SpeakerGroupForm,
    prayer_stream_field_name,
)
from .models import PrayerAutomationSetting, SpeakerDevice, SpeakerGroupPreset
from .services import (
    ADHAN_STREAMS,
    AUTOMATED_PRAYER_NAMES,
    DeviceDiscoveryError,
    PrayerTimesServiceError,
    ReverseGeocodeServiceError,
    broadcast_stream_to_devices,
    fetch_prayer_calendar,
    fetch_prayer_times,
    fetch_qibla_direction,
    get_adhan_stream_by_url,
    refresh_discovered_devices,
    reverse_geocode_location,
    timings_to_map,
)


def _device_choices() -> list[tuple[str, str]]:
    return [
        (
            device.device_id,
            f"{device.name} ({device.protocol.upper()})",
        )
        for device in SpeakerDevice.objects.filter(is_available=True).order_by("name")
    ]


def _group_choices() -> list[tuple[str, str]]:
    return [(str(group.pk), group.name) for group in SpeakerGroupPreset.objects.order_by("name")]


def _automation_initial(
    settings: PrayerAutomationSetting,
    prayer_result=None,
    *,
    selected_group_id: str = "",
    selected_device_ids: list[str] | None = None,
) -> dict[str, object]:
    stream_url = settings.selected_stream_url or ADHAN_STREAMS[0]["url"]
    initial = {
        "enabled": settings.enabled,
        "speaker_group_id": selected_group_id,
        "location_label": settings.location_label,
        "latitude": settings.latitude,
        "longitude": settings.longitude,
        "selected_stream_url": stream_url,
        "selected_device_ids": (
            selected_device_ids if selected_device_ids is not None else settings.selected_device_ids
        ),
        "enabled_prayers": settings.enabled_prayers or list(AUTOMATED_PRAYER_NAMES),
    }
    for prayer_name in AUTOMATED_PRAYER_NAMES:
        initial[prayer_stream_field_name(prayer_name)] = (settings.prayer_stream_urls or {}).get(
            prayer_name, ""
        )
    if prayer_result is not None:
        initial.update(
            {
                "location_label": settings.location_label,
                "latitude": prayer_result.latitude,
                "longitude": prayer_result.longitude,
            }
        )
    return initial


def _custom_prayer_streams(settings: PrayerAutomationSetting) -> list[dict[str, str]]:
    custom_streams: list[dict[str, str]] = []
    for prayer_name in AUTOMATED_PRAYER_NAMES:
        stream_url = (settings.prayer_stream_urls or {}).get(prayer_name)
        if not stream_url:
            continue
        stream = get_adhan_stream_by_url(stream_url)
        custom_streams.append(
            {
                "prayer_name": prayer_name,
                "stream_name": stream["name"] if stream else stream_url,
            }
        )
    return custom_streams


def _prayer_datetime(prayer_date, prayer_time: str, zone: ZoneInfo) -> datetime:
    clean_time = prayer_time.split(" ", 1)[0]
    hour, minute = (int(part) for part in clean_time.split(":")[:2])
    return datetime.combine(prayer_date, dt_time(hour=hour, minute=minute), tzinfo=zone)


def _qibla_bearing_label(direction: float) -> str:
    labels = (
        "North",
        "North-Northeast",
        "Northeast",
        "East-Northeast",
        "East",
        "East-Southeast",
        "Southeast",
        "South-Southeast",
        "South",
        "South-Southwest",
        "Southwest",
        "West-Southwest",
        "West",
        "West-Northwest",
        "Northwest",
        "North-Northwest",
    )
    index = round((direction % 360) / 22.5) % len(labels)
    return labels[index]


def _resolve_location_details(
    *,
    latitude: float,
    longitude: float,
    location_label: str,
    accept_language: str,
) -> tuple[str, str]:
    if location_label:
        return location_label, ""
    try:
        reverse_geocode_result = reverse_geocode_location(
            latitude,
            longitude,
            accept_language=accept_language,
        )
        return reverse_geocode_result.label, reverse_geocode_result.display_name
    except ReverseGeocodeServiceError:
        return "", ""


def _build_next_prayer_dashboard(
    *,
    latitude: float,
    longitude: float,
    timezone_name: str,
    location_label: str,
) -> dict[str, object]:
    zone = ZoneInfo(timezone_name or "Asia/Muscat")
    now_local = datetime.now(zone)
    today = now_local.date()
    tomorrow = today + timedelta(days=1)
    today_result = fetch_prayer_times(
        prayer_date=today,
        latitude=latitude,
        longitude=longitude,
    )
    tomorrow_result = fetch_prayer_times(
        prayer_date=tomorrow,
        latitude=latitude,
        longitude=longitude,
    )

    schedule: list[dict[str, object]] = []
    today_timings = timings_to_map(today_result)
    tomorrow_timings = timings_to_map(tomorrow_result)
    for prayer_name in AUTOMATED_PRAYER_NAMES:
        prayer_time = today_timings.get(prayer_name)
        if not prayer_time:
            continue
        prayer_dt = _prayer_datetime(today, prayer_time, zone)
        schedule.append(
            {
                "name": prayer_name,
                "time_label": prayer_time,
                "day_label": "Today",
                "timestamp_ms": int(prayer_dt.timestamp() * 1000),
            }
        )

    tomorrow_fajr = tomorrow_timings.get("Fajr")
    if tomorrow_fajr:
        tomorrow_fajr_dt = _prayer_datetime(tomorrow, tomorrow_fajr, zone)
        schedule.append(
            {
                "name": "Fajr",
                "time_label": tomorrow_fajr,
                "day_label": "Tomorrow",
                "timestamp_ms": int(tomorrow_fajr_dt.timestamp() * 1000),
            }
        )

    next_prayer = next(
        (item for item in schedule if item["timestamp_ms"] > int(now_local.timestamp() * 1000)),
        None,
    )

    return {
        "location_label": location_label,
        "timezone": today_result.timezone,
        "schedule": schedule,
        "next_prayer_name": next_prayer["name"] if next_prayer else "",
        "next_prayer_time_label": next_prayer["time_label"] if next_prayer else "",
        "next_prayer_day_label": next_prayer["day_label"] if next_prayer else "",
    }


@dataclass(frozen=True)
class PrayerLookupOutcome:
    prayer_result: object | None = None
    location_label: str = ""
    resolved_address: str = ""
    service_error: str | None = None


@dataclass(frozen=True)
class PrayerDashboardOutcome:
    next_prayer_dashboard: dict[str, object] | None = None
    dashboard_error: str | None = None
    qibla_result: object | None = None
    monthly_calendar: object | None = None
    monthly_calendar_error: str | None = None


def _build_forms(
    *,
    automation_setting: PrayerAutomationSetting,
    prayer_result,
    device_choices: list[tuple[str, str]],
    group_choices: list[tuple[str, str]],
    request_post=None,
    current_selected_device_ids: list[str] | None = None,
    selected_group_id: str = "",
):
    if request_post is None:
        automation_form = PrayerAutomationForm(
            initial=_automation_initial(
                automation_setting,
                prayer_result,
                selected_group_id=selected_group_id,
                selected_device_ids=current_selected_device_ids,
            ),
            device_choices=device_choices,
            group_choices=group_choices,
            prefix="automation",
        )
        group_form = SpeakerGroupForm(device_choices=device_choices, prefix="group")
        return automation_form, group_form

    automation_form = PrayerAutomationForm(
        request_post,
        device_choices=device_choices,
        group_choices=group_choices,
        prefix="automation",
    )
    group_form = SpeakerGroupForm(
        request_post,
        device_choices=device_choices,
        prefix="group",
    )
    return automation_form, group_form


def _save_automation_settings(
    *,
    automation_form: PrayerAutomationForm,
    automation_setting: PrayerAutomationSetting,
    accept_language: str,
) -> str:
    stream = get_adhan_stream_by_url(automation_form.cleaned_data["selected_stream_url"])
    if stream is None:
        raise PrayerTimesServiceError("Selected adhan stream is not available.")

    timezone_name = automation_setting.timezone_name
    cached_date = None
    cached_timings = {}
    calculation_method = ""
    auto_location_label = automation_form.cleaned_data["location_label"] or ""
    latitude = automation_form.cleaned_data["latitude"]
    longitude = automation_form.cleaned_data["longitude"]

    if latitude is not None and longitude is not None:
        try:
            daily_result = fetch_prayer_times(
                prayer_date=timezone.localdate(),
                latitude=latitude,
                longitude=longitude,
            )
            timezone_name = daily_result.timezone
            cached_date = daily_result.requested_date
            cached_timings = timings_to_map(daily_result)
            calculation_method = daily_result.calculation_method
        except PrayerTimesServiceError:
            pass

        auto_location_label, _ = _resolve_location_details(
            latitude=latitude,
            longitude=longitude,
            location_label=auto_location_label,
            accept_language=accept_language,
        )

    automation_setting.enabled = automation_form.cleaned_data["enabled"]
    automation_setting.location_label = auto_location_label
    automation_setting.latitude = latitude
    automation_setting.longitude = longitude
    automation_setting.timezone_name = timezone_name
    automation_setting.selected_stream_url = stream["url"]
    automation_setting.selected_stream_name = stream["name"]
    automation_setting.prayer_stream_urls = {
        prayer_name: automation_form.cleaned_data[prayer_stream_field_name(prayer_name)]
        for prayer_name in AUTOMATED_PRAYER_NAMES
        if automation_form.cleaned_data.get(prayer_stream_field_name(prayer_name))
    }
    automation_setting.selected_device_ids = automation_form.cleaned_data["selected_device_ids"]
    automation_setting.enabled_prayers = automation_form.cleaned_data["enabled_prayers"]
    automation_setting.cached_prayer_date = cached_date
    automation_setting.cached_timings = cached_timings
    automation_setting.calculation_method = calculation_method
    automation_setting.save()
    return automation_setting.location_label


def _perform_prayer_lookup(
    *,
    lookup_requested: bool,
    lookup_form: PrayerTimesLookupForm,
    accept_language: str,
) -> PrayerLookupOutcome:
    if not lookup_requested or not lookup_form.is_valid():
        return PrayerLookupOutcome()
    try:
        prayer_result = fetch_prayer_times(
            prayer_date=lookup_form.cleaned_data["prayer_date"],
            latitude=lookup_form.cleaned_data["latitude"],
            longitude=lookup_form.cleaned_data["longitude"],
        )
        location_label, resolved_address = _resolve_location_details(
            latitude=prayer_result.latitude,
            longitude=prayer_result.longitude,
            location_label=lookup_form.cleaned_data.get("location_label", ""),
            accept_language=accept_language,
        )
        return PrayerLookupOutcome(
            prayer_result=prayer_result,
            location_label=location_label,
            resolved_address=resolved_address,
        )
    except PrayerTimesServiceError as exc:
        return PrayerLookupOutcome(service_error=str(exc))


def _handle_load_group_action(
    *,
    automation_form: PrayerAutomationForm,
    automation_setting: PrayerAutomationSetting,
    prayer_result,
    device_choices: list[tuple[str, str]],
    group_choices: list[tuple[str, str]],
) -> tuple[PrayerAutomationForm, SpeakerGroupForm, list[str], str | None]:
    selected_group_id = automation_form.cleaned_data.get("speaker_group_id") or ""
    if not selected_group_id:
        automation_form.add_error(
            "speaker_group_id",
            "Choose a speaker preset to load.",
        )
        return (
            automation_form,
            SpeakerGroupForm(device_choices=device_choices, prefix="group"),
            [],
            None,
        )

    selected_group = SpeakerGroupPreset.objects.filter(pk=selected_group_id).first()
    if not selected_group:
        automation_form.add_error(
            "speaker_group_id",
            "Selected speaker preset was not found.",
        )
        return (
            automation_form,
            SpeakerGroupForm(device_choices=device_choices, prefix="group"),
            [],
            None,
        )

    current_selected_device_ids = list(selected_group.selected_device_ids)
    automation_form, group_form = _build_forms(
        automation_setting=automation_setting,
        prayer_result=prayer_result,
        device_choices=device_choices,
        group_choices=group_choices,
        current_selected_device_ids=current_selected_device_ids,
        selected_group_id=selected_group_id,
    )
    return (
        automation_form,
        group_form,
        current_selected_device_ids,
        f"Loaded preset: {selected_group.name}.",
    )


def _build_prayer_dashboard_outcome(
    *,
    prayer_result,
    automation_setting: PrayerAutomationSetting,
    prayer_result_location_label: str,
    prayer_result_resolved_address: str,
    resolved_automation_location_label: str,
) -> PrayerDashboardOutcome:
    active_timezone = (
        prayer_result.timezone
        if prayer_result
        else automation_setting.timezone_name or "Asia/Muscat"
    )
    dashboard_latitude = prayer_result.latitude if prayer_result else automation_setting.latitude
    dashboard_longitude = prayer_result.longitude if prayer_result else automation_setting.longitude
    dashboard_location_label = (
        prayer_result_location_label
        or prayer_result_resolved_address
        or resolved_automation_location_label
        or automation_setting.location_label
        or "Current location"
    )
    if dashboard_latitude is None or dashboard_longitude is None:
        return PrayerDashboardOutcome()

    next_prayer_dashboard = None
    dashboard_error = None
    qibla_result = None
    monthly_calendar = None
    monthly_calendar_error = None

    try:
        next_prayer_dashboard = _build_next_prayer_dashboard(
            latitude=dashboard_latitude,
            longitude=dashboard_longitude,
            timezone_name=active_timezone,
            location_label=dashboard_location_label,
        )
    except PrayerTimesServiceError as exc:
        dashboard_error = str(exc)
    try:
        qibla_result = fetch_qibla_direction(
            latitude=dashboard_latitude,
            longitude=dashboard_longitude,
        )
    except PrayerTimesServiceError:
        qibla_result = None
    try:
        anchor_date = prayer_result.requested_date if prayer_result else timezone.localdate()
        monthly_calendar = fetch_prayer_calendar(
            year=anchor_date.year,
            month=anchor_date.month,
            latitude=dashboard_latitude,
            longitude=dashboard_longitude,
        )
    except PrayerTimesServiceError as exc:
        monthly_calendar_error = str(exc)

    return PrayerDashboardOutcome(
        next_prayer_dashboard=next_prayer_dashboard,
        dashboard_error=dashboard_error,
        qibla_result=qibla_result,
        monthly_calendar=monthly_calendar,
        monthly_calendar_error=monthly_calendar_error,
    )


def prayer_times(request: HttpRequest) -> HttpResponse:
    current_calendar_mode = get_calendar_mode(
        request.GET.get("calendar_mode")
        or request.POST.get("calendar_mode")
        or APP_DEFAULT_CALENDAR_MODE
    )
    automation_setting = PrayerAutomationSetting.singleton()
    lookup_requested = request.method == "GET" and any(
        request.GET.get(field_name) for field_name in ("prayer_date", "latitude", "longitude")
    )
    lookup_form = PrayerTimesLookupForm(
        request.GET if lookup_requested else None,
        initial={
            "prayer_date": None,
            "latitude": automation_setting.latitude,
            "longitude": automation_setting.longitude,
            "location_label": automation_setting.location_label,
        },
    )
    prayer_result = None
    prayer_result_location_label = ""
    prayer_result_resolved_address = ""
    service_error = None
    automation_message = None
    broadcast_results = None
    current_selected_device_ids = list(automation_setting.selected_device_ids)
    resolved_automation_location_label = automation_setting.location_label

    lookup_outcome = _perform_prayer_lookup(
        lookup_requested=lookup_requested,
        lookup_form=lookup_form,
        accept_language=request.headers.get("Accept-Language", "en"),
    )
    prayer_result = lookup_outcome.prayer_result
    prayer_result_location_label = lookup_outcome.location_label
    prayer_result_resolved_address = lookup_outcome.resolved_address
    service_error = lookup_outcome.service_error

    device_choices = _device_choices()
    group_choices = _group_choices()
    automation_form, group_form = _build_forms(
        automation_setting=automation_setting,
        prayer_result=prayer_result,
        device_choices=device_choices,
        group_choices=group_choices,
    )

    if request.method == "POST":
        action = request.POST.get("action")
        if action == "scan_devices":
            try:
                refresh_discovered_devices()
                device_choices = _device_choices()
                group_choices = _group_choices()
                automation_message = (
                    f"Scan complete. Found {len(device_choices)} Cast or DLNA speaker targets."
                )
            except DeviceDiscoveryError as exc:
                service_error = str(exc)
            automation_form, group_form = _build_forms(
                automation_setting=automation_setting,
                prayer_result=prayer_result,
                device_choices=device_choices,
                group_choices=group_choices,
                request_post=request.POST,
            )
        elif action in {"save_automation", "test_broadcast", "load_group"}:
            automation_form, group_form = _build_forms(
                automation_setting=automation_setting,
                prayer_result=prayer_result,
                device_choices=device_choices,
                group_choices=group_choices,
                request_post=request.POST,
            )
            if action == "load_group" and automation_form.is_valid():
                (
                    automation_form,
                    group_form,
                    current_selected_device_ids,
                    automation_message,
                ) = _handle_load_group_action(
                    automation_form=automation_form,
                    automation_setting=automation_setting,
                    prayer_result=prayer_result,
                    device_choices=device_choices,
                    group_choices=group_choices,
                )
            elif automation_form.is_valid():
                if action == "save_automation":
                    try:
                        resolved_automation_location_label = _save_automation_settings(
                            automation_form=automation_form,
                            automation_setting=automation_setting,
                            accept_language=request.headers.get("Accept-Language", "en"),
                        )
                        automation_message = "Automatic adhan settings saved."
                    except PrayerTimesServiceError as exc:
                        service_error = str(exc)
                elif action == "test_broadcast":
                    current_selected_device_ids = list(
                        automation_form.cleaned_data["selected_device_ids"]
                    )
                    broadcast_results = broadcast_stream_to_devices(
                        automation_form.cleaned_data["selected_stream_url"],
                        current_selected_device_ids,
                    )
                    success_count = len(broadcast_results["successes"])
                    error_count = len(broadcast_results["errors"])
                    automation_message = (
                        f"Test broadcast sent to {success_count} device(s). "
                        f"{error_count} error(s) returned."
                    )
        elif action == "save_group":
            group_form = SpeakerGroupForm(
                request.POST,
                device_choices=device_choices,
                prefix="group",
            )
            automation_form, _ = _build_forms(
                automation_setting=automation_setting,
                prayer_result=prayer_result,
                device_choices=device_choices,
                group_choices=group_choices,
                request_post=request.POST,
            )
            if group_form.is_valid():
                SpeakerGroupPreset.objects.update_or_create(
                    name=group_form.cleaned_data["name"],
                    defaults={
                        "selected_device_ids": group_form.cleaned_data["selected_device_ids"],
                    },
                )
                group_choices = _group_choices()
                automation_form, group_form = _build_forms(
                    automation_setting=automation_setting,
                    prayer_result=prayer_result,
                    device_choices=device_choices,
                    group_choices=group_choices,
                )
                automation_message = "Speaker preset saved."

    active_timezone = (
        prayer_result.timezone
        if prayer_result
        else automation_setting.timezone_name or "Asia/Muscat"
    )
    dashboard_outcome = _build_prayer_dashboard_outcome(
        prayer_result=prayer_result,
        automation_setting=automation_setting,
        prayer_result_location_label=prayer_result_location_label,
        prayer_result_resolved_address=prayer_result_resolved_address,
        resolved_automation_location_label=resolved_automation_location_label,
    )
    selected_devices = list(
        SpeakerDevice.objects.filter(device_id__in=current_selected_device_ids).order_by("name")
    )
    available_devices = list(SpeakerDevice.objects.filter(is_available=True).order_by("name"))
    speaker_groups = list(SpeakerGroupPreset.objects.order_by("name"))
    context = {
        "active_page": "prayers",
        "active_timezone": active_timezone,
        "adhan_streams": ADHAN_STREAMS,
        "automation_form": automation_form,
        "automation_message": automation_message,
        "automation_setting": automation_setting,
        "broadcast_results": broadcast_results,
        "current_calendar_mode": current_calendar_mode,
        "dashboard_error": dashboard_outcome.dashboard_error,
        "device_choices_count": len(device_choices),
        "group_form": group_form,
        "lookup_form": lookup_form,
        "monthly_calendar": dashboard_outcome.monthly_calendar,
        "monthly_calendar_error": dashboard_outcome.monthly_calendar_error,
        "next_prayer_dashboard": dashboard_outcome.next_prayer_dashboard,
        "prayer_result": prayer_result,
        "prayer_result_location_label": prayer_result_location_label,
        "prayer_result_resolved_address": prayer_result_resolved_address,
        "qibla_bearing_label": (
            _qibla_bearing_label(dashboard_outcome.qibla_result.direction)
            if dashboard_outcome.qibla_result
            else ""
        ),
        "qibla_result": dashboard_outcome.qibla_result,
        "available_devices": available_devices,
        "custom_prayer_streams": _custom_prayer_streams(automation_setting),
        "resolved_automation_location_label": resolved_automation_location_label,
        "speaker_groups": speaker_groups,
        "selected_devices": selected_devices,
        "service_error": service_error,
        "today_record": today_record(current_calendar_mode),
    }
    return render(request, "Prayer_Time/home.html", context)


def qibla(request: HttpRequest) -> HttpResponse:
    current_calendar_mode = get_calendar_mode(
        request.GET.get("calendar_mode") or APP_DEFAULT_CALENDAR_MODE
    )
    automation_setting = PrayerAutomationSetting.singleton()
    lookup_requested = any(request.GET.get(field_name) for field_name in ("latitude", "longitude"))
    qibla_form = QiblaLookupForm(
        request.GET if lookup_requested else None,
        initial={
            "latitude": automation_setting.latitude,
            "longitude": automation_setting.longitude,
            "location_label": automation_setting.location_label,
        },
    )
    qibla_result = None
    location_label = ""
    resolved_address = ""
    service_error = None

    if lookup_requested and qibla_form.is_valid():
        latitude = qibla_form.cleaned_data["latitude"]
        longitude = qibla_form.cleaned_data["longitude"]
        location_label = qibla_form.cleaned_data.get("location_label", "")
        try:
            qibla_result = fetch_qibla_direction(latitude=latitude, longitude=longitude)
            location_label, resolved_address = _resolve_location_details(
                latitude=latitude,
                longitude=longitude,
                location_label=location_label,
                accept_language=request.headers.get("Accept-Language", "en"),
            )
        except PrayerTimesServiceError as exc:
            service_error = str(exc)

    context = {
        "active_page": "qibla",
        "current_calendar_mode": current_calendar_mode,
        "today_record": today_record(current_calendar_mode),
        "qibla_form": qibla_form,
        "qibla_result": qibla_result,
        "qibla_bearing_label": _qibla_bearing_label(qibla_result.direction) if qibla_result else "",
        "location_label": location_label,
        "resolved_address": resolved_address,
        "service_error": service_error,
    }
    return render(request, "Prayer_Time/qibla.html", context)
