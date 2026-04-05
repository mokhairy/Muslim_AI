from __future__ import annotations

import json
import platform
import shutil
import socket
import subprocess
import tempfile
import threading
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import date
from functools import lru_cache
from pathlib import Path
from typing import Any
from urllib.parse import urlencode, urljoin, urlparse
from urllib.request import Request, urlopen
from uuid import UUID
from xml.sax.saxutils import escape

import pychromecast
from django.utils import timezone
from pychromecast.quick_play import quick_play

from .models import SpeakerDevice

PRAYER_TIMES_API_URL = "https://api.aladhan.com/v1/timings/{date}"
PRAYER_CALENDAR_API_URL = "https://api.aladhan.com/v1/calendar/{year}/{month}"
QIBLA_API_URL = "https://api.aladhan.com/v1/qibla/{latitude}/{longitude}"
REVERSE_GEOCODE_API_URL = "https://nominatim.openstreetmap.org/reverse"
DEFAULT_CALCULATION_METHOD = 4
PRAYER_NAME_ORDER = (
    "Fajr",
    "Sunrise",
    "Dhuhr",
    "Asr",
    "Maghrib",
    "Isha",
)
AUTOMATED_PRAYER_NAMES = ("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")
ADHAN_STREAMS = (
    {
        "name": "Makkah Adhan 1",
        "reciter": "IslamCan stream",
        "url": "https://www.islamcan.com/audio/adhan/azan1.mp3",
        "source_label": "IslamCan",
        "source_url": "https://www.islamcan.com/audio/adhan/azan1.mp3",
    },
    {
        "name": "Makkah Adhan 2",
        "reciter": "IslamCan stream",
        "url": "https://www.islamcan.com/audio/adhan/azan2.mp3",
        "source_label": "IslamCan",
        "source_url": "https://www.islamcan.com/audio/adhan/azan2.mp3",
    },
    {
        "name": "Makkah Adhan 3",
        "reciter": "IslamCan stream",
        "url": "https://www.islamcan.com/audio/adhan/azan3.mp3",
        "source_label": "IslamCan",
        "source_url": "https://www.islamcan.com/audio/adhan/azan3.mp3",
    },
)
SSDP_GROUP = ("239.255.255.250", 1900)
CAST_AUDIO_CONTENT_TYPE = "audio/mpeg"
CAST_STREAM_TYPE = "BUFFERED"
LOCAL_SPEAKER_DEVICE_ID = "local:system_output"
LOCAL_SPEAKER_NAME = "This machine speakers"


class PrayerTimesServiceError(Exception):
    pass


class DeviceDiscoveryError(Exception):
    pass


class DeviceBroadcastError(Exception):
    pass


class ReverseGeocodeServiceError(Exception):
    pass


@dataclass(frozen=True)
class PrayerTimingEntry:
    name: str
    time: str


@dataclass(frozen=True)
class PrayerTimesResult:
    requested_date: date
    latitude: float
    longitude: float
    timezone: str
    hijri_date: str
    readable_date: str
    timings: list[PrayerTimingEntry]
    calculation_method: str


@dataclass(frozen=True)
class DiscoveredDevice:
    protocol: str
    device_id: str
    name: str
    host: str | None = None
    port: int | None = None
    device_type: str = ""
    model_name: str = ""
    location_url: str = ""
    is_group: bool = False


@dataclass(frozen=True)
class ReverseGeocodeResult:
    label: str
    display_name: str


@dataclass(frozen=True)
class QiblaDirectionResult:
    latitude: float
    longitude: float
    direction: float


@dataclass(frozen=True)
class PrayerCalendarDay:
    readable_date: str
    gregorian_date: str
    weekday: str
    hijri_date: str
    hijri_month: str
    holiday_summary: str
    timings: dict[str, str]


@dataclass(frozen=True)
class PrayerCalendarResult:
    year: int
    month: int
    month_label: str
    timezone: str
    calculation_method: str
    days: list[PrayerCalendarDay]


