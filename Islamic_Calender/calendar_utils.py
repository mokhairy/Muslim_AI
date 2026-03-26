from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from hijridate import Gregorian as UmmAlQuraGregorian
from hijridate import Hijri as UmmAlQuraHijri

ISLAMIC_EPOCH = date(622, 7, 19).toordinal()
MIN_SUPPORTED_GREGORIAN = date(622, 7, 19)
MAX_SUPPORTED_GREGORIAN = date(2100, 12, 31)
UMM_AL_QURA_MIN_SUPPORTED_GREGORIAN = date(1924, 8, 1)
UMM_AL_QURA_MAX_SUPPORTED_GREGORIAN = date(2077, 11, 16)
TABULAR_MODE = "tabular"
UMM_AL_QURA_MODE = "umm_al_qura"
APP_DEFAULT_CALENDAR_MODE = UMM_AL_QURA_MODE
HIJRI_MONTH_NAMES = (
    "Muharram",
    "Safar",
    "Rabi al-Awwal",
    "Rabi al-Thani",
    "Jumada al-Ula",
    "Jumada al-Akhirah",
    "Rajab",
    "Shaaban",
    "Ramadan",
    "Shawwal",
    "Dhu al-Qadah",
    "Dhu al-Hijjah",
)


@dataclass(frozen=True)
class IslamicDateValue:
    year: int
    month: int
    day: int

    @property
    def month_name(self) -> str:
        return HIJRI_MONTH_NAMES[self.month - 1]

    @property
    def formatted(self) -> str:
        return f"{self.day} {self.month_name} {self.year} AH"


@dataclass(frozen=True)
class CalendarModeDefinition:
    slug: str
    label: str
    short_label: str
    description: str
    supported_min: date
    supported_max: date


CALENDAR_MODES = {
    UMM_AL_QURA_MODE: CalendarModeDefinition(
        slug=UMM_AL_QURA_MODE,
        label="Umm al-Qura",
        short_label="Umm al-Qura",
        description="Saudi Arabia's precomputed civil Hijri calendar.",
        supported_min=UMM_AL_QURA_MIN_SUPPORTED_GREGORIAN,
        supported_max=UMM_AL_QURA_MAX_SUPPORTED_GREGORIAN,
    ),
    TABULAR_MODE: CalendarModeDefinition(
        slug=TABULAR_MODE,
        label="Tabular",
        short_label="Tabular",
        description="Arithmetic civil Hijri calendar with fixed month rules.",
        supported_min=MIN_SUPPORTED_GREGORIAN,
        supported_max=MAX_SUPPORTED_GREGORIAN,
    ),
}


def get_calendar_mode(mode_slug: str | None = None) -> CalendarModeDefinition:
    if mode_slug and mode_slug in CALENDAR_MODES:
        return CALENDAR_MODES[mode_slug]
    return CALENDAR_MODES[APP_DEFAULT_CALENDAR_MODE]


def supported_gregorian_range(mode_slug: str | None = None) -> tuple[date, date]:
    mode = get_calendar_mode(mode_slug)
    return mode.supported_min, mode.supported_max


def validate_supported_gregorian(value: date, mode_slug: str = TABULAR_MODE) -> None:
    supported_min, supported_max = supported_gregorian_range(mode_slug)
    if not supported_min <= value <= supported_max:
        raise ValueError(
            f"Supported Gregorian range for {get_calendar_mode(mode_slug).label} is "
            f"{supported_min.isoformat()} to {supported_max.isoformat()}."
        )


def days_before_islamic_month(month: int) -> int:
    return ((59 * (month - 1)) + 1) // 2


def is_islamic_leap_year(year: int) -> bool:
    return ((11 * year) + 14) % 30 < 11


def tabular_islamic_month_length(year: int, month: int) -> int:
    if month < 1 or month > 12:
        raise ValueError("Hijri month must be between 1 and 12.")
    if month == 12:
        return 30 if is_islamic_leap_year(year) else 29
    return 30 if month % 2 == 1 else 29


def islamic_month_length(year: int, month: int, mode_slug: str = TABULAR_MODE) -> int:
    if mode_slug == TABULAR_MODE:
        return tabular_islamic_month_length(year, month)
    if mode_slug == UMM_AL_QURA_MODE:
        return UmmAlQuraHijri(year, month, 1).month_length()
    raise ValueError(f"Unsupported calendar mode: {mode_slug}.")


def validate_hijri_date(year: int, month: int, day: int, mode_slug: str = TABULAR_MODE) -> None:
    if year < 1:
        raise ValueError("Hijri year must be 1 or greater.")
    if month < 1 or month > 12:
        raise ValueError("Hijri month must be between 1 and 12.")
    month_length = islamic_month_length(year, month, mode_slug)
    if day < 1 or day > month_length:
        raise ValueError(f"Hijri day must be between 1 and {month_length} for that month.")


def islamic_to_ordinal(year: int, month: int, day: int) -> int:
    validate_hijri_date(year, month, day, TABULAR_MODE)
    return (
        day
        + days_before_islamic_month(month)
        + (year - 1) * 354
        + ((3 + (11 * year)) // 30)
        + ISLAMIC_EPOCH
        - 1
    )


def ordinal_to_islamic(ordinal: int) -> IslamicDateValue:
    if ordinal < ISLAMIC_EPOCH:
        raise ValueError("Ordinal is earlier than the supported Hijri epoch.")

    year = ((30 * (ordinal - ISLAMIC_EPOCH)) + 10646) // 10631
    month = 1
    while month < 12 and ordinal >= islamic_to_ordinal(year, month + 1, 1):
        month += 1
    day = ordinal - islamic_to_ordinal(year, month, 1) + 1
    return IslamicDateValue(year=year, month=month, day=day)


def gregorian_to_hijri(value: date) -> IslamicDateValue:
    validate_supported_gregorian(value, TABULAR_MODE)
    return ordinal_to_islamic(value.toordinal())


def hijri_to_gregorian(year: int, month: int, day: int) -> date:
    ordinal = islamic_to_ordinal(year, month, day)
    value = date.fromordinal(ordinal)
    validate_supported_gregorian(value, TABULAR_MODE)
    return value


def gregorian_to_hijri_for_mode(value: date, mode_slug: str | None = None) -> IslamicDateValue:
    mode = get_calendar_mode(mode_slug)
    validate_supported_gregorian(value, mode.slug)
    if mode.slug == TABULAR_MODE:
        return gregorian_to_hijri(value)

    hijri_value = UmmAlQuraGregorian(value.year, value.month, value.day).to_hijri()
    return IslamicDateValue(
        year=hijri_value.year,
        month=hijri_value.month,
        day=hijri_value.day,
    )


def hijri_to_gregorian_for_mode(
    year: int,
    month: int,
    day: int,
    mode_slug: str | None = None,
) -> date:
    mode = get_calendar_mode(mode_slug)
    if mode.slug == TABULAR_MODE:
        return hijri_to_gregorian(year, month, day)

    gregorian_value = UmmAlQuraHijri(year, month, day).to_gregorian()
    value = date(gregorian_value.year, gregorian_value.month, gregorian_value.day)
    validate_supported_gregorian(value, mode.slug)
    return value