def _load_json_uncached(url: str, *, timeout: int = 10) -> dict[str, object]:
    request = Request(
        url,
        headers={
            "User-Agent": "MuslimAI/1.0 (+https://aladhan.com integration)",
            "Accept": "application/json",
        },
    )
    try:
        with urlopen(request, timeout=timeout) as response:
            return json.load(response)
    except Exception as exc:  # pragma: no cover
        raise PrayerTimesServiceError(
            "Unable to reach the prayer times service right now."
        ) from exc


@lru_cache(maxsize=256)
def _load_json_cached(url: str, timeout: int = 10) -> dict[str, object]:
    return _load_json_uncached(url, timeout=timeout)


def clear_prayer_service_caches() -> None:
    _load_json_cached.cache_clear()
    _reverse_geocode_cached.cache_clear()


def _clean_timing_label(raw_value: str) -> str:
    return raw_value.split(" ", 1)[0].strip()


def fetch_prayer_times(
    *,
    prayer_date: date,
    latitude: float,
    longitude: float,
) -> PrayerTimesResult:
    query = urlencode(
        {
            "latitude": latitude,
            "longitude": longitude,
            "method": DEFAULT_CALCULATION_METHOD,
        }
    )
    url = PRAYER_TIMES_API_URL.format(date=prayer_date.strftime("%d-%m-%Y"))
    payload = _load_json_cached(f"{url}?{query}")

    if payload.get("code") != 200:
        raise PrayerTimesServiceError(payload.get("status", "Prayer times lookup failed."))

    data = payload["data"]
    raw_timings = data["timings"]
    timings = [
        PrayerTimingEntry(
            name=prayer_name,
            time=_clean_timing_label(raw_timings[prayer_name]),
        )
        for prayer_name in PRAYER_NAME_ORDER
    ]
    return PrayerTimesResult(
        requested_date=prayer_date,
        latitude=latitude,
        longitude=longitude,
        timezone=data["meta"]["timezone"],
        hijri_date=data["date"]["hijri"]["date"],
        readable_date=data["date"]["readable"],
        timings=timings,
        calculation_method=data["meta"]["method"]["name"],
    )


def fetch_qibla_direction(*, latitude: float, longitude: float) -> QiblaDirectionResult:
    payload = _load_json_cached(QIBLA_API_URL.format(latitude=latitude, longitude=longitude))
    if payload.get("code") != 200:
        raise PrayerTimesServiceError(payload.get("status", "Qibla lookup failed."))
    data = payload.get("data", {})
    return QiblaDirectionResult(
        latitude=float(data.get("latitude", latitude)),
        longitude=float(data.get("longitude", longitude)),
        direction=float(data.get("direction", 0.0)),
    )


def fetch_prayer_calendar(
    *,
    year: int,
    month: int,
    latitude: float,
    longitude: float,
) -> PrayerCalendarResult:
    query = urlencode(
        {
            "latitude": latitude,
            "longitude": longitude,
            "method": DEFAULT_CALCULATION_METHOD,
        }
    )
    payload = _load_json_cached(
        PRAYER_CALENDAR_API_URL.format(year=year, month=month) + f"?{query}"
    )
    if payload.get("code") != 200:
        raise PrayerTimesServiceError(payload.get("status", "Prayer calendar lookup failed."))

    raw_days = payload.get("data", [])
    if not isinstance(raw_days, list) or not raw_days:
        raise PrayerTimesServiceError("Prayer calendar lookup returned no data.")

    days: list[PrayerCalendarDay] = []
    for day_payload in raw_days:
        raw_timings = day_payload.get("timings", {})
        date_payload = day_payload.get("date", {})
        gregorian = date_payload.get("gregorian", {})
        hijri = date_payload.get("hijri", {})
        holidays = hijri.get("holidays", []) or []
        days.append(
            PrayerCalendarDay(
                readable_date=date_payload.get("readable", ""),
                gregorian_date=gregorian.get("date", ""),
                weekday=(gregorian.get("weekday") or {}).get("en", ""),
                hijri_date=hijri.get("date", ""),
                hijri_month=(hijri.get("month") or {}).get("en", ""),
                holiday_summary=", ".join(holidays),
                timings={
                    prayer_name: _clean_timing_label(raw_timings.get(prayer_name, "--"))
                    for prayer_name in PRAYER_NAME_ORDER
                },
            )
        )

    meta = raw_days[0].get("meta", {})
    method = meta.get("method", {})
    month_name = (raw_days[0].get("date", {}).get("gregorian", {}).get("month", {}) or {}).get(
        "en", str(month)
    )
    return PrayerCalendarResult(
        year=year,
        month=month,
        month_label=f"{month_name} {year}",
        timezone=meta.get("timezone", ""),
        calculation_method=method.get("name", ""),
        days=days,
    )


def _build_location_label(address: dict[str, str], fallback: str) -> str:
    parts: list[str] = []
    road = address.get("road") or address.get("pedestrian") or address.get("suburb")
    locality = (
        address.get("city")
        or address.get("town")
        or address.get("village")
        or address.get("municipality")
        or address.get("county")
    )
    state = address.get("state") or address.get("state_district")
    country = address.get("country")

    for value in (road, locality, state, country):
        if value and value not in parts:
            parts.append(value)

    return ", ".join(parts[:4]) or fallback


@lru_cache(maxsize=256)
def _reverse_geocode_cached(
    latitude: float,
    longitude: float,
    accept_language: str,
) -> ReverseGeocodeResult:
    query = urlencode(
        {
            "format": "jsonv2",
            "lat": latitude,
            "lon": longitude,
            "addressdetails": 1,
            "zoom": 18,
            "accept-language": accept_language,
        }
    )
    request = Request(
        f"{REVERSE_GEOCODE_API_URL}?{query}",
        headers={
            "User-Agent": "MuslimAICalendar/1.0 (reverse geocoding)",
            "Accept-Language": accept_language,
        },
    )
    try:
        with urlopen(request, timeout=10) as response:
            payload = json.load(response)
    except Exception as exc:  # pragma: no cover
        raise ReverseGeocodeServiceError(
            "Unable to resolve the current location name right now."
        ) from exc

    display_name = payload.get("display_name", "").strip()
    if not display_name:
        raise ReverseGeocodeServiceError(
            "No reverse-geocoded address was returned for these coordinates."
        )

    address = payload.get("address", {})
    return ReverseGeocodeResult(
        label=_build_location_label(address, display_name),
        display_name=display_name,
    )


def reverse_geocode_location(
    latitude: float,
    longitude: float,
    *,
    accept_language: str = "en",
) -> ReverseGeocodeResult:
    normalized_language = (accept_language or "en").split(",")[0].strip() or "en"
    return _reverse_geocode_cached(round(latitude, 4), round(longitude, 4), normalized_language)


def get_adhan_stream_choices() -> list[tuple[str, str]]:
    return [(stream["url"], stream["name"]) for stream in ADHAN_STREAMS]


def get_adhan_stream_by_url(stream_url: str) -> dict[str, str] | None:
    for stream in ADHAN_STREAMS:
        if stream["url"] == stream_url:
            return stream
    return None


def timings_to_map(prayer_result: PrayerTimesResult) -> dict[str, str]:
    return {item.name: item.time for item in prayer_result.timings}


def ensure_local_speaker_device() -> SpeakerDevice:
    device, _ = SpeakerDevice.objects.update_or_create(
        device_id=LOCAL_SPEAKER_DEVICE_ID,
        defaults={
            "protocol": "local",
            "name": LOCAL_SPEAKER_NAME,
            "host": None,
            "port": None,
            "device_type": "System audio output",
            "model_name": platform.system() or "Local machine",
            "location_url": "",
            "is_group": False,
            "is_available": True,
        },
    )
    return device


def _safe_cast_attr(cast: Any, attr_path: str, default: Any = None) -> Any:
    current = cast
    for attr_name in attr_path.split("."):
        current = getattr(current, attr_name, None)
        if current is None:
            return default
    return current


def discover_cast_devices(timeout: float = 5) -> list[DiscoveredDevice]:
    discovered: list[DiscoveredDevice] = []
    browser = None
    try:
        chromecasts, browser = pychromecast.get_chromecasts(
            tries=1,
            retry_wait=0.5,
            timeout=timeout,
        )
        for cast in chromecasts:
            uuid_value = _safe_cast_attr(cast, "uuid") or _safe_cast_attr(cast, "cast_info.uuid")
            if not uuid_value:
                continue
            discovered.append(
                DiscoveredDevice(
                    protocol="cast",
                    device_id=f"cast:{uuid_value}",
                    name=_safe_cast_attr(cast, "name")
                    or _safe_cast_attr(cast, "cast_info.friendly_name")
                    or "Google Cast device",
                    host=_safe_cast_attr(cast, "host") or _safe_cast_attr(cast, "cast_info.host"),
                    port=_safe_cast_attr(cast, "port") or _safe_cast_attr(cast, "cast_info.port"),
                    device_type=_safe_cast_attr(cast, "cast_type")
                    or _safe_cast_attr(cast, "cast_info.cast_type")
                    or "",
                    model_name=_safe_cast_attr(cast, "model_name")
                    or _safe_cast_attr(cast, "cast_info.model_name")
                    or "",
                    is_group=(
                        (
                            _safe_cast_attr(cast, "cast_type")
                            or _safe_cast_attr(cast, "cast_info.cast_type")
                        )
                        == "group"
                    ),
                )
            )
    finally:
        if browser is not None:
            browser.stop_discovery()
    return discovered


def _parse_ssdp_response(payload: bytes) -> dict[str, str]:
    headers: dict[str, str] = {}
    for line in payload.decode("utf-8", "ignore").split("\r\n")[1:]:
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        headers[key.strip().lower()] = value.strip()
    return headers


def _fetch_dlna_description(location_url: str) -> tuple[str, str, str, str]:
    with urlopen(location_url, timeout=3) as response:
        xml_bytes = response.read()
    root = ET.fromstring(xml_bytes)
    friendly_name = root.findtext(".//{*}friendlyName", default="")
    model_name = root.findtext(".//{*}modelName", default="")
    device_type = root.findtext(".//{*}deviceType", default="")
    udn = root.findtext(".//{*}UDN", default="").strip()
    return friendly_name, model_name, device_type, udn


def discover_dlna_devices(timeout: float = 3.0) -> list[DiscoveredDevice]:
    message = "\r\n".join(
        [
            "M-SEARCH * HTTP/1.1",
            f"HOST: {SSDP_GROUP[0]}:{SSDP_GROUP[1]}",
            'MAN: "ssdp:discover"',
            "MX: 1",
            "ST: urn:schemas-upnp-org:device:MediaRenderer:1",
            "",
            "",
        ]
    ).encode("utf-8")
    discovered: dict[str, DiscoveredDevice] = {}
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP) as sock:
        sock.settimeout(0.5)
        sock.sendto(message, SSDP_GROUP)
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                payload, address = sock.recvfrom(8192)
            except TimeoutError:
                continue
            headers = _parse_ssdp_response(payload)
            location_url = headers.get("location")
            if not location_url:
                continue
            try:
                friendly_name, model_name, device_type, udn = _fetch_dlna_description(location_url)
            except Exception:
                continue
            if "MediaRenderer" not in device_type:
                continue
            parsed = urlparse(location_url)
            device_id = f"dlna:{udn or location_url}"
            discovered[device_id] = DiscoveredDevice(
                protocol="dlna",
                device_id=device_id,
                name=friendly_name or headers.get("server", "DLNA device"),
                host=parsed.hostname or address[0],
                port=parsed.port,
                device_type=device_type,
                model_name=model_name,
                location_url=location_url,
                is_group=False,
            )
    return list(discovered.values())


def refresh_discovered_devices(timeout: float = 4) -> list[SpeakerDevice]:
    local_device = ensure_local_speaker_device()
    try:
        discovered = [
            DiscoveredDevice(
                protocol=local_device.protocol,
                device_id=local_device.device_id,
                name=local_device.name,
                device_type=local_device.device_type,
                model_name=local_device.model_name,
                is_group=local_device.is_group,
            ),
            *discover_cast_devices(timeout=timeout),
            *discover_dlna_devices(timeout=timeout),
        ]
    except Exception as exc:  # pragma: no cover
        raise DeviceDiscoveryError("Unable to scan the local network for speakers.") from exc
    discovered_ids = {device.device_id for device in discovered}
    SpeakerDevice.objects.exclude(device_id=LOCAL_SPEAKER_DEVICE_ID).update(is_available=False)
    now = timezone.now()
    for device in discovered:
        SpeakerDevice.objects.update_or_create(
            device_id=device.device_id,
            defaults={
                "protocol": device.protocol,
                "name": device.name,
                "host": device.host,
                "port": device.port,
                "device_type": device.device_type,
                "model_name": device.model_name,
                "location_url": device.location_url,
                "is_group": device.is_group,
                "is_available": True,
                "last_seen": now,
            },
        )
    if not discovered_ids:
        return []
    return list(SpeakerDevice.objects.filter(device_id__in=discovered_ids).order_by("name"))


def _local_audio_player_command(audio_path: str) -> list[str]:
    system_name = platform.system()
    if system_name == "Darwin":
        return ["/usr/bin/afplay", audio_path]
    if system_name == "Linux":
        for command in (
            ["ffplay", "-nodisp", "-autoexit", "-loglevel", "error", audio_path],
            ["paplay", audio_path],
            ["aplay", audio_path],
        ):
            if shutil.which(command[0]):
                return command
    raise DeviceBroadcastError(
        f"Local speaker playback is not supported on {system_name or 'this platform'}."
    )


def _download_stream_to_temp_file(stream_url: str) -> str:
    suffix = Path(urlparse(stream_url).path).suffix or ".mp3"
    request = Request(
        stream_url,
        headers={
            "User-Agent": "MuslimAI/1.0 (local audio playback)",
        },
    )
    try:
        with urlopen(request, timeout=15) as response, tempfile.NamedTemporaryFile(
            delete=False,
            suffix=suffix,
        ) as temp_file:
            shutil.copyfileobj(response, temp_file)
            return temp_file.name
    except Exception as exc:  # pragma: no cover
        raise DeviceBroadcastError(
            "Unable to download the adhan stream for local playback."
        ) from exc


def _play_downloaded_audio(command: list[str], audio_path: str) -> None:
    try:
        subprocess.run(
            command,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    finally:
        Path(audio_path).unlink(missing_ok=True)


def _cast_to_local_output(device: SpeakerDevice, stream_url: str) -> None:
    audio_path = _download_stream_to_temp_file(stream_url)
    command = _local_audio_player_command(audio_path)
    playback_thread = threading.Thread(
        target=_play_downloaded_audio,
        args=(command, audio_path),
        daemon=True,
    )
    playback_thread.start()


def _chromecast_for_device(device: SpeakerDevice):
    device_uuid = UUID(device.device_id.removeprefix("cast:"))
    chromecasts, browser = pychromecast.get_listed_chromecasts(
        uuids=[device_uuid],
        discovery_timeout=5,
    )
    if chromecasts:
        return chromecasts[0], browser
    browser.stop_discovery()
    if device.host:
        chromecasts, browser = pychromecast.get_chromecasts(
            tries=1,
            retry_wait=0.5,
            timeout=5,
            known_hosts=[device.host],
        )
        matching_cast = next((cast for cast in chromecasts if cast.uuid == device_uuid), None)
        if matching_cast is not None:
            return matching_cast, browser
        browser.stop_discovery()
    if device.host:
        return (
            pychromecast.get_chromecast_from_host(
                (
                    device.host,
                    device.port or 8009,
                    device_uuid,
                    device.model_name or None,
                    device.name or None,
                )
            ),
            None,
        )
    raise DeviceBroadcastError(f"Cast device {device.name} is not reachable.")


def _cast_to_chromecast(device: SpeakerDevice, stream_url: str) -> None:
    cast, browser = _chromecast_for_device(device)
    try:
        cast.wait(timeout=10)
        quick_play(
            cast,
            "default_media_receiver",
            {
                "media_id": stream_url,
                "media_type": CAST_AUDIO_CONTENT_TYPE,
                "stream_type": CAST_STREAM_TYPE,
            },
            timeout=30,
        )
    finally:
        cast.disconnect()
        if browser is not None:
            browser.stop_discovery()


def _dlna_av_transport_control_url(device: SpeakerDevice) -> str:
    if not device.location_url:
        raise DeviceBroadcastError(f"DLNA device {device.name} has no descriptor URL.")
    with urlopen(device.location_url, timeout=3) as response:
        root = ET.fromstring(response.read())
    for service in root.findall(".//{*}service"):
        service_type = service.findtext("{*}serviceType", default="")
        if "AVTransport" not in service_type:
            continue
        control_url = service.findtext("{*}controlURL", default="")
        return urljoin(device.location_url, control_url)
    raise DeviceBroadcastError(f"DLNA device {device.name} does not expose AVTransport.")


def _soap_post(url: str, service_type: str, action_name: str, body: str) -> None:
    request = Request(
        url,
        data=body.encode("utf-8"),
        headers={
            "Content-Type": 'text/xml; charset="utf-8"',
            "SOAPACTION": f'"{service_type}#{action_name}"',
        },
        method="POST",
    )
    with urlopen(request, timeout=5):
        return


def _cast_to_dlna(device: SpeakerDevice, stream_url: str) -> None:
    service_type = "urn:schemas-upnp-org:service:AVTransport:1"
    control_url = _dlna_av_transport_control_url(device)
    set_uri_body = f"""<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:SetAVTransportURI xmlns:u="{service_type}">
      <InstanceID>0</InstanceID>
      <CurrentURI>{escape(stream_url)}</CurrentURI>
      <CurrentURIMetaData></CurrentURIMetaData>
    </u:SetAVTransportURI>
  </s:Body>
</s:Envelope>"""
    play_body = f"""<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:Play xmlns:u="{service_type}">
      <InstanceID>0</InstanceID>
      <Speed>1</Speed>
    </u:Play>
  </s:Body>
</s:Envelope>"""
    _soap_post(control_url, service_type, "SetAVTransportURI", set_uri_body)
    _soap_post(control_url, service_type, "Play", play_body)


def broadcast_stream_to_devices(stream_url: str, device_ids: list[str]) -> dict[str, list[str]]:
    ensure_local_speaker_device()
    results = {"successes": [], "errors": []}
    for device in SpeakerDevice.objects.filter(device_id__in=device_ids, is_available=True):
        try:
            if device.protocol == "cast":
                _cast_to_chromecast(device, stream_url)
            elif device.protocol == "dlna":
                _cast_to_dlna(device, stream_url)
            elif device.protocol == "local":
                _cast_to_local_output(device, stream_url)
            else:
                raise DeviceBroadcastError(f"Unsupported device protocol: {device.protocol}.")
            results["successes"].append(device.name)
        except Exception as exc:
            results["errors"].append(f"{device.name}: {exc}")
    return results
